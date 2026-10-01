-- db/053_items_homebrew_edit.sql
--
-- Lets a campaign's DM edit that campaign's homebrew items in place, from the
-- browser. Until now the only fix for a mistyped homebrew item was the SQL
-- editor: 025 shipped INSERT and nothing else, so a typo was permanent from
-- the app.
--
-- IN PLACE, NOT A COPY. The row is updated where it stands, so every
-- party_inventory and character_inventory stack pointing at it sees the new
-- name, price and stats on its next read. That is the point: nothing is
-- reseeded, and nothing is duplicated.
--
-- HOMEBREW ONLY, AND THAT IS THE DESIGN, NOT AN OMISSION. A shared catalogue
-- row (campaign_id is null) belongs to every campaign at once, so there is no
-- per-campaign DM who owns it, and letting any one DM edit it would rewrite
-- every other campaign's shop. Gating it on the global is_dm() was considered
-- and rejected: that flag means "may create campaigns" and nothing else (see
-- CLAUDE.md, Multi-campaign), and anyone who claims a DM invite would hold it.
-- Shared rows stay owner-only, i.e. a migration. If per-campaign changes to a
-- shared item are ever wanted, the shape is an override table keyed on
-- (campaign_id, item_id), 047's pattern -- not a looser policy here.
--
-- THE POLICY is 025's INSERT check, reused as both USING and WITH CHECK:
--   USING      -- which existing rows you may target. A shared row fails
--                 `campaign_id is not null`, another campaign's homebrew fails
--                 is_campaign_dm, and either way the UPDATE matches zero rows
--                 and returns a clean 200 (CLAUDE.md, "A refused write raises
--                 nothing"). The client must use .select().maybeSingle() and
--                 treat no row as a refusal, as updateNpc does.
--   WITH CHECK -- what the row may become. Stops a DM turning their homebrew
--                 into a shared row by nulling campaign_id.
--
-- THE PIN TRIGGER. RLS cannot compare old to new, so WITH CHECK alone would
-- still let a DM of two campaigns move an item from A to B: both sides pass
-- is_campaign_dm. Every stack in A pointing at it would then embed null for
-- A's players, 037's CharacterSpellRow hole on a new table. pin_item_row pins
-- id, campaign_id and created_at, pin_npc_row's shape: silently reset, not
-- raised, so a client bug sending the wrong campaign is a no-op rather than an
-- error in the middle of a game.
--
-- ⚠ A BLOCKLIST, LIKE THE OTHER FIVE. Every column added to items from here on
-- is DM-editable on homebrew until someone pins it. (KNOWN_ISSUES, "The pin
-- triggers are blocklists".) Today every unpinned column is one a DM should
-- be able to fix, including kind and the weapon/armor fields, whose CHECKs from
-- 001 still apply.
--
-- ⚠ IT ALSO BINDS MIGRATIONS. A future migration that deliberately rehomes an
-- item needs `alter table public.items disable trigger pin_item_row` inside its
-- own begin/commit, or the update reports success and changes nothing.
--
-- NO DELETE POLICY. Removing a homebrew item needs a decision about the
-- inventory stacks referencing it first; still open (NEXT_STEPS, section 1).
--
-- AFTERWARDS: `notify pgrst` is not needed (no new table, column or function
-- the client calls). gen:types changes nothing either. The client still has
-- no edit form; this is the permission half only.
--
-- RUN THE MIGRATION BLOCK BELOW ON ITS OWN, then the verification blocks one at
-- a time.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

create policy "dms edit homebrew items" on public.items
  for update to authenticated
  using (
    campaign_id is not null
    and public.is_campaign_dm(campaign_id)
  )
  with check (
    campaign_id is not null
    and public.is_campaign_dm(campaign_id)
  );

create or replace function public.pin_item_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
begin
  -- The immutable facts, pinned so an edit cannot re-key the item, rehome it
  -- into another campaign (or into the shared catalogue), or re-date it.
  new.id          := old.id;
  new.campaign_id := old.campaign_id;
  new.created_at  := old.created_at;
  return new;
end;
$function$
;

create trigger pin_item_row
  before update on public.items
  for each row execute function public.pin_item_row();

insert into public.schema_migrations (version) values ('053');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Each block is independent. Run them one at a time. Blocks that write end in
-- `rollback`, so nothing here survives.
--
-- Every refusal on UPDATE is a zero-row success, not an error, so these blocks
-- report rows_updated and the value left behind rather than catching 42501.
--
-- The uuids are 037's, so a block cannot quietly test nothing:
--
--   campaign A   d721b412-2750-492e-bddd-7387fc464bba   The cool kids
--   player of A  1313672b-6990-45a6-8a28-c448ca116d2d   Nat
--   DM of A      ea74d56b-8f45-4e4c-80f8-90a6d29b5adf   Dlizard72


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

select
  (select count(*) = 1
     from pg_policies
    where schemaname = 'public' and tablename = 'items'
      and policyname = 'dms edit homebrew items'
      and cmd = 'UPDATE')                                           as update_policy,
  (select count(*) = 1
     from pg_trigger
    where tgrelid = 'public.items'::regclass
      and tgname = 'pin_item_row')                                  as pin_trigger,
  (select not prosecdef
     from pg_proc
    where proname = 'pin_item_row')                                 as trigger_is_invoker,
  (select count(*) = 1
     from public.schema_migrations
    where version = '053')                                          as ledger_row;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the campaign DM edits their own homebrew
-- ---------------------------------------------------------------------------
--
-- The baseline. If this fails, blocks 2 and 3 prove nothing, because a policy
-- that denies everyone passes both of them.
--
-- CORRECT OUTPUT: rows_updated = 1, name_now = 'Fixed Name', price_now = 999.

begin;

select set_config(
  'request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}',
  true
);
set local role authenticated;

insert into public.items (campaign_id, name, price_cp)
values ('d721b412-2750-492e-bddd-7387fc464bba', 'Typo Nmae', 100);

with u as (
  update public.items
     set name = 'Fixed Name', price_cp = 999
   where name = 'Typo Nmae'
     and campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
  returning name, price_cp
)
select 'case 1: DM edits own homebrew' as check,
       jsonb_build_object(
         'rows_updated', (select count(*) from u),
         'name_now',     (select name from u),
         'price_now',    (select price_cp from u)
       ) as result;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: not even the DM can edit a shared catalogue row
-- ---------------------------------------------------------------------------
--
-- The whole reason the policy is homebrew-only. Targets one shared row by id,
-- resolved before switching role, and reports it so "zero rows" can't mean
-- "there was nothing to hit".
--
-- CORRECT OUTPUT: target_found = true, rows_updated = 0.

begin;

select set_config(
  'verification.shared_id',
  (select id::text from public.items where campaign_id is null order by name limit 1),
  true
);

select set_config(
  'request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}',
  true
);
set local role authenticated;

with u as (
  update public.items
     set name = 'Vandalised'
   where id = current_setting('verification.shared_id')::uuid
  returning 1
)
select 'case 2: DM edits a shared row' as check,
       jsonb_build_object(
         'target_found',  current_setting('verification.shared_id') <> '',
         'rows_updated',  (select count(*) from u)
       ) as result;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 3: a player cannot edit their campaign's homebrew
-- ---------------------------------------------------------------------------
--
-- The item is created as the DM, then the role switches to Nat, who can READ
-- it (she is a member) but must not be able to change it.
--
-- CORRECT OUTPUT: visible_to_player = 1, rows_updated = 0.

begin;

select set_config(
  'request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}',
  true
);
set local role authenticated;

insert into public.items (campaign_id, name, price_cp)
values ('d721b412-2750-492e-bddd-7387fc464bba', 'DM Blade', 100);

select set_config(
  'request.jwt.claims',
  '{"sub":"1313672b-6990-45a6-8a28-c448ca116d2d","role":"authenticated"}',
  true
);

with u as (
  update public.items
     set price_cp = 1
   where name = 'DM Blade'
  returning 1
)
select 'case 3: player edits homebrew' as check,
       jsonb_build_object(
         'visible_to_player', (select count(*) from public.items where name = 'DM Blade'),
         'rows_updated',      (select count(*) from u)
       ) as result;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 4: the DM cannot rehome homebrew or make it shared
-- ---------------------------------------------------------------------------
--
-- The pin trigger's job. Nulling campaign_id is reset by the trigger before
-- WITH CHECK ever sees it, so the update "succeeds" with the row still in
-- campaign A and the name change applied.
--
-- CORRECT OUTPUT: rows_updated = 1, campaign_now = campaign A's uuid,
--                 name_now = 'Renamed'.

begin;

select set_config(
  'request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}',
  true
);
set local role authenticated;

insert into public.items (campaign_id, name, price_cp)
values ('d721b412-2750-492e-bddd-7387fc464bba', 'Wandering Item', 100);

with u as (
  update public.items
     set campaign_id = null, name = 'Renamed'
   where name = 'Wandering Item'
  returning campaign_id, name
)
select 'case 4: DM nulls campaign_id' as check,
       jsonb_build_object(
         'rows_updated', (select count(*) from u),
         'campaign_now', (select campaign_id from u),
         'name_now',     (select name from u)
       ) as result;

rollback;

-- db/057_inventory_equipped.sql
--
-- Which carried items a character is wearing or wielding. The sheet derives AC
-- from the equipped armour and shield; until now that choice lived in
-- localStorage because character_inventory had nowhere to put it.
--
-- NO NEW POLICY. 028 already gives character_inventory an UPDATE policy, "owner
-- or dm updates inventory" (can_edit_character), which has had nothing to
-- update since quantity moved behind 030-032's RPCs. Equipping is exactly the
-- owner-or-DM write the rest of the pack already is.
--
-- UN-EQUIPPED BY STOWING, AND THAT IS CORRECT. 032's decrement deletes the row
-- at the last one and 038's transfers delete it on every Stow, so moving armour
-- to the hoard drops the flag with the row. Armour in the party pile is not
-- being worn; nothing needs to clear it.
--
-- ONE ARMOUR, ONE SHIELD is the client's rule, not a constraint. The category
-- lives on items, not here, so a partial unique index can't see it; the sheet
-- un-equips the previous body armour when a new one is equipped.
--
-- ⚠ character_inventory has no pin trigger (028 decided moving a stack between
-- two characters you can edit is harmless). This column doesn't change that.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.
--
-- RUN THE MIGRATION BLOCK BELOW ON ITS OWN.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

alter table public.character_inventory
  add column equipped boolean not null default false;

insert into public.schema_migrations (version) values ('057');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the column exists, the UPDATE policy is still there
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

select
  (select count(*) = 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'character_inventory'
      and column_name = 'equipped' and is_nullable = 'NO')          as column_ok,
  (select count(*) = 1 from pg_policies
    where schemaname = 'public' and tablename = 'character_inventory'
      and cmd = 'UPDATE')                                            as update_policy,
  (select count(*) = 1 from public.schema_migrations
    where version = '057')                                           as ledger_row;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the DM equips something in a player's pack
-- ---------------------------------------------------------------------------
--
-- Picks any stack in campaign A that isn't the DM's own character's.
--
-- CORRECT OUTPUT: target_found = true, rows_updated = 1, equipped_now = true.

begin;

select set_config(
  'verification.entry',
  (select ci.id::text
     from public.character_inventory ci
     join public.characters c on c.id = ci.character_id
    where c.campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
      and c.user_id <> 'ea74d56b-8f45-4e4c-80f8-90a6d29b5adf'
    limit 1),
  true
);
select set_config('request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}', true);
set local role authenticated;

with u as (
  update public.character_inventory set equipped = true
   where id = current_setting('verification.entry')::uuid
  returning equipped
)
select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'target_found', current_setting('verification.entry', true) is not null,
         'rows_updated', (select count(*) from u),
         'equipped_now', (select bool_and(equipped) from u)
       ));

rollback;

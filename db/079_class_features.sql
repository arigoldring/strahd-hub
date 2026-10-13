-- db/079_class_features.sql
--
-- The class features catalogue 054 promised ("they get their own catalogue
-- later (class_id, subclass_id, level)"), plus the one per-character choice
-- the first seeded features need: a Fighter's fighting style. No rows here;
-- 080 seeds the Fighter's two level-1 features.
--
-- TWO CHANGES:
--
--   1. class_features -- one row per feature: the class it belongs to, the
--      subclass if it's an archetype feature (null for the base class's own,
--      like Second Wind), the level it arrives at, and its text. A table, not
--      a map in code, for 054's reason: a homebrew class needs features too,
--      and a code map keyed on class names breaks the first time a DM adds one.
--
--      * The shared-or-mine split again: null campaign_id is the shared PHB
--        row, non-null is one campaign's homebrew. 054's two policies, copied:
--        read shared and own-campaign, DMs insert homebrew. No UPDATE policy;
--        KNOWN_ISSUES already covers "no homebrew forms yet" for this family.
--      * The subclass FK is composite, (subclass_id, class_id) ->
--        subclasses(id, class_id), 056's trick: a Champion feature hung on the
--        Wizard is unrepresentable. MATCH SIMPLE (the default) lets a null
--        subclass_id through, which is exactly the base-class case.
--      * A partial unique index on (class_id, subclass_id, name) for shared
--        rows, NULLS NOT DISTINCT so two base-class rows (both subclass null)
--        still collide. 066's reasoning: later seeds will resolve a feature by
--        name with `into strict`, and a duplicate must be unwritable rather
--        than an ambiguous lookup. Postgres 15+.
--      * `choice` says "this feature carries a picker, of this kind". Data,
--        not a name check in the client, so the Paladin's and Ranger's
--        Fighting Style rows reuse it when they're seeded. THE CHECK AND
--        FEATURE_CHOICES IN src/services/classes.ts ARE ONE LIST IN TWO PLACES.
--
--   2. character_classes.fighting_style -- the pick. A column on the class
--      entry, not a generic choices table:
--      * Per class entry, so a Fighter/Paladin multiclass holds one style per
--        class with no extra design, under 056's existing owner-or-DM UPDATE
--        policy.
--      * THE COST: Champion's Additional Fighting Style (level 10) has nowhere
--        to go. Written down in KNOWN_ISSUES. The time to move to a
--        character_feature_choices table is when maneuvers or invocations
--        arrive, which need many picks per feature; moving one column then is
--        a small migration.
--      * pin_character_class_row is a blocklist (CLAUDE.md) and this column is
--        NOT added to it, deliberately: it is meant to be client-writable.
--      * THE CHECK AND FIGHTING_STYLES IN src/data/rules.ts ARE ONE LIST IN TWO
--        PLACES, as with SKILLS. Six PHB styles, five from Tasha's.
--      * Nothing in the database ties a style to a class that has the feature.
--        The client clears it on a class change, the way it clears
--        subclass_id.
--
-- THE SQL EDITOR WILL OFFER "Run and enable RLS". This file enables RLS on its
-- own table; take the option that runs WITHOUT enabling, as for 067-078.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

create table public.class_features (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  subclass_id uuid,
  campaign_id uuid references public.campaigns(id) on delete cascade,

  level smallint not null check (level between 1 and 20),
  name text not null check (length(btrim(name)) between 1 and 80),
  description text not null,
  choice text check (choice in ('fighting_style')),

  created_at timestamptz not null default now(),

  foreign key (subclass_id, class_id)
    references public.subclasses (id, class_id)
    on delete cascade
);

create unique index class_features_shared_name_key
  on public.class_features (class_id, subclass_id, name)
  nulls not distinct
  where campaign_id is null;

-- 022's index, for 022's read: `campaign_id is null or campaign_id = $1`.
create index on public.class_features (campaign_id);
create index on public.class_features (class_id);

alter table public.class_features enable row level security;

create policy "read shared and own-campaign class features"
  on public.class_features for select to authenticated
  using (campaign_id is null or public.is_campaign_member(campaign_id));

create policy "dms create homebrew class features"
  on public.class_features for insert to authenticated
  with check (campaign_id is not null and public.is_campaign_dm(campaign_id));

alter table public.character_classes
  add column fighting_style text check (fighting_style in (
    -- PHB
    'archery', 'defense', 'dueling', 'great_weapon', 'protection', 'two_weapon',
    -- Tasha's
    'blind_fighting', 'interception', 'superior_technique', 'thrown_weapon',
    'unarmed'
  ));

insert into public.schema_migrations (version) values ('079');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.
--
--   campaign A   d721b412-2750-492e-bddd-7387fc464bba   The cool kids
--   player of A  1313672b-6990-45a6-8a28-c448ca116d2d   Nat
--   DM of A      ea74d56b-8f45-4e4c-80f8-90a6d29b5adf   Dlizard72


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 2 from pg_policies
    where schemaname = 'public' and tablename = 'class_features')       as two_policies,
  (select relrowsecurity from pg_class
    where oid = 'public.class_features'::regclass)                      as rls_on,
  (select count(*) = 1 from pg_indexes
    where schemaname = 'public'
      and indexname = 'class_features_shared_name_key')                 as unique_index,
  (select count(*) = 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'character_classes'
      and column_name = 'fighting_style' and is_nullable = 'YES')       as style_col,
  (select count(*) = 4 from pg_policies
    where schemaname = 'public' and tablename = 'character_classes')    as classes_still_4,
  (select count(*) = 1 from public.schema_migrations
    where version = '079')                                              as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the fighting_style CHECK
-- ---------------------------------------------------------------------------
--
-- Borrows the first character_classes row. Runs as the table owner: this is
-- about the CHECK, not RLS. Each outcome is caught and reported (039's shape).
--
-- CORRECT OUTPUT: two rows: made_up = 'refused', defense = 'ok'.
-- With no characters yet, both read 'skipped'.

begin;

do $$
declare
  v_entry uuid;
begin
  select id into v_entry from public.character_classes limit 1;
  if v_entry is null then
    perform set_config('verification.made_up', 'skipped: no character_classes row', true);
    perform set_config('verification.defense', 'skipped: no character_classes row', true);
    return;
  end if;

  begin
    update public.character_classes set fighting_style = 'kung_fu' where id = v_entry;
    perform set_config('verification.made_up', 'ACCEPTED -- CHECK MISSING', true);
  exception when check_violation then
    perform set_config('verification.made_up', 'refused', true);
  end;

  begin
    update public.character_classes set fighting_style = 'defense' where id = v_entry;
    perform set_config('verification.defense', 'ok', true);
  exception when check_violation then
    perform set_config('verification.defense', 'REFUSED -- should have passed', true);
  end;
end
$$;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'made_up', current_setting('verification.made_up'),
         'defense', current_setting('verification.defense')
       ));

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: owner, DM and a stranger each try to set Nat's style
-- ---------------------------------------------------------------------------
--
-- 056 BLOCK 1's shape, on the new column. A refused UPDATE is a zero-row
-- success, so row counts are what's reported.
--
-- CORRECT OUTPUT: target_found = true, owner_rows = 1, dm_rows = 1,
-- stranger_rows = 0, style_now = 'dueling' (the DM's write, the last landed).
-- target_found = false means Nat has no class picked yet; pick one first.

begin;

select set_config(
  'verification.nat_entry',
  (select cc.id::text from public.character_classes cc
     join public.characters c on c.id = cc.character_id
    where c.campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
      and c.user_id = '1313672b-6990-45a6-8a28-c448ca116d2d'
    limit 1),
  true
);
set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"1313672b-6990-45a6-8a28-c448ca116d2d","role":"authenticated"}', true);
with u as (
  update public.character_classes set fighting_style = 'archery'
   where id = nullif(current_setting('verification.nat_entry'), '')::uuid
  returning 1
) select set_config('verification.owner_rows', count(*)::text, true) from u;

select set_config('request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}', true);
with u as (
  update public.character_classes set fighting_style = 'dueling'
   where id = nullif(current_setting('verification.nat_entry'), '')::uuid
  returning 1
) select set_config('verification.dm_rows', count(*)::text, true) from u;

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
with u as (
  update public.character_classes set fighting_style = 'protection'
   where id = nullif(current_setting('verification.nat_entry'), '')::uuid
  returning 1
) select set_config('verification.stranger_rows', count(*)::text, true) from u;

reset role;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'target_found',  nullif(current_setting('verification.nat_entry', true), '') is not null,
         'owner_rows',    current_setting('verification.owner_rows'),
         'dm_rows',       current_setting('verification.dm_rows'),
         'stranger_rows', current_setting('verification.stranger_rows'),
         'style_now',     (select fighting_style from public.character_classes
                            where id = nullif(current_setting('verification.nat_entry'), '')::uuid)
       ));

rollback;

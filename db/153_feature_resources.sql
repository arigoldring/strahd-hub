-- db/153_feature_resources.sql
--
-- Use counters: Action Surge, superiority dice, Lucky's luck points, spell
-- slots. KNOWN_ISSUES ("Class features are mostly display only") listed every
-- "once per short or long rest" feature as a use nothing tracks. This file is
-- the machinery. 154 on seed the rows, a class at a time.
--
-- TWO TABLES, ONE FOR WHAT A COUNTER IS AND ONE FOR HOW MUCH OF IT IS SPENT:
--
--   1. feature_resources: a counter a class feature or a feat gives. Its
--      maximum is a RULE, not a number, because it grows with level,
--      proficiency or an ability score. src/data/rules.ts (resourceMax)
--      turns the rule into a number for a given character, so nothing here
--      goes stale when a character levels up or raises a score. A row
--      belongs to exactly one feature or one feat.
--
--      Why a table and not columns on class_features: one feature can give
--      more than one counter. Psionic Power has its dice pool and a
--      once-per-short-rest Telekinetic Movement. A feat can give one too, and
--      the same rule shape serves both.
--
--      THE MAXIMUM, formula plus its parameters:
--        steps        a step function of the granting class's level, the
--                     class_feature_picks shape (122) in two parallel arrays:
--                     Action Surge is levels {2,17}, totals {1,2}. Before the
--                     first step the counter has no uses and isn't shown.
--        proficiency  proficiency bonus x multiplier + bonus
--        level        class level x multiplier + bonus (ki, Lay on Hands'
--                     x5). For a feat it's the character's total level.
--        ability      the ability's modifier x multiplier + bonus (Bardic
--                     Inspiration, Divine Sense's 1 + CHA).
--      Every formula but steps has a floor of 1, the book's "(minimum of
--      once)". ONE RULE IN TWO PLACES with resourceMax and RESOURCE_FORMULAS
--      in rules.ts, as with FEATURE_EFFECTS. A new formula is new maths, so
--      it's a migration and a client change together.
--
--      THE RECHARGE: 'short' (a short or a long rest) or 'long' (a long rest
--      only). short_rest_from is for a counter whose recharge improves at a
--      class level, which so far is Bardic Inspiration with Font of
--      Inspiration at 5th. From that level on, a 'long' counter recharges on
--      a short rest too.
--
--   2. character_resource_uses: how many uses a character has SPENT of one
--      counter. No row means none spent. Only spent uses are stored: the
--      maximum is derived (above), so a level-up can't leave a stored
--      maximum disagreeing with the rules. A row spent above a lower new
--      maximum shows as full, and the next write clamps it.
--
--      resource_key names the counter:
--        res:<feature_resources.id>   a feature's or feat's counter
--        slot:<1-9>                   a spell slot level
--        pact                         Pact Magic slots (Warlock)
--      Spell slots have no feature_resources row: their maximum is a table
--      in rules.ts keyed on caster type, so a key is all they need. That
--      model arrives with the slot work (KNOWN_ISSUES, "Spellcasting has no
--      slot or school model"). The key's CHECK accepts it now so that work
--      needs no change to this table.
--
--      Not a foreign key to feature_resources: a slot key has nothing to
--      point at. A spent row whose counter is later deleted is never read.
--
-- use_resource(character, key, delta, cap) is one upsert, 045's shape, so two
-- taps at once (the player and the DM, or two tabs) can't lose one. It clamps
-- to 0..cap. The client passes cap because the maximum is derived on the
-- client. A caller who lies about it misreports only their own character's
-- counter, which they can already set to anything. SECURITY INVOKER: RLS on
-- the table is the boundary, as with adjust_character_hp (056).
--
-- RESTS ARE DELETES, through PostgREST, with no function. A long rest clears
-- every counter (each recharges on one). A short rest clears the keys the
-- client lists as short-rest ones. Either is one DELETE statement, so it's
-- atomic without a function. A refused delete is a zero-row success
-- (KNOWN_ISSUES, the remove*FromCharacter entries), but only a caller who
-- can't edit the character is refused, and the sheet hides the buttons from
-- them.
--
-- WRITES TO feature_resources: none from the app. Shared rows are written by
-- migrations as the table owner. Homebrew features can't define counters
-- yet (KNOWN_ISSUES, "Use counters and rests").
--
-- THE SQL EDITOR WILL OFFER "Run and enable RLS". This file enables RLS on its
-- own tables; take the option that runs WITHOUT enabling (CLAUDE.md).
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- ---------- 1. feature_resources ----------

create table public.feature_resources (
  id uuid primary key default gen_random_uuid(),
  feature_id uuid references public.class_features(id) on delete cascade,
  feat_id    uuid references public.feats(id) on delete cascade,

  name text not null check (length(btrim(name)) between 1 and 80),
  recharge text not null check (recharge in ('short', 'long')),
  short_rest_from smallint check (short_rest_from between 1 and 20),

  formula text not null check (formula in ('steps', 'proficiency', 'level', 'ability')),
  ability text check (ability in ('str', 'dex', 'con', 'int', 'wis', 'cha')),
  multiplier smallint not null default 1 check (multiplier between 1 and 10),
  bonus smallint not null default 0 check (bonus between -10 and 10),
  step_levels smallint[] not null default '{}',
  step_totals smallint[] not null default '{}',

  -- The order a feature's counters are listed in (Psionic Power's dice
  -- before its Telekinetic Movement).
  sort smallint not null default 0,

  check (num_nonnulls(feature_id, feat_id) = 1),
  check ((formula = 'ability') = (ability is not null)),
  check ((formula = 'steps') = (cardinality(step_levels) > 0)),
  check (cardinality(step_levels) = cardinality(step_totals)),
  check (1 <= all (step_levels) and 20 >= all (step_levels)),
  check (0 <= all (step_totals) and 99 >= all (step_totals)),
  -- short_rest_from improves a long-rest counter. On a short-rest one it
  -- would mean nothing.
  check (short_rest_from is null or recharge = 'long')
);

-- A counter's name is unique within its feature or feat. The seeds resolve
-- rows by it.
create unique index feature_resources_feature_name
  on public.feature_resources (feature_id, name) where feature_id is not null;
create unique index feature_resources_feat_name
  on public.feature_resources (feat_id, name) where feat_id is not null;

alter table public.feature_resources enable row level security;

-- Visible when the feature or feat it hangs off is: their own SELECT
-- policies do the campaign scoping, as with class_feature_picks (122).
create policy "read resources of visible features and feats"
  on public.feature_resources for select to authenticated
  using (
    exists (select 1 from public.class_features f
             where f.id = feature_resources.feature_id)
    or exists (select 1 from public.feats t
                where t.id = feature_resources.feat_id)
  );

-- ---------- 2. character_resource_uses ----------

create table public.character_resource_uses (
  character_id uuid not null references public.characters(id) on delete cascade,
  resource_key text not null check (resource_key ~
    '^(res:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|slot:[1-9]|pact)$'),
  used smallint not null check (used between 0 and 999),
  updated_at timestamptz not null default now(),
  primary key (character_id, resource_key)
);

alter table public.character_resource_uses enable row level security;

-- 056's four policies for character_stats, word for word.
create policy "character viewers read resource uses"
  on public.character_resource_uses for select to authenticated
  using (
    exists (
      select 1 from characters c
      where c.id = character_resource_uses.character_id
    )
  );

create policy "owner or dm creates resource uses"
  on public.character_resource_uses for insert to authenticated
  with check (public.can_edit_character(character_id));

create policy "owner or dm edits resource uses"
  on public.character_resource_uses for update to authenticated
  using (public.can_edit_character(character_id))
  with check (public.can_edit_character(character_id));

create policy "owner or dm deletes resource uses"
  on public.character_resource_uses for delete to authenticated
  using (public.can_edit_character(character_id));

-- A row can't move to another character or counter. Only `used` changes.
create or replace function public.pin_character_resource_uses_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
begin
  new.character_id := old.character_id;
  new.resource_key := old.resource_key;
  new.updated_at   := now();
  return new;
end;
$function$
;

create trigger pin_character_resource_uses_row
  before update on public.character_resource_uses
  for each row execute function public.pin_character_resource_uses_row();

-- ---------- 3. use_resource ----------

-- Spend (delta > 0) or restore (delta < 0) uses, clamped to 0..cap, in one
-- statement. Returns the spent count after the write, or no row if RLS
-- refused it. The update branch reads the row as it is after any concurrent
-- write commits, so two +1s make +2.
create or replace function public.use_resource(
  target_character uuid,
  target_key text,
  delta int,
  cap int
)
 returns int
 language sql
 security invoker
 set search_path to 'public'
as $function$
  insert into character_resource_uses as r (character_id, resource_key, used)
  values (
    target_character,
    target_key,
    least(greatest(cap, 0), 999, greatest(0, delta))
  )
  on conflict (character_id, resource_key) do update
    set used = least(greatest(cap, 0), 999, greatest(0, r.used + delta))
  returning used;
$function$
;

insert into public.schema_migrations (version) values ('153');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Each block is independent. Run them one at a time. Blocks that write end in
-- `rollback`, so nothing here survives.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the tables, the function and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

select
  to_regclass('public.feature_resources') is not null        as resources_table,
  to_regclass('public.character_resource_uses') is not null  as uses_table,
  to_regprocedure('public.use_resource(uuid, text, int, int)') is not null
                                                             as use_fn,
  (select relrowsecurity from pg_class
    where oid = 'public.feature_resources'::regclass)        as resources_rls,
  (select relrowsecurity from pg_class
    where oid = 'public.character_resource_uses'::regclass)  as uses_rls,
  (select count(*) = 1 from public.schema_migrations
    where version = '153')                                   as ledger_row;


-- ---------------------------------------------------------------------------
-- BLOCK 1: use_resource clamps both ways
-- ---------------------------------------------------------------------------
--
-- Run as the table owner (the SQL editor), so RLS doesn't apply and this
-- tests the maths only. Any character will do.
--
-- CORRECT OUTPUT: four results, each one row of `t`.

begin;

create temp table t_c on commit drop as
  select id from public.characters limit 1;

select public.use_resource(id, 'slot:1', 1, 2) = 1  as first_use      from t_c;
select public.use_resource(id, 'slot:1', 5, 2) = 2  as capped_at_max  from t_c;
select public.use_resource(id, 'slot:1', -9, 2) = 0 as floored_at_0   from t_c;
select public.use_resource(id, 'pact', 3, 1) = 1    as new_row_capped from t_c;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: a key that isn't a counter is refused
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: ERROR 23514, new row ... violates check constraint
-- "character_resource_uses_resource_key_check".

begin;

select public.use_resource((select id from public.characters limit 1), 'slot:10', 1, 1);

rollback;

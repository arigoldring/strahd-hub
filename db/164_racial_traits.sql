-- db/164_racial_traits.sql
--
-- Racial traits the sheet applies by itself: subraces, the proficiencies,
-- senses and resistances a race grants, a list of traits to read, and use
-- counters for the ones that recharge. 165 seeds the PHB rows and Warforged;
-- 166 puts the two race-level effect keys on their rows once the client is
-- deployed.
--
-- ABILITY SCORE INCREASES ARE STILL NOT STORED. The sheet takes final scores
-- (055), so a racial +2 is something the player types. Decided 2026-11-07;
-- see ACCEPTED_ISSUES. Choices inside a race (Half-Elf's two skills, the
-- Dwarf's tool, a High Elf's cantrip, Dragonborn ancestry, an extra
-- language) are manual too: the trait text says what to pick.
--
-- WHAT THIS ADDS:
--
--   subraces       054's catalogue shape (null campaign_id = shared row,
--                  otherwise one campaign's homebrew), keyed to a race.
--                  `speed` and `darkvision` are null for "the race's"; a
--                  subrace can only add to the grant lists, never take a
--                  race's away, so the client unions the two. unique
--                  (id, race_id) so character_stats can carry a composite FK.
--   race_traits    the readable list, class_features' shape: race_id, plus
--                  subrace_id null for a trait every subrace has. A
--                  composite FK makes "a High Elf trait on the Dwarf"
--                  unrepresentable.
--   grant columns  on races and subraces, all inputs the sheet derives from:
--                    darkvision            feet, null for none
--                    skill_proficiencies   SkillKeys ('perception')
--                    weapon_proficiencies  shared weapon names, 161's rule
--                    armor_proficiencies   'light' 'medium' 'heavy' 'shield'
--                    tool_proficiencies    free text, display only
--                    languages             free text, display only
--                    resistances           damage types, display only
--   subraces.effect   one effect_key, like races.effect (159). Hill Dwarf's
--                    Dwarven Toughness is the first.
--   feature_resources.race_trait_id   a third parent for a counter (153),
--                    so Breath Weapon and Relentless Endurance count down
--                    like Action Surge. They read total level, as a feat's
--                    do.
--   character_stats.subrace_id   with a composite FK to subraces
--                    (id, race_id), so a subrace of another race can't be
--                    stored. Changing race must clear the subrace in the same
--                    write; the client does, and the FK refuses it otherwise.
--
-- WHY DERIVED AND NOT WRITTEN. A race's proficiencies are read off the
-- catalogue every render, the way class weapon lists are (161), not inserted
-- into character_proficiencies on pick. Nothing is stored that could
-- disagree with the race, and changing race needs no cleanup. The cost is the
-- 161 one: a racial proficiency can't be switched off on the sheet. A skill
-- the race grants can still be raised to expertise with a stored row.
--
-- WHY THE GRANTS ARE COLUMNS AND NOT ROWS ON THE TRAITS. The class side put
-- weapon lists on `classes` (161), not on features, and the sheet already has
-- one rule for unioning a source's list into the proficiency map. A link
-- table (trait -> grant) would let a trait own its grant, which matters only
-- for homebrew that nobody can create yet (no race form, KNOWN_ISSUES).
--
-- THREE NEW EFFECT KEYS. The domain gains
-- dwarven_toughness (+1 HP per level), savage_attacks (one extra weapon die
-- on a melee crit) and heavy_armor_speed (heavy armour's STR requirement
-- costs no speed). Widening the domain is safe any time; putting a key on a
-- row the deployed client parses is not (CLAUDE.md). subraces.effect is safe
-- in 165 because no deployed client reads subraces. races.effect is parsed
-- by the deployed client, so the Dwarf's and Half-Orc's keys wait for 166.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.
--
-- Run by Claude via `npx supabase db query --linked`. In the SQL editor,
-- this file creates tables, so the "enable RLS" prompt is harmless here, but
-- both tables enable it themselves.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- ---------- 1. effect keys ----------

alter domain public.effect_key drop constraint effect_key_check;
alter domain public.effect_key add constraint effect_key_check check (value in (
  -- 121 and 150
  'extra_attack', 'extra_attack_fighter', 'improved_critical',
  'superior_critical', 'sneak_attack', 'martial_arts',
  'jack_of_all_trades', 'remarkable_athlete', 'dread_ambusher',
  'tactical_wit', 'rakish_audacity', 'aura_of_protection',
  'fast_movement', 'unarmored_movement', 'draconic_resilience',
  'battle_ready',
  -- 159
  'brutal_critical', 'integrated_protection', 'alert', 'observant',
  'mobile', 'tough', 'medium_armor_master',
  -- 164
  'dwarven_toughness', 'savage_attacks', 'heavy_armor_speed'
));

-- ---------- 2. grant columns on races ----------
--
-- The skill list is 056's CHECK on character_proficiencies, and SKILLS in
-- rules.ts: one list in three places now. The damage types are the PHB's
-- thirteen; nothing in the client parses them.

alter table public.races
  add column darkvision smallint check (darkvision between 1 and 300),
  add column skill_proficiencies text[] not null default '{}'
    check (skill_proficiencies <@ array[
      'acrobatics', 'animalHandling', 'arcana', 'athletics', 'deception',
      'history', 'insight', 'intimidation', 'investigation', 'medicine',
      'nature', 'perception', 'performance', 'persuasion', 'religion',
      'sleightOfHand', 'stealth', 'survival']),
  add column weapon_proficiencies text[] not null default '{}',
  add column armor_proficiencies text[] not null default '{}'
    check (armor_proficiencies <@ array['light', 'medium', 'heavy', 'shield']),
  add column tool_proficiencies text[] not null default '{}',
  add column languages text[] not null default '{}',
  add column resistances text[] not null default '{}'
    check (resistances <@ array[
      'acid', 'bludgeoning', 'cold', 'fire', 'force', 'lightning',
      'necrotic', 'piercing', 'poison', 'psychic', 'radiant', 'slashing',
      'thunder']);

-- ---------- 3. subraces ----------

create table public.subraces (
  id uuid primary key default gen_random_uuid(),
  race_id uuid not null references public.races(id) on delete cascade,
  campaign_id uuid references public.campaigns(id) on delete cascade,

  name text not null check (length(btrim(name)) between 1 and 60),
  description text not null default '',
  -- Null: the race's speed (Wood Elf's 35 is the one that isn't).
  speed smallint check (speed between 0 and 120),
  -- Null: the race's darkvision. The client takes the better of the two.
  darkvision smallint check (darkvision between 1 and 300),
  effect public.effect_key,

  skill_proficiencies text[] not null default '{}'
    check (skill_proficiencies <@ array[
      'acrobatics', 'animalHandling', 'arcana', 'athletics', 'deception',
      'history', 'insight', 'intimidation', 'investigation', 'medicine',
      'nature', 'perception', 'performance', 'persuasion', 'religion',
      'sleightOfHand', 'stealth', 'survival']),
  weapon_proficiencies text[] not null default '{}',
  armor_proficiencies text[] not null default '{}'
    check (armor_proficiencies <@ array['light', 'medium', 'heavy', 'shield']),
  tool_proficiencies text[] not null default '{}',
  languages text[] not null default '{}',
  resistances text[] not null default '{}'
    check (resistances <@ array[
      'acid', 'bludgeoning', 'cold', 'fire', 'force', 'lightning',
      'necrotic', 'piercing', 'poison', 'psychic', 'radiant', 'slashing',
      'thunder']),

  created_at timestamptz not null default now(),

  unique (id, race_id)
);

-- 066's index, for 066's reason: the seed resolves a subrace by race and name
-- with `into strict`, so a duplicate must be unwritable.
create unique index subraces_shared_race_name_key
  on public.subraces (race_id, name)
  where campaign_id is null;

create index on public.subraces (campaign_id);

alter table public.subraces enable row level security;

create policy "read shared and own-campaign subraces"
  on public.subraces for select to authenticated
  using (campaign_id is null or public.is_campaign_member(campaign_id));

create policy "dms create homebrew subraces"
  on public.subraces for insert to authenticated
  with check (campaign_id is not null and public.is_campaign_dm(campaign_id));

-- ---------- 4. race_traits ----------

create table public.race_traits (
  id uuid primary key default gen_random_uuid(),
  race_id uuid not null references public.races(id) on delete cascade,
  subrace_id uuid,
  campaign_id uuid references public.campaigns(id) on delete cascade,

  name text not null check (length(btrim(name)) between 1 and 80),
  description text not null default '',
  -- The order traits are listed in, the book's order.
  sort smallint not null default 0,

  created_at timestamptz not null default now(),

  -- MATCH SIMPLE: a null subrace_id is a trait of the whole race.
  foreign key (subrace_id, race_id)
    references public.subraces (id, race_id) on delete cascade
);

-- 079's index: 165 resolves a trait by race, subrace and name.
create unique index race_traits_shared_name_key
  on public.race_traits (race_id, subrace_id, name)
  nulls not distinct
  where campaign_id is null;

create index on public.race_traits (campaign_id);

alter table public.race_traits enable row level security;

create policy "read shared and own-campaign race traits"
  on public.race_traits for select to authenticated
  using (campaign_id is null or public.is_campaign_member(campaign_id));

create policy "dms create homebrew race traits"
  on public.race_traits for insert to authenticated
  with check (campaign_id is not null and public.is_campaign_dm(campaign_id));

-- ---------- 5. counters on race traits ----------

alter table public.feature_resources
  add column race_trait_id uuid references public.race_traits(id) on delete cascade;

-- 153's unnamed CHECK, auto-named by Postgres.
alter table public.feature_resources drop constraint feature_resources_check;
alter table public.feature_resources
  add constraint feature_resources_one_parent
  check (num_nonnulls(feature_id, feat_id, race_trait_id) = 1);

create unique index feature_resources_race_trait_name
  on public.feature_resources (race_trait_id, name) where race_trait_id is not null;

drop policy "read resources of visible features and feats" on public.feature_resources;
create policy "read resources of visible features, feats and race traits"
  on public.feature_resources for select to authenticated
  using (
    exists (select 1 from public.class_features f
             where f.id = feature_resources.feature_id)
    or exists (select 1 from public.feats t
                where t.id = feature_resources.feat_id)
    or exists (select 1 from public.race_traits r
                where r.id = feature_resources.race_trait_id)
  );

-- ---------- 6. the character's subrace ----------

alter table public.character_stats
  add column subrace_id uuid,
  add constraint character_stats_subrace_fkey
    foreign key (subrace_id, race_id)
    references public.subraces (id, race_id)
    on delete set null (subrace_id);

-- ---------- 7. assert the end state ----------

do $$
declare
  v_count int;
begin
  select count(*) into v_count
    from pg_policies
   where schemaname = 'public' and tablename in ('subraces', 'race_traits');
  if v_count <> 4 then
    raise exception '% policies on subraces and race_traits (expected 4). Rolled back.', v_count;
  end if;

  select count(*) into v_count
    from pg_policies
   where schemaname = 'public' and tablename = 'feature_resources';
  if v_count <> 1 then
    raise exception '% policies on feature_resources (expected 1). Rolled back.', v_count;
  end if;

  -- The 23 keys and 24 keyed rows of 159/160 survived the domain rebuild.
  select count(*) into v_count
    from public.class_features where effect is not null;
  if v_count <> 24 then
    raise exception '% keyed class features (expected 24). Rolled back.', v_count;
  end if;
end
$$;

insert into public.schema_migrations (version) values ('164');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 2 from pg_policies
    where tablename = 'subraces')                                     as subrace_policies,
  (select count(*) = 2 from pg_policies
    where tablename = 'race_traits')                                  as trait_policies,
  (select count(*) = 7 from information_schema.columns
    where table_schema = 'public' and table_name = 'races'
      and column_name in ('darkvision', 'skill_proficiencies',
        'weapon_proficiencies', 'armor_proficiencies',
        'tool_proficiencies', 'languages', 'resistances'))            as race_columns,
  (select domain_name = 'effect_key' from information_schema.columns
    where table_schema = 'public' and table_name = 'subraces'
      and column_name = 'effect')                                     as subrace_effect,
  (select count(*) = 1 from pg_constraint
    where conname = 'character_stats_subrace_fkey')                   as stats_fk,
  (select count(*) = 0 from pg_constraint
    where conname = 'feature_resources_check')                        as old_check_gone,
  (select count(*) = 1 from public.schema_migrations
    where version = '164')                                            as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: a subrace of another race is refused
-- ---------------------------------------------------------------------------
--
-- Builds two throwaway races and a subrace of the first, then points a
-- character's stats at (subrace of A, race B). 039's shape: the refusal is
-- caught and reported as a row. Needs at least one character.
--
-- CORRECT OUTPUT: one row, `refused` = t.

begin;

create temp table result (refused boolean) on commit drop;

do $$
declare
  v_a uuid;
  v_b uuid;
  v_sub uuid;
  v_char uuid;
begin
  insert into public.races (name, speed) values ('Test A', 30) returning id into v_a;
  insert into public.races (name, speed) values ('Test B', 30) returning id into v_b;
  insert into public.subraces (race_id, name) values (v_a, 'Test Sub') returning id into v_sub;
  select character_id into strict v_char from public.character_stats limit 1;

  begin
    update public.character_stats
       set race_id = v_b, subrace_id = v_sub
     where character_id = v_char;
    insert into result values (false);
  exception when foreign_key_violation then
    insert into result values (true);
  end;
end
$$;

select * from result;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: a counter with two parents is refused
-- ---------------------------------------------------------------------------
--
-- Needs a race trait, so run it after 165.
--
-- CORRECT OUTPUT: one row, `refused` = t.

begin;

create temp table result (refused boolean) on commit drop;

do $$
declare
  v_trait uuid;
  v_feat uuid;
begin
  select id into strict v_trait from public.race_traits limit 1;
  select id into strict v_feat from public.feats limit 1;
  begin
    insert into public.feature_resources
      (race_trait_id, feat_id, name, recharge, formula, step_levels, step_totals)
    values (v_trait, v_feat, 'Two parents', 'long', 'steps', '{1}', '{1}');
    insert into result values (false);
  exception when check_violation then
    insert into result values (true);
  end;
end
$$;

select * from result;

rollback;

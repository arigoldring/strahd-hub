-- db/169_pallid_eladrin_reborn.sql
--
-- Three player options from outside the PHB, added because players in the
-- campaign are using them:
--
--   * Pallid Elf (Explorer's Guide to Wildemount), an Elf subrace
--   * Eladrin (Mordenkainen's Tome of Foes, 2018), an Elf subrace. The 2022
--     Monsters of the Multiverse Eladrin is a separate race with
--     proficiency-bonus Fey Steps; MToF's was chosen, decided 2026-11-07.
--   * Reborn (Van Richten's Guide to Ravenloft), a lineage, seeded as a race
--
-- All three are SHARED rows (null campaign_id), Warforged's precedent (148):
-- nothing in the app creates races, and a published option belongs in every
-- campaign's picker.
--
-- REBORN IS A RACE ROW, NOT A LAYER OVER ONE. A lineage replaces your race;
-- what the book lets you keep from the old one (its skill proficiencies and
-- any climb, fly or swim speed) is something a player enters with the
-- ordinary controls. A lineage_id beside race_id was considered and
-- rejected: a second source every rule in rules.ts would have to merge, for
-- what the stored-skill path already covers. Decided 2026-11-07.
--
-- WHAT THE SHEET COMPUTES FROM THIS FILE, AND WHAT IT DOESN'T:
--   * Pallid Elf and Eladrin inherit Elf's darkvision, Perception and traits
--     through the race row; neither adds a weapon list.
--   * Counters: Pallid Elf's sleep (3rd) and invisibility (5th), Drow Magic's
--     shape; Eladrin's Fey Step, once per short rest; Reborn's Knowledge
--     from a Past Life, proficiency-bonus uses per long rest (153's
--     'proficiency' formula, read at total level like every race counter).
--   * Reborn's poison resistance is a grant column.
--   * Text only: Incisive Sense's advantage, Eladrin's season (a choice),
--     everything in Deathless Nature, Reborn's size (Small or Medium; races
--     holds one value, so the row says medium and the trait says choose).
--   * Not stored, as for every race (ACCEPTED_ISSUES): ability score
--     increases, Reborn's extra language and its Ancestral Legacy skills.
--
-- Trait text is a short summary in our own words with every number kept.
-- Written from memory, 2026-11-07; check against the books, especially
-- Fey Step's season effects and Ancestral Legacy's two-skill fallback.
--
-- SHAPE: 165's. Rows written once into temp tables, inserts guarded by
-- `not exists`, a pre-check that every name resolves, and an assertion of
-- the end state for the rows this file is about. One difference: the
-- counters table carries a formula, because Reborn's isn't 'steps'.
--
-- No schema change, so no reload and no gen:types.
--
-- Run by Claude via `npx supabase db query --linked`. In the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): the temp tables are dropped on
-- commit.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- ---------- 1. Reborn's race row ----------
--
-- races has no unique name, so the guard is `not exists` and section 3's
-- pre-check is what refuses a duplicate.

insert into public.races (name, speed, size, description)
select 'Reborn', 30, 'medium',
       $$Someone who died and came back: a revived corpse, a body rebuilt, or a soul in a new form, carrying fragments of a life they can't fully remember.$$
 where not exists (
   select 1 from public.races r
    where r.campaign_id is null and r.name = 'Reborn'
 );

-- ---------- 2. the rows, written once ----------

create temp table seed_races (
  name text primary key,
  darkvision smallint,
  skills text[] not null default '{}',
  weapons text[] not null default '{}',
  languages text[] not null default '{}',
  resistances text[] not null default '{}'
) on commit drop;

insert into seed_races (name, darkvision, skills, weapons, languages, resistances) values
  ('Reborn', null, '{}', '{}', array['Common'], array['poison']);

create temp table seed_subraces (
  race text not null,
  name text not null,
  description text not null,
  speed smallint,
  darkvision smallint,
  effect text,
  weapons text[] not null default '{}',
  armor text[] not null default '{}',
  tools text[] not null default '{}',
  resistances text[] not null default '{}',
  primary key (race, name)
) on commit drop;

insert into seed_subraces
  (race, name, description, speed, darkvision, effect, weapons, armor, tools, resistances)
values
  ('Elf', 'Pallid Elf',
   $$Pale, mystical elves blessed by the moon goddess, with sharp insight and quiet magic.$$,
   null, null, null, '{}', '{}', '{}', '{}'),
  ('Elf', 'Eladrin',
   $$Elves of the Feywild whose moods and magic follow the seasons.$$,
   null, null, null, '{}', '{}', '{}', '{}');

create temp table seed_traits (
  race text not null,
  subrace text,
  sort smallint not null,
  name text not null,
  description text not null
) on commit drop;

insert into seed_traits (race, subrace, sort, name, description) values
  -- Pallid Elf (sorts from 20, after the PHB subraces' 10-13)
  ('Elf', 'Pallid Elf', 20, 'Incisive Sense',
   $$Advantage on Intelligence (Investigation) and Wisdom (Insight) checks.$$),
  ('Elf', 'Pallid Elf', 21, 'Blessing of the Moon Weaver',
   $$You know the light cantrip. From 3rd level you can cast sleep once, and from 5th level invisibility on yourself only once, each regained on a long rest and needing no material components. Wisdom is your spellcasting ability for these.$$),

  -- Eladrin (MToF)
  ('Elf', 'Eladrin', 20, 'Fey Step',
   $$As a bonus action, teleport up to 30 ft to an unoccupied space you can see. Once per short or long rest. From 3rd level it also has your season's effect; any save is DC 8 + your proficiency bonus + your CHA modifier.$$),
  ('Elf', 'Eladrin', 21, 'Seasons',
   $$Choose a season (you may change it when you finish a long rest). Its Fey Step effect from 3rd level: Autumn, up to two creatures you can see within 10 ft make a WIS save or are charmed by you for 1 minute, or until you or your companions damage them. Winter, before you teleport, one creature you can see within 5 ft makes a WIS save or is frightened of you until the end of your next turn. Spring, instead of you, one willing creature you touch within 5 ft teleports, to a space you can see within 30 ft. Summer, after you teleport, each creature you choose within 5 ft takes fire damage equal to your CHA modifier (minimum 1). Record your season yourself.$$),

  -- Reborn (VRGtR)
  ('Reborn', null, 1, 'Creature Type and Size',
   $$You are a humanoid. You are Medium or Small, chosen when you take this lineage; the sheet shows Medium.$$),
  ('Reborn', null, 2, 'Ancestral Legacy',
   $$If you replaced a race with this lineage, you may keep its skill proficiencies and any climbing, flying or swimming speed. If you keep none of them, or took this lineage at character creation, gain proficiency in two skills of your choice instead. Add them yourself.$$),
  ('Reborn', null, 3, 'Deathless Nature',
   $$Advantage on saving throws against disease and being poisoned, and resistance to poison damage. Advantage on death saving throws. You don't need to eat, drink or breathe, and you don't sleep; magic can't put you to sleep. A long rest takes you 4 hours, spent inactive and motionless but conscious.$$),
  ('Reborn', null, 4, 'Knowledge from a Past Life',
   $$When you make an ability check that uses a skill, you can roll a d6 after seeing the d20 and add it to the check. Uses equal your proficiency bonus, all regained on a long rest.$$),
  ('Reborn', null, 5, 'Extra Language',
   $$You speak, read and write Common and one other language you and the DM agree on. Add it yourself.$$);

create temp table seed_resources (
  race text not null,
  subrace text,
  trait text not null,
  name text not null,
  recharge text not null,
  formula text not null,
  step_levels smallint[] not null,
  step_totals smallint[] not null,
  sort smallint not null
) on commit drop;

insert into seed_resources values
  ('Elf',    'Pallid Elf', 'Blessing of the Moon Weaver', 'Sleep',        'long',  'steps',       '{3}', '{1}', 0),
  ('Elf',    'Pallid Elf', 'Blessing of the Moon Weaver', 'Invisibility', 'long',  'steps',       '{5}', '{1}', 1),
  ('Elf',    'Eladrin',    'Fey Step',                    'Fey Step',     'short', 'steps',       '{1}', '{1}', 0),
  ('Reborn', null,         'Knowledge from a Past Life',  'Knowledge from a Past Life',
                                                                          'long',  'proficiency', '{}',  '{}',  0);

-- ---------- 3. every name resolves, before anything else is written ----------

do $do$
declare
  v_missing text;
begin
  select string_agg(s.name, ', ') into v_missing
    from (select name from seed_races
          union select race from seed_subraces
          union select race from seed_traits) s
   where (select count(*) from public.races r
           where r.name = s.name and r.campaign_id is null) <> 1;
  if v_missing is not null then
    raise exception 'Races not found exactly once as shared rows: %. Rolled back.', v_missing;
  end if;

  select string_agg(t.subrace, ', ') into v_missing
    from seed_traits t
   where t.subrace is not null
     and not exists (select 1 from seed_subraces s
                      where s.race = t.race and s.name = t.subrace);
  if v_missing is not null then
    raise exception 'Traits name unknown subraces: %. Rolled back.', v_missing;
  end if;

  select string_agg(x.trait, ', ') into v_missing
    from seed_resources x
   where not exists (select 1 from seed_traits t
                      where t.race = x.race
                        and t.subrace is not distinct from x.subrace
                        and t.name = x.trait);
  if v_missing is not null then
    raise exception 'Counters name unknown traits: %. Rolled back.', v_missing;
  end if;
end
$do$;

-- ---------- 4. grants on Reborn ----------

update public.races r
   set darkvision           = s.darkvision,
       skill_proficiencies  = s.skills,
       weapon_proficiencies = s.weapons,
       languages            = s.languages,
       resistances          = s.resistances
  from seed_races s
 where r.name = s.name and r.campaign_id is null;

-- ---------- 5. subraces ----------

insert into public.subraces
  (race_id, name, description, speed, darkvision, effect,
   weapon_proficiencies, armor_proficiencies, tool_proficiencies, resistances)
select r.id, s.name, s.description, s.speed, s.darkvision, s.effect::public.effect_key,
       s.weapons, s.armor, s.tools, s.resistances
  from seed_subraces s
  join public.races r on r.name = s.race and r.campaign_id is null
 where not exists (
   select 1 from public.subraces x
    where x.race_id = r.id and x.name = s.name and x.campaign_id is null
 );

-- ---------- 6. traits ----------

insert into public.race_traits (race_id, subrace_id, sort, name, description)
select r.id, sr.id, t.sort, t.name, t.description
  from seed_traits t
  join public.races r on r.name = t.race and r.campaign_id is null
  left join public.subraces sr
    on sr.race_id = r.id and sr.name = t.subrace and sr.campaign_id is null
 where not exists (
   select 1 from public.race_traits x
    where x.race_id = r.id
      and x.subrace_id is not distinct from sr.id
      and x.name = t.name
      and x.campaign_id is null
 );

-- ---------- 7. counters ----------

insert into public.feature_resources
  (race_trait_id, name, recharge, formula, step_levels, step_totals, sort)
select tr.id, x.name, x.recharge, x.formula, x.step_levels, x.step_totals, x.sort
  from seed_resources x
  join public.races r on r.name = x.race and r.campaign_id is null
  left join public.subraces sr
    on sr.race_id = r.id and sr.name = x.subrace and sr.campaign_id is null
  join public.race_traits tr
    on tr.race_id = r.id
   and tr.subrace_id is not distinct from sr.id
   and tr.name = x.trait
   and tr.campaign_id is null
 where not exists (
   select 1 from public.feature_resources f
    where f.race_trait_id = tr.id and f.name = x.name
 );

-- ---------- 8. assert the end state, not the work ----------

do $do$
declare
  v_count int;
  v_expected int;
begin
  select count(*) into v_count
    from public.races r
   where r.campaign_id is null and r.name = 'Reborn'
     and r.speed = 30 and r.size = 'medium'
     and r.darkvision is null
     and r.skill_proficiencies = '{}'
     and r.weapon_proficiencies = '{}'
     and r.languages = array['Common']
     and r.resistances = array['poison'];
  if v_count <> 1 then
    raise exception '% shared Reborn rows as written (expected 1). Rolled back.', v_count;
  end if;

  select count(*) into v_count
    from seed_subraces s
    join public.races r on r.name = s.race and r.campaign_id is null
    join public.subraces x on x.race_id = r.id and x.name = s.name and x.campaign_id is null
   where x.speed is not distinct from s.speed
     and x.darkvision is not distinct from s.darkvision
     and x.effect::text is not distinct from s.effect
     and x.weapon_proficiencies = s.weapons
     and x.armor_proficiencies = s.armor
     and x.tool_proficiencies = s.tools
     and x.resistances = s.resistances;
  select count(*) into v_expected from seed_subraces;
  if v_count <> v_expected then
    raise exception '% of % subraces as written. Rolled back.', v_count, v_expected;
  end if;

  select count(*) into v_count
    from seed_traits t
    join public.races r on r.name = t.race and r.campaign_id is null
    left join public.subraces sr
      on sr.race_id = r.id and sr.name = t.subrace and sr.campaign_id is null
    join public.race_traits x
      on x.race_id = r.id and x.subrace_id is not distinct from sr.id
     and x.name = t.name and x.campaign_id is null
   where (t.subrace is null) = (sr.id is null)
     and x.description = t.description
     and x.sort = t.sort;
  select count(*) into v_expected from seed_traits;
  if v_count <> v_expected then
    raise exception '% of % traits as written. Rolled back.', v_count, v_expected;
  end if;

  select count(*) into v_count
    from seed_resources x
    join public.races r on r.name = x.race and r.campaign_id is null
    left join public.subraces sr
      on sr.race_id = r.id and sr.name = x.subrace and sr.campaign_id is null
    join public.race_traits tr
      on tr.race_id = r.id and tr.subrace_id is not distinct from sr.id
     and tr.name = x.trait and tr.campaign_id is null
    join public.feature_resources f
      on f.race_trait_id = tr.id and f.name = x.name
   where f.recharge = x.recharge
     and f.formula = x.formula
     and f.step_levels = x.step_levels
     and f.step_totals = x.step_totals;
  select count(*) into v_expected from seed_resources;
  if v_count <> v_expected then
    raise exception '% of % counters as written. Rolled back.', v_count, v_expected;
  end if;
end
$do$;

insert into public.schema_migrations (version) values ('169');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: spot checks and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 11 from public.subraces where campaign_id is null)    as eleven_subraces,
  (select count(*) = 62 from public.race_traits where campaign_id is null) as traits_53_plus_9,
  (select count(*) = 10 from public.feature_resources
    where race_trait_id is not null)                                       as counters_6_plus_4,
  (select count(*) = 1 from public.races
    where name = 'Reborn' and campaign_id is null)                         as one_reborn,
  (select count(*) = 1 from public.feature_resources f
     join public.race_traits t on t.id = f.race_trait_id
    where t.name = 'Knowledge from a Past Life'
      and f.formula = 'proficiency')                                       as reborn_counter,
  (select count(*) = 1 from public.schema_migrations
    where version = '169')                                                 as ledger_row;

rollback;

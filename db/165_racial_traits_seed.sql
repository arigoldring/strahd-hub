-- db/165_racial_traits_seed.sql
--
-- Seeds 164's racial data for the shared races: the nine of the 2014 PHB
-- (055) and Warforged (148). RUN 164 FIRST.
--
--   * grants on the ten races (darkvision, skills, weapons, languages,
--     resistances)
--   * the PHB's nine subraces: Hill and Mountain Dwarf; High Elf, Wood Elf and
--     Drow; Forest and Rock Gnome; Lightfoot and Stout Halfling
--   * 53 traits, each race's in the book's order, subrace traits after
--   * 6 use counters: Breath Weapon, Relentless Endurance, and the 3rd- and
--     5th-level spells of Drow Magic and Infernal Legacy
--   * Hill Dwarf's dwarven_toughness key
--
-- SAFE TO RUN BEFORE THE CLIENT IS DEPLOYED. The deployed client reads races
-- with select("*"), so new columns are ignored, and it never reads subraces,
-- race_traits or a counter whose parent is a race trait. The two keys that
-- go on `races` itself (Dwarf, Half-Orc) are 166's, because the deployed
-- client does parse races.effect.
--
-- NOT SEEDED, ON PURPOSE:
--   * ability score increases (055: the sheet takes final scores)
--   * anything a player chooses: Dragonborn ancestry (and so its resistance),
--     Half-Elf's two skills, the Dwarf's tool, a High Elf's cantrip, the
--     extra language of Humans, Half-Elves, High Elves and Warforged, and
--     Warforged's Specialized Design skill and tool. The trait text says what
--     to pick. See ACCEPTED_ISSUES.
--   * Variant Human (an optional PHB rule) and every non-PHB race but
--     Warforged
--   * innate spells as spell-list entries: they're trait text, and only the
--     once-a-day ones get counters. Cantrips are at will.
--
-- Trait text is a short summary in our own words with every number kept,
-- the class-feature rule (CLAUDE.md). Written from memory of the PHB and
-- ERLW, 2026-11-07; check against the books.
--
-- SHAPE: 130's. Rows written once into temp tables, inserts guarded by
-- `not exists` on the shared row, then an assertion of the end state. A
-- race or subrace name that matches nothing would insert nothing and
-- succeed, so a pre-check raises before any insert if a name doesn't
-- resolve.
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

-- ---------- 1. the rows, written once ----------

create temp table seed_races (
  name text primary key,
  darkvision smallint,
  skills text[] not null default '{}',
  weapons text[] not null default '{}',
  languages text[] not null default '{}',
  resistances text[] not null default '{}'
) on commit drop;

insert into seed_races (name, darkvision, skills, weapons, languages, resistances) values
  ('Dragonborn', null, '{}', '{}',
   array['Common', 'Draconic'], '{}'),
  ('Dwarf', 60, '{}', array['Battleaxe', 'Handaxe', 'Light Hammer', 'Warhammer'],
   array['Common', 'Dwarvish'], array['poison']),
  ('Elf', 60, array['perception'], '{}',
   array['Common', 'Elvish'], '{}'),
  ('Gnome', 60, '{}', '{}',
   array['Common', 'Gnomish'], '{}'),
  ('Half-Elf', 60, '{}', '{}',
   array['Common', 'Elvish'], '{}'),
  ('Half-Orc', 60, array['intimidation'], '{}',
   array['Common', 'Orc'], '{}'),
  ('Halfling', null, '{}', '{}',
   array['Common', 'Halfling'], '{}'),
  ('Human', null, '{}', '{}',
   array['Common'], '{}'),
  ('Tiefling', 60, '{}', '{}',
   array['Common', 'Infernal'], array['fire']),
  ('Warforged', null, '{}', '{}',
   array['Common'], array['poison']);

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
  ('Dwarf', 'Hill Dwarf',
   $$Keen-sensed and deeply resilient dwarves of the hills and valleys.$$,
   null, null, 'dwarven_toughness', '{}', '{}', '{}', '{}'),
  ('Dwarf', 'Mountain Dwarf',
   $$Strong, hardy dwarves of the high peaks, used to a life in armour.$$,
   null, null, null, '{}', array['light', 'medium'], '{}', '{}'),
  ('Elf', 'High Elf',
   $$Keen-minded elves with a natural knack for magic.$$,
   null, null, null, array['Longsword', 'Shortsword', 'Shortbow', 'Longbow'], '{}', '{}', '{}'),
  ('Elf', 'Wood Elf',
   $$Swift, stealthy elves of the deep forests.$$,
   35, null, null, array['Longsword', 'Shortsword', 'Shortbow', 'Longbow'], '{}', '{}', '{}'),
  ('Elf', 'Drow',
   $$Dark elves of the Underdark, at home in the dark and pained by the sun.$$,
   null, 120, null, array['Rapier', 'Shortsword', 'Crossbow, Hand'], '{}', '{}', '{}'),
  ('Gnome', 'Forest Gnome',
   $$Reclusive gnomes with a gift for illusion and a friendship with small animals.$$,
   null, null, null, '{}', '{}', '{}', '{}'),
  ('Gnome', 'Rock Gnome',
   $$Inventive gnomes, hardier than their kin, who tinker with clockwork.$$,
   null, null, null, '{}', '{}', array['Tinker''s Tools'], '{}'),
  ('Halfling', 'Lightfoot',
   $$Easygoing halflings who slip out of notice behind larger folk.$$,
   null, null, null, '{}', '{}', '{}', '{}'),
  ('Halfling', 'Stout',
   $$Hardier halflings, said to have a little dwarven blood.$$,
   null, null, null, '{}', '{}', '{}', array['poison']);

create temp table seed_traits (
  race text not null,
  subrace text,
  sort smallint not null,
  name text not null,
  description text not null
) on commit drop;

insert into seed_traits (race, subrace, sort, name, description) values
  -- Dragonborn
  ('Dragonborn', null, 1, 'Draconic Ancestry',
   $$Choose a dragon type (black, blue, brass, bronze, copper, gold, green, red, silver or white). It sets your breath weapon's damage type, area and saving throw, and your damage resistance; see the PHB's Draconic Ancestry table. Record it yourself.$$),
  ('Dragonborn', null, 2, 'Breath Weapon',
   $$As an action, exhale destructive energy in your ancestry's area (a 5 by 30 ft line or a 15 ft cone). Each creature in it makes a DEX or CON save (by ancestry), DC 8 + your CON modifier + your proficiency bonus, taking 2d6 damage on a failure and half on a success. The damage rises to 3d6 at 6th level, 4d6 at 11th and 5d6 at 16th. Once per short or long rest.$$),
  ('Dragonborn', null, 3, 'Damage Resistance',
   $$Resistance to the damage type of your draconic ancestry.$$),

  -- Dwarf
  ('Dwarf', null, 1, 'Darkvision',
   $$You see in dim light within 60 ft as if it were bright light, and in darkness as if it were dim light, in shades of grey.$$),
  ('Dwarf', null, 2, 'Dwarven Resilience',
   $$Advantage on saving throws against poison, and resistance to poison damage.$$),
  ('Dwarf', null, 3, 'Dwarven Combat Training',
   $$Proficiency with the battleaxe, handaxe, light hammer and warhammer. Applied automatically.$$),
  ('Dwarf', null, 4, 'Tool Proficiency',
   $$Proficiency with one artisan's tool of your choice: smith's tools, brewer's supplies or mason's tools. Add it yourself.$$),
  ('Dwarf', null, 5, 'Stonecunning',
   $$On an Intelligence (History) check about the origin of stonework, you count as proficient and add double your proficiency bonus.$$),
  ('Dwarf', null, 6, 'Speed',
   $$Your speed is 25 ft, and wearing heavy armour never reduces it, whatever your Strength.$$),
  ('Dwarf', 'Hill Dwarf', 10, 'Dwarven Toughness',
   $$Your hit point maximum rises by 1, and by 1 again every time you gain a level. Included in the average-HP hint.$$),
  ('Dwarf', 'Mountain Dwarf', 10, 'Dwarven Armor Training',
   $$Proficiency with light and medium armour. Applied automatically.$$),

  -- Elf
  ('Elf', null, 1, 'Darkvision',
   $$You see in dim light within 60 ft as if it were bright light, and in darkness as if it were dim light, in shades of grey.$$),
  ('Elf', null, 2, 'Keen Senses',
   $$Proficiency in Perception. Applied automatically.$$),
  ('Elf', null, 3, 'Fey Ancestry',
   $$Advantage on saving throws against being charmed, and magic can't put you to sleep.$$),
  ('Elf', null, 4, 'Trance',
   $$Instead of sleeping, you meditate deeply, semiconscious, for 4 hours a day, and gain what a human would from 8 hours of sleep.$$),
  ('Elf', 'High Elf', 10, 'Elf Weapon Training',
   $$Proficiency with the longsword, shortsword, shortbow and longbow. Applied automatically.$$),
  ('Elf', 'High Elf', 11, 'Cantrip',
   $$You know one cantrip of your choice from the wizard spell list, cast with Intelligence. Add it to your spells yourself.$$),
  ('Elf', 'High Elf', 12, 'Extra Language',
   $$You speak, read and write one extra language of your choice.$$),
  ('Elf', 'Wood Elf', 10, 'Elf Weapon Training',
   $$Proficiency with the longsword, shortsword, shortbow and longbow. Applied automatically.$$),
  ('Elf', 'Wood Elf', 11, 'Fleet of Foot',
   $$Your base walking speed is 35 ft. Applied automatically.$$),
  ('Elf', 'Wood Elf', 12, 'Mask of the Wild',
   $$You can try to hide when only lightly obscured by foliage, heavy rain, falling snow, mist or other natural phenomena.$$),
  ('Elf', 'Drow', 10, 'Superior Darkvision',
   $$Your darkvision reaches 120 ft. Applied automatically.$$),
  ('Elf', 'Drow', 11, 'Sunlight Sensitivity',
   $$In direct sunlight, you have disadvantage on attack rolls, and on Wisdom (Perception) checks that rely on sight, when you, your target or what you're trying to see is in it.$$),
  ('Elf', 'Drow', 12, 'Drow Magic',
   $$You know the dancing lights cantrip. From 3rd level you can cast faerie fire once, and from 5th level darkness once, each regained on a long rest. Charisma is your spellcasting ability for these.$$),
  ('Elf', 'Drow', 13, 'Drow Weapon Training',
   $$Proficiency with the rapier, shortsword and hand crossbow. Applied automatically.$$),

  -- Gnome
  ('Gnome', null, 1, 'Darkvision',
   $$You see in dim light within 60 ft as if it were bright light, and in darkness as if it were dim light, in shades of grey.$$),
  ('Gnome', null, 2, 'Gnome Cunning',
   $$Advantage on Intelligence, Wisdom and Charisma saving throws against magic.$$),
  ('Gnome', 'Forest Gnome', 10, 'Natural Illusionist',
   $$You know the minor illusion cantrip, cast with Intelligence.$$),
  ('Gnome', 'Forest Gnome', 11, 'Speak with Small Beasts',
   $$Through sounds and gestures you can share simple ideas with Small or smaller beasts.$$),
  ('Gnome', 'Rock Gnome', 10, 'Artificer''s Lore',
   $$On an Intelligence (History) check about magic items, alchemical objects or technological devices, add twice your proficiency bonus instead of any proficiency bonus you would normally apply.$$),
  ('Gnome', 'Rock Gnome', 11, 'Tinker',
   $$Proficiency with tinker's tools (applied automatically). With 1 hour and 10 gp of materials you can build a Tiny clockwork device (AC 5, 1 hp): a toy, a fire starter or a music box. It works for 24 hours unless you spend an hour repairing it, and you can have up to three at once.$$),

  -- Half-Elf
  ('Half-Elf', null, 1, 'Darkvision',
   $$You see in dim light within 60 ft as if it were bright light, and in darkness as if it were dim light, in shades of grey.$$),
  ('Half-Elf', null, 2, 'Fey Ancestry',
   $$Advantage on saving throws against being charmed, and magic can't put you to sleep.$$),
  ('Half-Elf', null, 3, 'Skill Versatility',
   $$Proficiency in two skills of your choice. Mark them on the Skills list yourself.$$),
  ('Half-Elf', null, 4, 'Extra Language',
   $$You speak, read and write one extra language of your choice.$$),

  -- Half-Orc
  ('Half-Orc', null, 1, 'Darkvision',
   $$You see in dim light within 60 ft as if it were bright light, and in darkness as if it were dim light, in shades of grey.$$),
  ('Half-Orc', null, 2, 'Menacing',
   $$Proficiency in Intimidation. Applied automatically.$$),
  ('Half-Orc', null, 3, 'Relentless Endurance',
   $$When you drop to 0 hit points but aren't killed outright, you drop to 1 hit point instead. Once per long rest.$$),
  ('Half-Orc', null, 4, 'Savage Attacks',
   $$When you score a critical hit with a melee weapon, roll one of its damage dice one more time and add it to the extra damage.$$),

  -- Halfling
  ('Halfling', null, 1, 'Lucky',
   $$When you roll a 1 on the d20 for an attack roll, ability check or saving throw, you can reroll it and must use the new roll.$$),
  ('Halfling', null, 2, 'Brave',
   $$Advantage on saving throws against being frightened.$$),
  ('Halfling', null, 3, 'Halfling Nimbleness',
   $$You can move through the space of any creature at least one size larger than you.$$),
  ('Halfling', 'Lightfoot', 10, 'Naturally Stealthy',
   $$You can try to hide when only obscured by a creature at least one size larger than you.$$),
  ('Halfling', 'Stout', 10, 'Stout Resilience',
   $$Advantage on saving throws against poison, and resistance to poison damage.$$),

  -- Human
  ('Human', null, 1, 'Extra Language',
   $$You speak, read and write one extra language of your choice.$$),

  -- Tiefling
  ('Tiefling', null, 1, 'Darkvision',
   $$You see in dim light within 60 ft as if it were bright light, and in darkness as if it were dim light, in shades of grey.$$),
  ('Tiefling', null, 2, 'Hellish Resistance',
   $$Resistance to fire damage.$$),
  ('Tiefling', null, 3, 'Infernal Legacy',
   $$You know the thaumaturgy cantrip. From 3rd level you can cast hellish rebuke once as a 2nd-level spell, and from 5th level darkness once, each regained on a long rest. Charisma is your spellcasting ability for these.$$),

  -- Warforged
  ('Warforged', null, 1, 'Constructed Resilience',
   $$Advantage on saving throws against being poisoned, resistance to poison damage, and immunity to disease. You don't need to eat, drink or breathe, and magic can't put you to sleep.$$),
  ('Warforged', null, 2, 'Sentry''s Rest',
   $$On a long rest you spend at least 6 hours inactive and motionless, but not unconscious, instead of sleeping. You can see and hear as normal.$$),
  ('Warforged', null, 3, 'Integrated Protection',
   $$+1 to AC (applied automatically). Armour you wear must be incorporated into your body over 1 hour, and can't be removed against your will while you live.$$),
  ('Warforged', null, 4, 'Specialized Design',
   $$Proficiency in one skill and one tool of your choice. Add them yourself.$$),
  ('Warforged', null, 5, 'Extra Language',
   $$You speak, read and write one extra language of your choice.$$);

create temp table seed_resources (
  race text not null,
  subrace text,
  trait text not null,
  name text not null,
  recharge text not null,
  step_levels smallint[] not null,
  step_totals smallint[] not null,
  sort smallint not null
) on commit drop;

insert into seed_resources values
  ('Dragonborn', null,   'Breath Weapon',        'Breath Weapon',        'short', '{1}', '{1}', 0),
  ('Half-Orc',   null,   'Relentless Endurance', 'Relentless Endurance', 'long',  '{1}', '{1}', 0),
  ('Elf',        'Drow', 'Drow Magic',           'Faerie Fire',          'long',  '{3}', '{1}', 0),
  ('Elf',        'Drow', 'Drow Magic',           'Darkness',             'long',  '{5}', '{1}', 1),
  ('Tiefling',   null,   'Infernal Legacy',      'Hellish Rebuke',       'long',  '{3}', '{1}', 0),
  ('Tiefling',   null,   'Infernal Legacy',      'Darkness',             'long',  '{5}', '{1}', 1);

-- ---------- 2. every name resolves, before anything is written ----------

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

-- ---------- 3. grants on the races ----------

update public.races r
   set darkvision           = s.darkvision,
       skill_proficiencies  = s.skills,
       weapon_proficiencies = s.weapons,
       languages            = s.languages,
       resistances          = s.resistances
  from seed_races s
 where r.name = s.name and r.campaign_id is null;

-- ---------- 4. subraces ----------

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

-- ---------- 5. traits ----------

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

-- ---------- 6. counters ----------

insert into public.feature_resources
  (race_trait_id, name, recharge, formula, step_levels, step_totals, sort)
select tr.id, x.name, x.recharge, 'steps', x.step_levels, x.step_totals, x.sort
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

-- ---------- 7. assert the end state, not the work ----------

do $do$
declare
  v_count int;
  v_expected int;
begin
  select count(*) into v_count
    from seed_races s
    join public.races r on r.name = s.name and r.campaign_id is null
   where r.darkvision is not distinct from s.darkvision
     and r.skill_proficiencies = s.skills
     and r.weapon_proficiencies = s.weapons
     and r.languages = s.languages
     and r.resistances = s.resistances;
  if v_count <> (select count(*) from seed_races) then
    raise exception '% of % races carry their grants. Rolled back.',
      v_count, (select count(*) from seed_races);
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
  if (select count(*) from public.subraces where campaign_id is null) <> v_expected then
    raise exception 'Shared subraces other than these exist. Rolled back.';
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
  if v_count <> v_expected or v_expected <> 53 then
    raise exception '% of % traits as written (expected 53). Rolled back.', v_count, v_expected;
  end if;

  select count(*) into v_count
    from public.feature_resources where race_trait_id is not null;
  if v_count <> 6 then
    raise exception '% race-trait counters (expected 6). Rolled back.', v_count;
  end if;
end
$do$;

insert into public.schema_migrations (version) values ('165');

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
  (select count(*) = 9 from public.subraces where campaign_id is null)    as nine_subraces,
  (select count(*) = 53 from public.race_traits where campaign_id is null) as traits,
  (select speed = 35 from public.subraces
    where name = 'Wood Elf' and campaign_id is null)                       as wood_elf_35,
  (select darkvision = 120 from public.subraces
    where name = 'Drow' and campaign_id is null)                           as drow_120,
  (select effect::text = 'dwarven_toughness' from public.subraces
    where name = 'Hill Dwarf' and campaign_id is null)                     as hill_dwarf_key,
  (select skill_proficiencies = array['perception'] from public.races
    where name = 'Elf' and campaign_id is null)                            as elf_perception,
  (select count(*) = 2 from public.feature_resources f
     join public.race_traits t on t.id = f.race_trait_id
    where t.name = 'Infernal Legacy')                                      as tiefling_counters,
  (select count(*) = 1 from public.schema_migrations
    where version = '165')                                                 as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: every racial weapon names a shared, mundane weapon
-- ---------------------------------------------------------------------------
--
-- 162's check, for the race lists: a misspelt name would grant proficiency
-- with nothing and raise no error.
--
-- CORRECT OUTPUT: no rows.

begin;

select w.name
  from (select unnest(weapon_proficiencies) as name from public.races
         where campaign_id is null
        union
        select unnest(weapon_proficiencies) from public.subraces
         where campaign_id is null) w
 where not exists (
   select 1 from public.items i
    where i.name = w.name and i.kind = 'weapon'
      and i.campaign_id is null and i.rarity is null
 );

rollback;

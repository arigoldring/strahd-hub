-- db/115_class_features_xgte_sorcerer.sql
--
-- The Sorcerer's three Xanathar's origins: Divine Soul, Shadow Magic and Storm
-- Sorcery. 16 rows, all subclass features (the base class is 092's).
--
-- Picks the player notes by hand: Divine Magic's affinity, which also decides
-- Otherworldly Wings' look. Its bonus spell is not added to the spell list
-- automatically.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 076.
--
-- TEXT: every row is a short summary in our own words, mechanics intact, not
-- the book's wording. Tables are referenced, not reproduced.
--
-- NO PICKERS: no row here is linked to a feature option (095). The end-state
-- check counts class_feature_options links on these subclasses' features and
-- requires zero. Display only, like every feature row (KNOWN_ISSUES).
--
-- Run by Claude via `npx supabase db query --linked`; in the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class constant text := 'Sorcerer';
  c_divine_soul          constant text := 'Divine Soul';
  c_shadow_magic         constant text := 'Shadow Magic';
  c_storm_sorcery        constant text := 'Storm Sorcery';
  c_divine_soul_n        constant int  := 5;
  c_shadow_magic_n       constant int  := 5;
  c_storm_sorcery_n      constant int  := 6;

  v_seeking text;
  v_class   uuid;
  v_divine_soul          uuid;
  v_shadow_magic         uuid;
  v_storm_sorcery        uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_divine_soul;
  select id into strict v_divine_soul
  from public.subclasses
  where class_id = v_class and name = c_divine_soul and campaign_id is null;

  v_seeking := 'subclass ' || c_shadow_magic;
  select id into strict v_shadow_magic
  from public.subclasses
  where class_id = v_class and name = c_shadow_magic and campaign_id is null;

  v_seeking := 'subclass ' || c_storm_sorcery;
  select id into strict v_storm_sorcery
  from public.subclasses
  where class_id = v_class and name = c_storm_sorcery and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Divine Soul -------------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_divine_soul::uuid, 1, 'Divine Magic',
       'You can learn cleric spells as sorcerer spells. Pick an affinity '
       '(note it) and learn its spell, not counted against your spells '
       'known: good, cure wounds; evil, inflict wounds; law, bless; chaos, '
       'bane; neutrality, protection from evil and good.'),
      (v_divine_soul, 1, 'Favored by the Gods',
       'When you fail a saving throw or miss with an attack, add 2d4 to the '
       'roll, possibly changing the result. Once per short or long rest.'),
      (v_divine_soul, 6, 'Empowered Healing',
       'Once per turn, when you or an ally within 5 feet rolls healing dice '
       'for a spell, spend 1 sorcery point to reroll any of those dice once. '
       'Not while you are incapacitated.'),
      (v_divine_soul, 14, 'Otherworldly Wings',
       'Bonus action: spectral wings give you a 30-foot flying speed until '
       'you dismiss them as a bonus action. Eagle wings for good or law, bat '
       'wings for evil or chaos, dragonfly wings for neutrality.'),
      (v_divine_soul, 18, 'Unearthly Recovery',
       'Bonus action, while below half your hit point maximum: regain hit '
       'points equal to half your maximum. Once per long rest.'),
      -- ---- Shadow Magic ------------------------------------------------------
      (v_shadow_magic, 1, 'Eyes of the Dark',
       'Darkvision 120 feet. At 3rd level you learn darkness, not counted '
       'against your spells known. Cast it with 2 sorcery points instead of '
       'a slot and you can see through it.'),
      (v_shadow_magic, 1, 'Strength of the Grave',
       'When damage drops you to 0 hit points, make a Charisma save (DC 5 + '
       'the damage) to drop to 1 instead. Not against radiant damage or a '
       'critical hit. Once it succeeds, not again until a long rest.'),
      (v_shadow_magic, 6, 'Hound of Ill Omen',
       'Bonus action, 3 sorcery points: a shadow hound (dire wolf stats, '
       'Medium, with temporary hit points equal to half your sorcerer level) '
       'appears within 30 feet of a creature you can see within 120 feet, '
       'and hunts only it for 5 minutes. While the hound is within 5 feet of '
       'it, the target has disadvantage on saves against your spells.'),
      (v_shadow_magic, 14, 'Shadow Walk',
       'Bonus action, while in dim light or darkness: teleport up to 120 '
       'feet to a space you can see that is also in dim light or darkness.'),
      (v_shadow_magic, 18, 'Umbral Form',
       'Bonus action, 6 sorcery points, for 1 minute: resistance to all '
       'damage but force and radiant, and you can move through creatures and '
       'objects as difficult terrain, taking 5 force damage if you end a '
       'turn inside one. Ends early if you are incapacitated, or as a bonus '
       'action.'),
      -- ---- Storm Sorcery -----------------------------------------------------
      (v_storm_sorcery, 1, 'Wind Speaker',
       'You speak, read and write Primordial and its dialects.'),
      (v_storm_sorcery, 1, 'Tempestuous Magic',
       'Bonus action, right before or after you cast a spell of 1st level or '
       'higher: fly up to 10 feet without provoking opportunity attacks.'),
      (v_storm_sorcery, 6, 'Heart of the Storm',
       'Resistance to lightning and thunder damage. When you start casting a '
       'spell of 1st level or higher that deals lightning or thunder damage, '
       'creatures of your choice within 10 feet take lightning or thunder '
       'damage (your pick) equal to half your sorcerer level.'),
      (v_storm_sorcery, 6, 'Storm Guide',
       'If it''s raining, an action stops the rain in a 20-foot sphere around '
       'you until you end it as a bonus action. If it''s windy, a bonus '
       'action sets the wind''s direction in a 100-foot sphere around you '
       'until the end of your next turn.'),
      (v_storm_sorcery, 14, 'Storm''s Fury',
       'Reaction: when a melee attack hits you, the attacker takes lightning '
       'damage equal to your sorcerer level and makes a Strength save '
       'against your spell DC or is pushed up to 20 feet away.'),
      (v_storm_sorcery, 18, 'Wind Soul',
       'Immunity to lightning and thunder damage, and a 60-foot flying '
       'speed. Action: drop your flying speed to 30 feet for 1 hour to give '
       'up to 3 + your Charisma modifier creatures within 30 feet a 30-foot '
       'flying speed for that hour. Once per short or long rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_divine_soul and campaign_id is null;
  if v_count <> c_divine_soul_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_divine_soul, v_count, c_divine_soul_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_shadow_magic and campaign_id is null;
  if v_count <> c_shadow_magic_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_shadow_magic, v_count, c_shadow_magic_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_storm_sorcery and campaign_id is null;
  if v_count <> c_storm_sorcery_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_storm_sorcery, v_count, c_storm_sorcery_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_divine_soul, v_shadow_magic, v_storm_sorcery);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 076 the Sorcerer''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('115');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the rows and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

with f as (
  select s.name as subclass, f.*
    from public.class_features f
    join public.classes c on c.id = f.class_id
    join public.subclasses s on s.id = f.subclass_id
   where c.name = 'Sorcerer' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Divine Soul', 'Shadow Magic', 'Storm Sorcery')
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 6, 14, 18]::smallint[]
     from f where subclass = 'Divine Soul')                   as divine_soul_levels,
  (select array_agg(level order by level, name)
          = array[1, 1, 6, 14, 18]::smallint[]
     from f where subclass = 'Shadow Magic')                  as shadow_magic_levels,
  (select array_agg(level order by level, name)
          = array[1, 1, 6, 6, 14, 18]::smallint[]
     from f where subclass = 'Storm Sorcery')                 as storm_sorcery_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '115')                                            as ledger_row;

rollback;

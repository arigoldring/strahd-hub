-- db/112_class_features_tcoe_ranger.sql
--
-- The Ranger's two Tasha's archetypes: Fey Wanderer and Swarmkeeper. 11 rows,
-- all subclass features. Tasha's optional base-class features (Deft Explorer,
-- Favored Foe, Primal Awareness, Nature's Veil and the rest) are not seeded
-- here; Druidic Warrior is already a 095 fighting-style option.
--
-- Picks the player notes by hand: Otherworldly Glamour's skill.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 074.
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
  c_class constant text := 'Ranger';
  c_fey_wanderer         constant text := 'Fey Wanderer';
  c_swarmkeeper          constant text := 'Swarmkeeper';
  c_fey_wanderer_n       constant int  := 6;
  c_swarmkeeper_n        constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_fey_wanderer         uuid;
  v_swarmkeeper          uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_fey_wanderer;
  select id into strict v_fey_wanderer
  from public.subclasses
  where class_id = v_class and name = c_fey_wanderer and campaign_id is null;

  v_seeking := 'subclass ' || c_swarmkeeper;
  select id into strict v_swarmkeeper
  from public.subclasses
  where class_id = v_class and name = c_swarmkeeper and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Fey Wanderer ------------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_fey_wanderer::uuid, 3, 'Fey Wanderer Magic',
       'Always known, not counted against your ranger spells known; the '
       'levels are ranger levels. 3rd: charm person. 5th: misty step. 9th: '
       'dispel magic. 13th: dimension door. 17th: mislead. You also carry a '
       'harmless fey blessing (Tasha''s table).'),
      (v_fey_wanderer, 3, 'Dreadful Strikes',
       'Once on each of your turns, when you hit with a weapon, deal an '
       'extra 1d4 psychic damage (1d6 at 11th level). A creature takes this '
       'only once per turn.'),
      (v_fey_wanderer, 3, 'Otherworldly Glamour',
       'Add your Wisdom modifier (minimum +1) to Charisma checks, and gain '
       'proficiency in Deception, Performance or Persuasion (note your '
       'pick).'),
      (v_fey_wanderer, 7, 'Beguiling Twist',
       'Advantage on saves against being charmed or frightened. Reaction: '
       'when you or a creature you can see within 120 feet succeeds on such '
       'a save, a different creature you can see within 120 feet makes a '
       'Wisdom save against your spell DC or is charmed or frightened by you '
       '(your choice) for 1 minute, repeating the save each turn.'),
      (v_fey_wanderer, 11, 'Fey Reinforcements',
       'You can cast summon fey without a material component, once per long '
       'rest without a slot. When you cast it, you can drop concentration '
       'and make it last 1 minute instead.'),
      (v_fey_wanderer, 15, 'Misty Wanderer',
       'Cast misty step without a slot a number of times equal to your '
       'proficiency bonus per long rest, and bring a willing creature within '
       '5 feet along each time.'),
      -- ---- Swarmkeeper -------------------------------------------------------
      (v_swarmkeeper, 3, 'Swarmkeeper Magic',
       'Always known, not counted against your ranger spells known; the '
       'levels are ranger levels. 3rd: faerie fire, mage hand (cantrip). '
       '5th: web. 9th: gaseous form. 13th: arcane eye. 17th: insect plague.'),
      (v_swarmkeeper, 3, 'Gathered Swarm',
       'Once on each of your turns, after you hit a creature with an attack, '
       'your swarm either deals it 1d6 piercing, pushes it up to 15 feet '
       'horizontally on a failed Strength save against your spell DC, or '
       'carries you 5 feet horizontally.'),
      (v_swarmkeeper, 7, 'Writhing Tide',
       'Bonus action: a 10-foot flying speed and hover for 1 minute. Uses '
       'equal to your proficiency bonus per long rest.'),
      (v_swarmkeeper, 11, 'Mighty Swarm',
       'Gathered Swarm deals 1d8. A creature that fails the save against '
       'being pushed can also be knocked prone, and being carried gives you '
       'half cover until the start of your next turn.'),
      (v_swarmkeeper, 15, 'Swarming Dispersal',
       'Reaction: when you take damage, gain resistance to it and teleport '
       'up to 30 feet to a space you can see. Uses equal to your proficiency '
       'bonus per long rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_fey_wanderer and campaign_id is null;
  if v_count <> c_fey_wanderer_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_fey_wanderer, v_count, c_fey_wanderer_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_swarmkeeper and campaign_id is null;
  if v_count <> c_swarmkeeper_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_swarmkeeper, v_count, c_swarmkeeper_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_fey_wanderer, v_swarmkeeper);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 074 the Ranger''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('112');

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
   where c.name = 'Ranger' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Fey Wanderer', 'Swarmkeeper')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 7, 11, 15]::smallint[]
     from f where subclass = 'Fey Wanderer')                  as fey_wanderer_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 7, 11, 15]::smallint[]
     from f where subclass = 'Swarmkeeper')                   as swarmkeeper_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '112')                                            as ledger_row;

rollback;

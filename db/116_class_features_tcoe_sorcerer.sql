-- db/116_class_features_tcoe_sorcerer.sql
--
-- The Sorcerer's two Tasha's origins: Aberrant Mind and Clockwork Soul. 11
-- rows, all subclass features. Tasha's optional base-class features (Magical
-- Guidance, Sorcerous Versatility, the extra Metamagic options) are not seeded
-- here.
--
-- Revelation in Flesh's benefits are chosen each use, not stored.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
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
  c_aberrant_mind        constant text := 'Aberrant Mind';
  c_clockwork_soul       constant text := 'Clockwork Soul';
  c_aberrant_mind_n      constant int  := 6;
  c_clockwork_soul_n     constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_aberrant_mind        uuid;
  v_clockwork_soul       uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_aberrant_mind;
  select id into strict v_aberrant_mind
  from public.subclasses
  where class_id = v_class and name = c_aberrant_mind and campaign_id is null;

  v_seeking := 'subclass ' || c_clockwork_soul;
  select id into strict v_clockwork_soul
  from public.subclasses
  where class_id = v_class and name = c_clockwork_soul and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Aberrant Mind -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_aberrant_mind::uuid, 1, 'Psionic Spells',
       'Known, not counted against your spells known; the levels are '
       'sorcerer levels. 1st: arms of Hadar, dissonant whispers, mind sliver '
       '(cantrip). 3rd: calm emotions, detect thoughts. 5th: hunger of '
       'Hadar, sending. 7th: Evard''s black tentacles, summon aberration. '
       '9th: Rary''s telepathic bond, telekinesis. On a level up, you can '
       'swap one for a divination or enchantment spell of the same level '
       'from the sorcerer, warlock or wizard list.'),
      (v_aberrant_mind, 1, 'Telepathic Speech',
       'Bonus action: you and one creature you can see within 30 feet can '
       'talk telepathically for minutes equal to your sorcerer level, within '
       'miles equal to your Charisma modifier (minimum 1), in a language the '
       'listener knows.'),
      (v_aberrant_mind, 6, 'Psionic Sorcery',
       'You can cast a Psionic Spell of 1st level or higher by spending '
       'sorcery points equal to its level instead of a slot. Cast that way, '
       'it needs no verbal or somatic components, and no material ones '
       'unless they are consumed or have a cost.'),
      (v_aberrant_mind, 6, 'Psychic Defenses',
       'Resistance to psychic damage, and advantage on saves against being '
       'charmed or frightened.'),
      (v_aberrant_mind, 14, 'Revelation in Flesh',
       concat_ws(E'\n',
       'Bonus action, for 10 minutes: spend sorcery points, one benefit per '
       'point:',
       '- See invisible creatures within 60 feet that aren''t behind total '
       'cover.',
       '- A flying speed equal to your walking speed, and hover.',
       '- A swimming speed of twice your walking speed, and water breathing.',
       '- Squeeze through a 1-inch gap, and spend 5 feet of movement to '
       'escape nonmagical restraints or a grapple.')),
      (v_aberrant_mind, 18, 'Warping Implosion',
       'Action: teleport to a space you can see within 120 feet. Each '
       'creature within 30 feet of where you left makes a Strength save '
       'against your spell DC: 3d10 force and pulled toward that spot on a '
       'failure, half and not pulled on a success. Once per long rest, or '
       'again for 5 sorcery points.'),
      -- ---- Clockwork Soul ----------------------------------------------------
      (v_clockwork_soul, 1, 'Clockwork Magic',
       'Known, not counted against your spells known; the levels are '
       'sorcerer levels. 1st: alarm, protection from evil and good. 3rd: '
       'aid, lesser restoration. 5th: dispel magic, protection from energy. '
       '7th: freedom of movement, summon construct. 9th: greater '
       'restoration, wall of force. On a level up, you can swap one for an '
       'abjuration or transmutation spell of the same level from the '
       'sorcerer, warlock or wizard list. Your magic shows a harmless sign '
       'of order (Tasha''s table).'),
      (v_clockwork_soul, 1, 'Restore Balance',
       'Reaction: when a creature you can see within 60 feet is about to '
       'roll a d20 with advantage or disadvantage, cancel it. Uses equal to '
       'your proficiency bonus per long rest.'),
      (v_clockwork_soul, 6, 'Bastion of Law',
       'Action: spend 1 to 5 sorcery points to ward yourself or a creature '
       'within 30 feet with that many d8s. When the warded creature takes '
       'damage, it can spend any of the dice to reduce the damage by their '
       'roll. The ward lasts until a long rest or until you use this again.'),
      (v_clockwork_soul, 14, 'Trance of Order',
       'Bonus action, for 1 minute: attacks against you can''t have '
       'advantage, and on your attack rolls, checks and saves you treat a '
       'd20 roll of 9 or lower as 10. Once per long rest, or again for 5 '
       'sorcery points.'),
      (v_clockwork_soul, 18, 'Clockwork Cavalcade',
       'Action: in a 30-foot cube from you, restore up to 100 hit points '
       'split among creatures of your choice, fully repair damaged objects '
       'entirely inside, and end every spell of 6th level or lower on '
       'creatures and objects of your choice. Once per long rest, or again '
       'for 7 sorcery points.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_aberrant_mind and campaign_id is null;
  if v_count <> c_aberrant_mind_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_aberrant_mind, v_count, c_aberrant_mind_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_clockwork_soul and campaign_id is null;
  if v_count <> c_clockwork_soul_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_clockwork_soul, v_count, c_clockwork_soul_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_aberrant_mind, v_clockwork_soul);
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

insert into public.schema_migrations (version) values ('116');

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
     and s.name in ('Aberrant Mind', 'Clockwork Soul')
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 6, 6, 14, 18]::smallint[]
     from f where subclass = 'Aberrant Mind')                 as aberrant_mind_levels,
  (select array_agg(level order by level, name)
          = array[1, 1, 6, 14, 18]::smallint[]
     from f where subclass = 'Clockwork Soul')                as clockwork_soul_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '116')                                            as ledger_row;

rollback;

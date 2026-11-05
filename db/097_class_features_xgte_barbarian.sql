-- db/097_class_features_xgte_barbarian.sql
--
-- The Barbarian's three Xanathar's Primal Paths: Ancestral Guardian, Storm
-- Herald and Zealot. 13 rows, all subclass features (the base class is 084's).
--
-- Picks the player notes by hand: Storm Aura's environment (one pick, changeable
-- on a level up) and Divine Fury's damage type (fixed once chosen). Each is a
-- single pick a feature-option picker could carry later, but this file adds no
-- option kinds.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 067.
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
  c_class constant text := 'Barbarian';
  c_ancestral_guardian   constant text := 'Path of the Ancestral Guardian';
  c_storm_herald         constant text := 'Path of the Storm Herald';
  c_zealot               constant text := 'Path of the Zealot';
  c_ancestral_guardian_n constant int  := 4;
  c_storm_herald_n       constant int  := 4;
  c_zealot_n             constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_ancestral_guardian   uuid;
  v_storm_herald         uuid;
  v_zealot               uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_ancestral_guardian;
  select id into strict v_ancestral_guardian
  from public.subclasses
  where class_id = v_class and name = c_ancestral_guardian and campaign_id is null;

  v_seeking := 'subclass ' || c_storm_herald;
  select id into strict v_storm_herald
  from public.subclasses
  where class_id = v_class and name = c_storm_herald and campaign_id is null;

  v_seeking := 'subclass ' || c_zealot;
  select id into strict v_zealot
  from public.subclasses
  where class_id = v_class and name = c_zealot and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Path of the Ancestral Guardian ------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_ancestral_guardian::uuid, 3, 'Ancestral Protectors',
       'While raging, the first creature you hit on your turn is marked '
       'until the start of your next turn or the rage ends: it has '
       'disadvantage on attacks against anyone but you, and anyone but you '
       'that it hits has resistance to that damage.'),
      (v_ancestral_guardian, 6, 'Spirit Shield',
       'While raging, when a creature you can see within 30 feet takes '
       'damage, you can use your reaction to reduce that damage by 2d6; 3d6 '
       'at 10th level, 4d6 at 14th.'),
      (v_ancestral_guardian, 10, 'Consult the Spirits',
       'Cast augury or clairvoyance without a spell slot or material '
       'components, using Wisdom. Clairvoyance places an invisible ancestral '
       'spirit at the spot. Once per short or long rest.'),
      (v_ancestral_guardian, 14, 'Vengeful Ancestors',
       'When Spirit Shield reduces damage, the attacker takes force damage '
       'equal to the amount prevented.'),
      -- ---- Path of the Storm Herald ------------------------------------------
      (v_storm_herald, 3, 'Storm Aura',
       concat_ws(E'\n',
       'While raging you have a 10-foot aura. It activates when you rage, '
       'and again as a bonus action on later turns. Save DC 8 + proficiency '
       'bonus + Constitution modifier. Pick an environment at 3rd level '
       '(note it); you can change it when you gain a barbarian level.',
       '- Desert: each other creature in the aura takes 2 fire damage; 3 at '
       '5th, 4 at 10th, 5 at 15th, 6 at 20th.',
       '- Sea: one other creature in the aura makes a Dexterity save or '
       'takes 1d6 lightning, half on a success; 2d6 at 10th, 3d6 at 15th, '
       '4d6 at 20th.',
       '- Tundra: creatures of your choice in the aura gain 2 temporary hit '
       'points; 3 at 5th, 4 at 10th, 5 at 15th, 6 at 20th.')),
      (v_storm_herald, 6, 'Storm Soul',
       concat_ws(E'\n',
       'A benefit from your chosen environment, active even when not raging:',
       '- Desert: resistance to fire, unbothered by extreme heat, and you '
       'can set an unattended flammable object alight by touch (action).',
       '- Sea: resistance to lightning, you breathe underwater, and you have '
       'a 30-foot swimming speed.',
       '- Tundra: resistance to cold, unbothered by extreme cold, and you '
       'can freeze a 5-foot cube of water by touch for 1 minute (action).')),
      (v_storm_herald, 10, 'Shielding Storm',
       'Creatures of your choice in your Storm Aura have the damage '
       'resistance your Storm Soul gives you.'),
      (v_storm_herald, 14, 'Raging Storm',
       concat_ws(E'\n',
       'A stronger effect from your environment while raging, using the '
       'Storm Aura save DC:',
       '- Desert: right after a creature in the aura hits you, use your '
       'reaction: it makes a Dexterity save or takes fire damage equal to '
       'half your barbarian level.',
       '- Sea: when you hit a creature in the aura, use your reaction: it '
       'makes a Strength save or is knocked prone.',
       '- Tundra: each time the aura activates, one creature you can see in '
       'it makes a Strength save or its speed is 0 until the start of your '
       'next turn.')),
      -- ---- Path of the Zealot ------------------------------------------------
      (v_zealot, 3, 'Divine Fury',
       'While raging, the first creature you hit with a weapon on each of '
       'your turns takes an extra 1d6 + half your barbarian level of '
       'necrotic or radiant damage. Pick the type when you gain the feature '
       '(note it).'),
      (v_zealot, 3, 'Warrior of the Gods',
       'A spell whose only effect is to bring you back to life, such as '
       'raise dead, needs no material components when cast on you.'),
      (v_zealot, 6, 'Fanatical Focus',
       'Once per rage, when you fail a saving throw while raging, you can '
       'reroll it and must use the new roll.'),
      (v_zealot, 10, 'Zealous Presence',
       'Bonus action: up to ten creatures of your choice within 60 feet that '
       'can hear you have advantage on attack rolls and saving throws until '
       'the start of your next turn. Once per long rest.'),
      (v_zealot, 14, 'Rage Beyond Death',
       'While raging, 0 hit points doesn''t knock you unconscious. You still '
       'make death saves and take damage normally, but you don''t die from '
       'failed death saves until the rage ends, and then only if you are '
       'still at 0 hit points.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_ancestral_guardian and campaign_id is null;
  if v_count <> c_ancestral_guardian_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_ancestral_guardian, v_count, c_ancestral_guardian_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_storm_herald and campaign_id is null;
  if v_count <> c_storm_herald_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_storm_herald, v_count, c_storm_herald_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_zealot and campaign_id is null;
  if v_count <> c_zealot_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_zealot, v_count, c_zealot_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_ancestral_guardian, v_storm_herald, v_zealot);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 067 the Barbarian''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('097');

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
   where c.name = 'Barbarian' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Path of the Ancestral Guardian', 'Path of the Storm Herald', 'Path of the Zealot')
)
select
  (select array_agg(level order by level, name)
          = array[3, 6, 10, 14]::smallint[]
     from f where subclass = 'Path of the Ancestral Guardian') as ancestral_guardian_levels,
  (select array_agg(level order by level, name)
          = array[3, 6, 10, 14]::smallint[]
     from f where subclass = 'Path of the Storm Herald')      as storm_herald_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 6, 10, 14]::smallint[]
     from f where subclass = 'Path of the Zealot')            as zealot_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '097')                                            as ledger_row;

rollback;

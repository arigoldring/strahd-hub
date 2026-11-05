-- db/102_class_features_tcoe_cleric.sql
--
-- The Cleric's three Tasha's domains: Order, Peace and Twilight. 22 rows, all
-- subclass features, in 086's row naming. Tasha's optional base-class features
-- (Harness Divine Power, Blessed Strikes, Cantrip Versatility) are not seeded
-- here.
--
-- Picks the player notes by hand: Order's skill (Intimidation or Persuasion)
-- and Peace's (Insight, Performance or Persuasion). Each is a single pick that
-- a skill picker could carry later.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 069.
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
  c_class constant text := 'Cleric';
  c_order                constant text := 'Order Domain';
  c_peace                constant text := 'Peace Domain';
  c_twilight             constant text := 'Twilight Domain';
  c_order_n              constant int  := 7;
  c_peace_n              constant int  := 7;
  c_twilight_n           constant int  := 8;

  v_seeking text;
  v_class   uuid;
  v_order                uuid;
  v_peace                uuid;
  v_twilight             uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_order;
  select id into strict v_order
  from public.subclasses
  where class_id = v_class and name = c_order and campaign_id is null;

  v_seeking := 'subclass ' || c_peace;
  select id into strict v_peace
  from public.subclasses
  where class_id = v_class and name = c_peace and campaign_id is null;

  v_seeking := 'subclass ' || c_twilight;
  select id into strict v_twilight
  from public.subclasses
  where class_id = v_class and name = c_twilight and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Order Domain ------------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_order::uuid, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: command, '
       'heroism. 3rd: hold person, zone of truth. 5th: mass healing word, '
       'slow. 7th: compulsion, locate creature. 9th: commune, dominate '
       'person.'),
      (v_order, 1, 'Bonus Proficiencies',
       'Proficiency with heavy armor, and with Intimidation or Persuasion '
       '(note your pick).'),
      (v_order, 1, 'Voice of Authority',
       'When you cast a spell of 1st level or higher with a spell slot that '
       'targets an ally, one targeted ally can use its reaction right after '
       'to make one weapon attack against a creature you choose and can see.'),
      (v_order, 2, 'Channel Divinity: Order''s Demand',
       'Action: creatures of your choice within 30 feet that can see or hear '
       'you make a Wisdom save or are charmed by you until the end of your '
       'next turn or until they take damage. You can make any of them drop '
       'one item they hold.'),
      (v_order, 6, 'Embodiment of the Law',
       'When you cast an enchantment spell of 1st level or higher that '
       'normally takes an action, you can cast it as a bonus action instead. '
       'Uses equal to your Wisdom modifier (minimum 1) per long rest.'),
      (v_order, 8, 'Divine Strike',
       'Once on each of your turns, when you hit with a weapon attack, deal '
       'an extra 1d8 psychic damage; 2d8 at 14th level.'),
      (v_order, 17, 'Order''s Wrath',
       'Once per turn, when your Divine Strike damages a creature, you can '
       'curse it until the start of your next turn. The next ally hit on it '
       'deals an extra 2d8 psychic damage, ending the curse.'),
      -- ---- Peace Domain ------------------------------------------------------
      (v_peace, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: heroism, '
       'sanctuary. 3rd: aid, warding bond. 5th: beacon of hope, sending. '
       '7th: aura of purity, Otiluke''s resilient sphere. 9th: greater '
       'restoration, Rary''s telepathic bond.'),
      (v_peace, 1, 'Implement of Peace',
       'Proficiency in Insight, Performance or Persuasion (note your pick).'),
      (v_peace, 1, 'Emboldening Bond',
       'Action: bond up to your proficiency bonus willing creatures within '
       '30 feet, yourself included, for 10 minutes or until you use this '
       'again. Once per turn, a bonded creature within 30 feet of another '
       'can add a d4 to an attack roll, ability check or saving throw. Uses '
       'equal to your proficiency bonus per long rest.'),
      (v_peace, 2, 'Channel Divinity: Balm of Peace',
       'Action: move up to your speed without provoking opportunity attacks. '
       'Each creature you pass within 5 feet of can regain 2d6 + your Wisdom '
       'modifier (minimum 1) hit points, once per use.'),
      (v_peace, 6, 'Protective Bond',
       'When a bonded creature is about to take damage, another bonded '
       'creature within 30 feet can use its reaction to teleport next to it '
       'and take all of that damage instead.'),
      (v_peace, 8, 'Potent Spellcasting',
       'Add your Wisdom modifier to the damage of your cleric cantrips.'),
      (v_peace, 17, 'Expansive Bond',
       'Emboldening Bond and Protective Bond reach 60 feet, and a creature '
       'taking damage through Protective Bond has resistance to it.'),
      -- ---- Twilight Domain ---------------------------------------------------
      (v_twilight, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: faerie fire, '
       'sleep. 3rd: moonbeam, see invisibility. 5th: aura of vitality, '
       'Leomund''s tiny hut. 7th: aura of life, greater invisibility. 9th: '
       'circle of power, mislead.'),
      (v_twilight, 1, 'Bonus Proficiencies',
       'Proficiency with martial weapons and heavy armor.'),
      (v_twilight, 1, 'Eyes of Night',
       'Darkvision out to 300 feet. Action: share it for 1 hour with up to '
       'your Wisdom modifier (minimum 1) willing creatures you can see '
       'within 10 feet. Sharing is once per long rest, or again by spending '
       'a spell slot.'),
      (v_twilight, 1, 'Vigilant Blessing',
       'Action: one creature you touch, you included, has advantage on its '
       'next initiative roll. It ends after that roll or when you use this '
       'again.'),
      (v_twilight, 2, 'Channel Divinity: Twilight Sanctuary',
       'Action: a 30-foot sphere of twilight surrounds you for 1 minute, or '
       'until you are incapacitated or die. When a creature, you included, '
       'ends its turn in it, you can give it 1d6 + your cleric level '
       'temporary hit points, or end one effect charming or frightening it.'),
      (v_twilight, 6, 'Steps of Night',
       'Bonus action, while in dim light or darkness: a flying speed equal '
       'to your walking speed for 1 minute. Uses equal to your proficiency '
       'bonus per long rest.'),
      (v_twilight, 8, 'Divine Strike',
       'Once on each of your turns, when you hit with a weapon attack, deal '
       'an extra 1d8 radiant damage; 2d8 at 14th level.'),
      (v_twilight, 17, 'Twilight Shroud',
       'You and your allies have half cover while inside your Twilight '
       'Sanctuary.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_order and campaign_id is null;
  if v_count <> c_order_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_order, v_count, c_order_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_peace and campaign_id is null;
  if v_count <> c_peace_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_peace, v_count, c_peace_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_twilight and campaign_id is null;
  if v_count <> c_twilight_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_twilight, v_count, c_twilight_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_order, v_peace, v_twilight);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 069 the Cleric''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('102');

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
   where c.name = 'Cleric' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Order Domain', 'Peace Domain', 'Twilight Domain')
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 1, 2, 6, 8, 17]::smallint[]
     from f where subclass = 'Order Domain')                  as order_levels,
  (select array_agg(level order by level, name)
          = array[1, 1, 1, 2, 6, 8, 17]::smallint[]
     from f where subclass = 'Peace Domain')                  as peace_levels,
  (select array_agg(level order by level, name)
          = array[1, 1, 1, 1, 2, 6, 8, 17]::smallint[]
     from f where subclass = 'Twilight Domain')               as twilight_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '102')                                            as ledger_row;

rollback;

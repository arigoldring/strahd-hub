-- db/101_class_features_xgte_cleric.sql
--
-- The Cleric's two Xanathar's domains: Forge and Grave. 14 rows, all subclass
-- features (the base class is 086's). 086's row naming throughout: Domain
-- Spells at 1st, "Channel Divinity: <option>" beside the base row that counts
-- uses, and Divine Strike or Potent Spellcasting at 8th.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
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
  c_forge                constant text := 'Forge Domain';
  c_grave                constant text := 'Grave Domain';
  c_forge_n              constant int  := 7;
  c_grave_n              constant int  := 7;

  v_seeking text;
  v_class   uuid;
  v_forge                uuid;
  v_grave                uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_forge;
  select id into strict v_forge
  from public.subclasses
  where class_id = v_class and name = c_forge and campaign_id is null;

  v_seeking := 'subclass ' || c_grave;
  select id into strict v_grave
  from public.subclasses
  where class_id = v_class and name = c_grave and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Forge Domain ------------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_forge::uuid, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: identify, '
       'searing smite. 3rd: heat metal, magic weapon. 5th: elemental weapon, '
       'protection from energy. 7th: fabricate, wall of fire. 9th: animate '
       'objects, creation.'),
      (v_forge, 1, 'Bonus Proficiencies',
       'Proficiency with heavy armor and smith''s tools.'),
      (v_forge, 1, 'Blessing of the Forge',
       'At the end of a long rest, touch one nonmagical weapon, suit of '
       'armor or shield. Until your next long rest it is magical, with +1 to '
       'AC (armor or shield) or +1 to attack and damage rolls (weapon). Once '
       'per long rest.'),
      (v_forge, 2, 'Channel Divinity: Artisan''s Blessing',
       'A one-hour ritual crafts a nonmagical item containing metal, worth '
       'up to 100 gp: a weapon, a suit of armor, ten pieces of ammunition, a '
       'set of tools or another metal object. You must lay out metal, coins '
       'included, worth as much as the item.'),
      (v_forge, 6, 'Soul of the Forge',
       'Resistance to fire damage, and +1 AC while you wear heavy armor.'),
      (v_forge, 8, 'Divine Strike',
       'Once on each of your turns, when you hit with a weapon attack, deal '
       'an extra 1d8 fire damage; 2d8 at 14th level.'),
      (v_forge, 17, 'Saint of Forge and Fire',
       'Immunity to fire damage. While you wear heavy armor, resistance to '
       'bludgeoning, piercing and slashing damage from nonmagical attacks.'),
      -- ---- Grave Domain ------------------------------------------------------
      (v_grave, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: bane, false '
       'life. 3rd: gentle repose, ray of enfeeblement. 5th: revivify, '
       'vampiric touch. 7th: blight, death ward. 9th: antilife shell, raise '
       'dead.'),
      (v_grave, 1, 'Circle of Mortality',
       'Healing dice from your spells use their maximum on a creature at 0 '
       'hit points. You learn spare the dying (not counted against your '
       'cantrips) and can cast it as a bonus action at a range of 30 feet.'),
      (v_grave, 1, 'Eyes of the Grave',
       'Action: until the end of your next turn, you know where any undead '
       'within 60 feet are, unless behind total cover or warded from '
       'divination. Uses equal to your Wisdom modifier (minimum 1) per long '
       'rest.'),
      (v_grave, 2, 'Channel Divinity: Path to the Grave',
       'Action: curse one creature you can see within 30 feet until the end '
       'of your next turn. The next attack by you or an ally that hits it '
       'deals damage it is vulnerable to, then the curse ends.'),
      (v_grave, 6, 'Sentinel at Death''s Door',
       'Reaction: turn a critical hit against you or a creature you can see '
       'within 30 feet into a normal hit. Uses equal to your Wisdom modifier '
       '(minimum 1) per long rest.'),
      (v_grave, 8, 'Potent Spellcasting',
       'Add your Wisdom modifier to the damage of your cleric cantrips.'),
      (v_grave, 17, 'Keeper of Souls',
       'Once per turn, when an enemy you can see dies within 60 feet, you or '
       'one creature of your choice within 60 feet regains hit points equal '
       'to the enemy''s number of Hit Dice. Not while you are incapacitated.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_forge and campaign_id is null;
  if v_count <> c_forge_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_forge, v_count, c_forge_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_grave and campaign_id is null;
  if v_count <> c_grave_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_grave, v_count, c_grave_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_forge, v_grave);
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

insert into public.schema_migrations (version) values ('101');

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
     and s.name in ('Forge Domain', 'Grave Domain')
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 1, 2, 6, 8, 17]::smallint[]
     from f where subclass = 'Forge Domain')                  as forge_levels,
  (select array_agg(level order by level, name)
          = array[1, 1, 1, 2, 6, 8, 17]::smallint[]
     from f where subclass = 'Grave Domain')                  as grave_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '101')                                            as ledger_row;

rollback;

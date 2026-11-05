-- db/111_class_features_xgte_ranger.sql
--
-- The Ranger's three Xanathar's archetypes: Gloom Stalker, Horizon Walker and
-- Monster Slayer. 18 rows, all subclass features (the base class is 090's).
-- Each has its own spell row at 3rd, the way 089 gives oaths theirs.
--
-- Picks the player notes by hand: Iron Mind's save if Wisdom is already
-- proficient.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
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
  c_gloom_stalker        constant text := 'Gloom Stalker';
  c_horizon_walker       constant text := 'Horizon Walker';
  c_monster_slayer       constant text := 'Monster Slayer';
  c_gloom_stalker_n      constant int  := 6;
  c_horizon_walker_n     constant int  := 6;
  c_monster_slayer_n     constant int  := 6;

  v_seeking text;
  v_class   uuid;
  v_gloom_stalker        uuid;
  v_horizon_walker       uuid;
  v_monster_slayer       uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_gloom_stalker;
  select id into strict v_gloom_stalker
  from public.subclasses
  where class_id = v_class and name = c_gloom_stalker and campaign_id is null;

  v_seeking := 'subclass ' || c_horizon_walker;
  select id into strict v_horizon_walker
  from public.subclasses
  where class_id = v_class and name = c_horizon_walker and campaign_id is null;

  v_seeking := 'subclass ' || c_monster_slayer;
  select id into strict v_monster_slayer
  from public.subclasses
  where class_id = v_class and name = c_monster_slayer and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Gloom Stalker -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_gloom_stalker::uuid, 3, 'Gloom Stalker Magic',
       'Always known, not counted against your ranger spells known; the '
       'levels are ranger levels. 3rd: disguise self. 5th: rope trick. 9th: '
       'fear. 13th: greater invisibility. 17th: seeming.'),
      (v_gloom_stalker, 3, 'Dread Ambusher',
       'Add your Wisdom modifier to initiative. On your first turn of each '
       'combat, your walking speed rises by 10 feet, and if you take the '
       'Attack action you make one extra weapon attack, which deals an extra '
       '1d8 damage of the weapon''s type on a hit.'),
      (v_gloom_stalker, 3, 'Umbral Sight',
       'Darkvision 60 feet, or 30 feet more if you already have it. In '
       'darkness, you are invisible to creatures relying on darkvision to '
       'see you.'),
      (v_gloom_stalker, 7, 'Iron Mind',
       'Proficiency in Wisdom saves, or in Intelligence or Charisma saves if '
       'you already have it (note your pick).'),
      (v_gloom_stalker, 11, 'Stalker''s Flurry',
       'Once on each of your turns, when you miss with a weapon attack, you '
       'can make another weapon attack as part of the same action.'),
      (v_gloom_stalker, 15, 'Shadowy Dodge',
       'Reaction: when a creature attacks you without advantage, impose '
       'disadvantage on the roll, before you know whether it hits.'),
      -- ---- Horizon Walker ----------------------------------------------------
      (v_horizon_walker, 3, 'Horizon Walker Magic',
       'Always known, not counted against your ranger spells known; the '
       'levels are ranger levels. 3rd: protection from evil and good. 5th: '
       'misty step. 9th: haste. 13th: banishment. 17th: teleportation '
       'circle.'),
      (v_horizon_walker, 3, 'Detect Portal',
       'Action: sense the distance and direction to the nearest planar '
       'portal within 1 mile. Once per short or long rest.'),
      (v_horizon_walker, 3, 'Planar Warrior',
       'Bonus action: pick a creature you can see within 30 feet. The next '
       'time you hit it this turn with a weapon, all the damage becomes '
       'force, plus an extra 1d8 force (2d8 at 11th level).'),
      (v_horizon_walker, 7, 'Ethereal Step',
       'Bonus action: cast etherealness without a spell slot, ending at the '
       'end of the turn. Once per short or long rest.'),
      (v_horizon_walker, 11, 'Distant Strike',
       'When you take the Attack action, teleport up to 10 feet before each '
       'attack to a space you can see. If you attack at least two different '
       'creatures with the action, make one extra attack against a third.'),
      (v_horizon_walker, 15, 'Spectral Defense',
       'Reaction: when an attack damages you, gain resistance to all of that '
       'attack''s damage this turn.'),
      -- ---- Monster Slayer ----------------------------------------------------
      (v_monster_slayer, 3, 'Monster Slayer Magic',
       'Always known, not counted against your ranger spells known; the '
       'levels are ranger levels. 3rd: protection from evil and good. 5th: '
       'zone of truth. 9th: magic circle. 13th: banishment. 17th: hold '
       'monster.'),
      (v_monster_slayer, 3, 'Hunter''s Sense',
       'Action: learn a creature''s damage immunities, resistances and '
       'vulnerabilities, if it''s one you can see within 60 feet and isn''t '
       'warded from divination. Uses equal to your Wisdom modifier (minimum '
       '1) per long rest.'),
      (v_monster_slayer, 3, 'Slayer''s Prey',
       'Bonus action: mark a creature you can see within 60 feet. The first '
       'time each turn you hit it with a weapon, deal an extra 1d6 damage. '
       'It lasts until a short or long rest, or until you mark another.'),
      (v_monster_slayer, 7, 'Supernatural Defense',
       'Add a d6 to saving throws your marked prey forces you to make, and '
       'to checks to escape its grapple.'),
      (v_monster_slayer, 11, 'Magic-User''s Nemesis',
       'Reaction: when you see a creature within 60 feet cast a spell or '
       'teleport, it makes a Wisdom save against your spell DC or the spell '
       'or teleport fails and is wasted. Once per short or long rest.'),
      (v_monster_slayer, 15, 'Slayer''s Counter',
       'Reaction: when your marked prey forces you to make a save, make one '
       'weapon attack against it first. On a hit, you also succeed on the '
       'save.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_gloom_stalker and campaign_id is null;
  if v_count <> c_gloom_stalker_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_gloom_stalker, v_count, c_gloom_stalker_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_horizon_walker and campaign_id is null;
  if v_count <> c_horizon_walker_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_horizon_walker, v_count, c_horizon_walker_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_monster_slayer and campaign_id is null;
  if v_count <> c_monster_slayer_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_monster_slayer, v_count, c_monster_slayer_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_gloom_stalker, v_horizon_walker, v_monster_slayer);
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

insert into public.schema_migrations (version) values ('111');

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
     and s.name in ('Gloom Stalker', 'Horizon Walker', 'Monster Slayer')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 7, 11, 15]::smallint[]
     from f where subclass = 'Gloom Stalker')                 as gloom_stalker_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 7, 11, 15]::smallint[]
     from f where subclass = 'Horizon Walker')                as horizon_walker_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 7, 11, 15]::smallint[]
     from f where subclass = 'Monster Slayer')                as monster_slayer_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '111')                                            as ledger_row;

rollback;

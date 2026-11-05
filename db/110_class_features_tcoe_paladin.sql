-- db/110_class_features_tcoe_paladin.sql
--
-- The Paladin's two Tasha's oaths: Glory and the Watchers. 12 rows, all
-- subclass features, in 089's row naming. Tasha's optional base-class
-- features (Harness Divine Power, Martial Versatility) are not seeded here;
-- Blessed Warrior is already a 095 fighting-style option.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 073.
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
  c_class constant text := 'Paladin';
  c_glory                constant text := 'Oath of Glory';
  c_watchers             constant text := 'Oath of the Watchers';
  c_glory_n              constant int  := 6;
  c_watchers_n           constant int  := 6;

  v_seeking text;
  v_class   uuid;
  v_glory                uuid;
  v_watchers             uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_glory;
  select id into strict v_glory
  from public.subclasses
  where class_id = v_class and name = c_glory and campaign_id is null;

  v_seeking := 'subclass ' || c_watchers;
  select id into strict v_watchers
  from public.subclasses
  where class_id = v_class and name = c_watchers and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Oath of Glory -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_glory::uuid, 3, 'Oath Spells',
       'Always prepared, not counted against your total; the levels are '
       'paladin levels. 3rd: guiding bolt, heroism. 5th: enhance ability, '
       'magic weapon. 9th: haste, protection from energy. 13th: compulsion, '
       'freedom of movement. 17th: commune, flame strike.'),
      (v_glory, 3, 'Channel Divinity: Peerless Athlete',
       'Bonus action, for 10 minutes: advantage on Athletics and Acrobatics '
       'checks, double carrying, pushing, dragging and lifting capacity, and '
       '10 feet more on long and high jumps.'),
      (v_glory, 3, 'Channel Divinity: Inspiring Smite',
       'Bonus action, right after you deal Divine Smite damage: share 2d8 + '
       'your paladin level temporary hit points among creatures of your '
       'choice within 30 feet, you included.'),
      (v_glory, 7, 'Aura of Alacrity',
       'Your walking speed rises by 10 feet. While you aren''t incapacitated, '
       'an ally who starts its turn within 5 feet of you (10 feet at 18th '
       'level) gains 10 feet of walking speed until the end of that turn.'),
      (v_glory, 15, 'Glorious Defense',
       'Reaction: when you or a creature you can see within 10 feet is hit, '
       'add your Charisma modifier (minimum +1) to the target''s AC against '
       'it. If that makes it miss, you can make one weapon attack against '
       'the attacker if it''s in range. Uses equal to your Charisma modifier '
       '(minimum 1) per long rest.'),
      (v_glory, 20, 'Living Legend',
       'Bonus action, for 1 minute: advantage on Charisma checks; once per '
       'turn, turn a missed weapon attack into a hit; and use your reaction '
       'to reroll a failed saving throw. Once per long rest, or again by '
       'spending a 5th-level spell slot.'),
      -- ---- Oath of the Watchers ----------------------------------------------
      (v_watchers, 3, 'Oath Spells',
       'Always prepared, not counted against your total; the levels are '
       'paladin levels. 3rd: alarm, detect magic. 5th: moonbeam, see '
       'invisibility. 9th: counterspell, nondetection. 13th: aura of purity, '
       'banishment. 17th: hold monster, scrying.'),
      (v_watchers, 3, 'Channel Divinity: Watcher''s Will',
       'Action: for 1 minute, you and up to your Charisma modifier (minimum '
       '1) creatures you can see within 30 feet have advantage on '
       'Intelligence, Wisdom and Charisma saves.'),
      (v_watchers, 3, 'Channel Divinity: Abjure the Extraplanar',
       'Action: each aberration, celestial, elemental, fey or fiend within '
       '30 feet that can hear you makes a Wisdom save or is turned for 1 '
       'minute, or until it takes damage.'),
      (v_watchers, 7, 'Aura of the Sentinel',
       'You and creatures of your choice within 10 feet (30 feet at 18th '
       'level) add your proficiency bonus to initiative, while you aren''t '
       'incapacitated.'),
      (v_watchers, 15, 'Vigilant Rebuke',
       'Reaction: when you or a creature you can see within 30 feet succeeds '
       'on an Intelligence, Wisdom or Charisma save, deal 2d8 + your '
       'Charisma modifier force damage to the creature that forced it.'),
      (v_watchers, 20, 'Mortal Bulwark',
       'Bonus action, for 1 minute: truesight 120 feet and advantage on '
       'attacks against aberrations, celestials, elementals, fey and fiends. '
       'When you hit and damage one of them, it makes a Charisma save or is '
       'sent back to its home plane, if it isn''t there. Once per long rest, '
       'or again by spending a 5th-level spell slot.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_glory and campaign_id is null;
  if v_count <> c_glory_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_glory, v_count, c_glory_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_watchers and campaign_id is null;
  if v_count <> c_watchers_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_watchers, v_count, c_watchers_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_glory, v_watchers);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 073 the Paladin''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('110');

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
   where c.name = 'Paladin' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Oath of Glory', 'Oath of the Watchers')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 7, 15, 20]::smallint[]
     from f where subclass = 'Oath of Glory')                 as glory_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 7, 15, 20]::smallint[]
     from f where subclass = 'Oath of the Watchers')          as watchers_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '110')                                            as ledger_row;

rollback;

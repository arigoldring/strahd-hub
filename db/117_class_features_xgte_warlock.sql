-- db/117_class_features_xgte_warlock.sql
--
-- The Warlock's two Xanathar's patrons: the Celestial and the Hexblade. 12
-- rows, all subclass features (the base class is 093's), in 093's row naming:
-- Expanded Spell List first, keyed by spell level.
--
-- Hex Warrior's bonded weapon is chosen on each long rest, not stored.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 077.
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
  c_class constant text := 'Warlock';
  c_celestial            constant text := 'The Celestial';
  c_hexblade             constant text := 'The Hexblade';
  c_celestial_n          constant int  := 6;
  c_hexblade_n           constant int  := 6;

  v_seeking text;
  v_class   uuid;
  v_celestial            uuid;
  v_hexblade             uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_celestial;
  select id into strict v_celestial
  from public.subclasses
  where class_id = v_class and name = c_celestial and campaign_id is null;

  v_seeking := 'subclass ' || c_hexblade;
  select id into strict v_hexblade
  from public.subclasses
  where class_id = v_class and name = c_hexblade and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- The Celestial -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_celestial::uuid, 1, 'Expanded Spell List',
       'These count as warlock spells for you; the levels are spell levels. '
       '1st: cure wounds, guiding bolt. 2nd: flaming sphere, lesser '
       'restoration. 3rd: daylight, revivify. 4th: guardian of faith, wall '
       'of fire. 5th: flame strike, greater restoration.'),
      (v_celestial, 1, 'Bonus Cantrips',
       'You learn light and sacred flame. They count as warlock cantrips but '
       'not against your cantrips known.'),
      (v_celestial, 1, 'Healing Light',
       'A pool of d6s equal to 1 + your warlock level, restored on a long '
       'rest. Bonus action: heal a creature you can see within 60 feet by '
       'spending up to your Charisma modifier (minimum 1) dice from the '
       'pool.'),
      (v_celestial, 6, 'Radiant Soul',
       'Resistance to radiant damage. When you cast a spell that deals '
       'radiant or fire damage, add your Charisma modifier to one radiant or '
       'fire damage roll of it against one target.'),
      (v_celestial, 10, 'Celestial Resilience',
       'At the end of a short or long rest, gain temporary hit points equal '
       'to your warlock level + Charisma modifier, and up to five creatures '
       'you can see gain half your warlock level + Charisma modifier.'),
      (v_celestial, 14, 'Searing Vengeance',
       'When you would make a death save at the start of your turn, you can '
       'instead regain half your hit point maximum and stand if you wish. '
       'Creatures of your choice within 30 feet take 2d8 + your Charisma '
       'modifier radiant damage and are blinded until the end of the turn. '
       'Once per long rest.'),
      -- ---- The Hexblade ------------------------------------------------------
      (v_hexblade, 1, 'Expanded Spell List',
       'These count as warlock spells for you; the levels are spell levels. '
       '1st: shield, wrathful smite. 2nd: blur, branding smite. 3rd: blink, '
       'elemental weapon. 4th: phantasmal killer, staggering smite. 5th: '
       'banishing smite, cone of cold.'),
      (v_hexblade, 1, 'Hexblade''s Curse',
       'Bonus action: curse a creature you can see within 30 feet for 1 '
       'minute. Against it, add your proficiency bonus to damage rolls and '
       'score a critical hit on a 19 or 20. If it dies, regain hit points '
       'equal to your warlock level + Charisma modifier (minimum 1). Ends '
       'early if it dies, or you die or are incapacitated. Once per short or '
       'long rest.'),
      (v_hexblade, 1, 'Hex Warrior',
       'Proficiency with medium armor, shields and martial weapons. At the '
       'end of a long rest, touch one weapon you''re proficient with that '
       'isn''t two-handed: until your next long rest, you attack with it '
       'using Charisma instead of Strength or Dexterity. With Pact of the '
       'Blade, this applies to every pact weapon you conjure.'),
      (v_hexblade, 6, 'Accursed Specter',
       'When you slay a humanoid, you can raise its spirit as a specter '
       'until your next long rest. It has temporary hit points equal to half '
       'your warlock level, obeys you, acts on your turn, and adds your '
       'Charisma modifier (minimum 0) to its attack rolls. Once per long '
       'rest.'),
      (v_hexblade, 10, 'Armor of Hexes',
       'Reaction: when the target of your Hexblade''s Curse hits you, roll a '
       'd6. On a 4 or higher, the attack misses instead.'),
      (v_hexblade, 14, 'Master of Hexes',
       'When your cursed target dies, you can move the curse to another '
       'creature you can see within 30 feet, if you aren''t incapacitated. '
       'You don''t regain hit points from the first one''s death if you do.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_celestial and campaign_id is null;
  if v_count <> c_celestial_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_celestial, v_count, c_celestial_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_hexblade and campaign_id is null;
  if v_count <> c_hexblade_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_hexblade, v_count, c_hexblade_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_celestial, v_hexblade);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 077 the Warlock''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('117');

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
   where c.name = 'Warlock' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('The Celestial', 'The Hexblade')
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 1, 6, 10, 14]::smallint[]
     from f where subclass = 'The Celestial')                 as celestial_levels,
  (select array_agg(level order by level, name)
          = array[1, 1, 1, 6, 10, 14]::smallint[]
     from f where subclass = 'The Hexblade')                  as hexblade_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '117')                                            as ledger_row;

rollback;

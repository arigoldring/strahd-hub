-- db/120_class_features_tcoe_wizard.sql
--
-- The Wizard's two Tasha's traditions: Bladesinging and the Order of Scribes.
-- 10 rows, all subclass features. Tasha's optional base-class feature
-- (Cantrip Formulas) is not seeded here.
--
-- Picks the player notes by hand: Training in War and Song's weapon. The
-- Bladesinger's Extra Attack repeats the Fighter's feature name; the unique
-- name index is per class and subclass, so that's allowed.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 078.
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
  c_class constant text := 'Wizard';
  c_bladesinging         constant text := 'Bladesinging';
  c_scribes              constant text := 'Order of Scribes';
  c_bladesinging_n       constant int  := 5;
  c_scribes_n            constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_bladesinging         uuid;
  v_scribes              uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_bladesinging;
  select id into strict v_bladesinging
  from public.subclasses
  where class_id = v_class and name = c_bladesinging and campaign_id is null;

  v_seeking := 'subclass ' || c_scribes;
  select id into strict v_scribes
  from public.subclasses
  where class_id = v_class and name = c_scribes and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Bladesinging ------------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_bladesinging::uuid, 2, 'Training in War and Song',
       'Proficiency with light armor, one type of one-handed melee weapon '
       '(note your pick) and Performance.'),
      (v_bladesinging, 2, 'Bladesong',
       'Bonus action, for 1 minute, while wearing no medium or heavy armor '
       'and no shield: add your Intelligence modifier (minimum +1) to AC and '
       'to Constitution saves to keep concentration, +10 feet of walking '
       'speed, and advantage on Acrobatics checks. It ends if you''re '
       'incapacitated, put on medium or heavy armor or a shield, or attack '
       'with a weapon in two hands. Uses equal to your proficiency bonus per '
       'long rest.'),
      (v_bladesinging, 6, 'Extra Attack',
       'You attack twice when you take the Attack action on your turn, and '
       'one of the attacks can be a cantrip instead.'),
      (v_bladesinging, 10, 'Song of Defense',
       'Reaction, while Bladesong is active: when you take damage, spend a '
       'spell slot to reduce the damage by five times its level.'),
      (v_bladesinging, 14, 'Song of Victory',
       'While Bladesong is active, add your Intelligence modifier (minimum '
       '+1) to the damage of your melee weapon attacks.'),
      -- ---- Order of Scribes --------------------------------------------------
      (v_scribes, 2, 'Wizardly Quill',
       'Bonus action: conjure a Tiny quill that needs no ink. Copying a '
       'spell into your spellbook with it takes 2 minutes per spell level, '
       'and you can erase its writing within 5 feet as a bonus action. It '
       'vanishes if you make another or die.'),
      (v_scribes, 2, 'Awakened Spellbook',
       'Your spellbook is a spellcasting focus. When you cast a wizard spell '
       'with a slot, you can swap its damage type for one from another spell '
       'of that level in your spellbook. Once per long rest, you can cast a '
       'wizard spell as a ritual in its normal casting time.'),
      (v_scribes, 6, 'Manifest Mind',
       'Bonus action: your spellbook''s spirit appears as a Tiny spectral '
       'form within 60 feet, shedding dim light for 10 feet, with darkvision '
       '60 feet. You see and hear through it, and move it 30 feet as a bonus '
       'action. It ends if it is more than 300 feet away. When you cast a '
       'wizard spell on your turn, it can come from the spirit''s space, as '
       'many times as your proficiency bonus per long rest, or again by '
       'spending a spell slot.'),
      (v_scribes, 10, 'Master Scrivener',
       'After a long rest, use your quill to copy a 1st- or 2nd-level spell '
       'from your spellbook onto a blank scroll. It casts one level higher '
       'than normal, only you can use it, and it fades at your next long '
       'rest if unused.'),
      (v_scribes, 14, 'One with the Word',
       'Advantage on Intelligence (Arcana) checks. Reaction, while the '
       'spirit is manifested: when you take damage, dismiss it to prevent '
       'all of that damage. Then roll 3d6; your spellbook loses spells of '
       'your choice whose levels total at least the roll, and they return '
       'after 1d6 long rests. Once per long rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_bladesinging and campaign_id is null;
  if v_count <> c_bladesinging_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_bladesinging, v_count, c_bladesinging_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_scribes and campaign_id is null;
  if v_count <> c_scribes_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_scribes, v_count, c_scribes_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_bladesinging, v_scribes);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 078 the Wizard''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('120');

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
   where c.name = 'Wizard' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Bladesinging', 'Order of Scribes')
)
select
  (select array_agg(level order by level, name)
          = array[2, 2, 6, 10, 14]::smallint[]
     from f where subclass = 'Bladesinging')                  as bladesinging_levels,
  (select array_agg(level order by level, name)
          = array[2, 2, 6, 10, 14]::smallint[]
     from f where subclass = 'Order of Scribes')              as scribes_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '120')                                            as ledger_row;

rollback;

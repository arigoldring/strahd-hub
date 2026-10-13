-- db/081_class_features_fighter_base.sql
--
-- The rest of the Fighter's base-class features, levels 2 to 20: Action
-- Surge, Ability Score Improvement, Extra Attack, Indomitable. RUN 080 FIRST.
--
-- 080 seeded level 1 only, so until this file a Fighter 2 had no level-2
-- feature on the sheet.
--
-- ONE ROW PER NAMED FEATURE, AT THE LEVEL IT FIRST ARRIVES. The PHB describes
-- a scaling feature once ("three attacks at 11th, four at 20th") and so does
-- this table: the later steps live in the text. 079's unique index on
-- (class_id, subclass_id, name) would refuse a second "Extra Attack" row
-- anyway, and suffixed rows ("Extra Attack (2)") would stack, since the sheet
-- shows every row at or below the class's level. The cost: a Fighter 11 sees
-- "Level 5" on Extra Attack and reads the upgrade in the text.
--
-- No "Martial Archetype" row at level 3: the sheet already prints the picked
-- subclass's name and description above the feature list. Archetype features
-- are 082.
--
-- Display only, like 080: no use is tracked and Extra Attack adds no rows to
-- the attacks block. See KNOWN_ISSUES.
--
-- THE SQL EDITOR WILL OFFER "Run and enable RLS": it misreads plpgsql's
-- `into strict` as a table being created (CLAUDE.md). This file creates no
-- table. Take the option that runs WITHOUT enabling.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class    constant text := 'Fighter';
  -- Every shared base-class row after this file: 080's two plus these four.
  -- Counting the total, not the inserts, also proves 080 ran.
  c_expected constant int  := 6;

  v_class   uuid;
  v_count   int;
  v_choices int;
begin
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  insert into public.class_features (class_id, level, name, description)
  select v_class, v.level, v.name, v.description
  from (values
      (2, 'Action Surge',
       'Starting at 2nd level, you can push yourself beyond your normal limits '
       'for a moment. On your turn, you can take one additional action. Once you '
       'use this feature, you must finish a short or long rest before you can use '
       'it again. Starting at 17th level, you can use it twice before a rest, but '
       'only once on the same turn.'),
      (4, 'Ability Score Improvement',
       'When you reach 4th level, and again at 6th, 8th, 12th, 14th, 16th, and '
       '19th level, you can increase one ability score of your choice by 2, or you '
       'can increase two ability scores of your choice by 1. As normal, you can''t '
       'increase an ability score above 20 using this feature. If your DM uses '
       'feats, you can take a feat instead.'),
      (5, 'Extra Attack',
       'Beginning at 5th level, you can attack twice, instead of once, whenever '
       'you take the Attack action on your turn. The number of attacks increases '
       'to three when you reach 11th level in this class and to four when you '
       'reach 20th level in this class.'),
      (9, 'Indomitable',
       'Beginning at 9th level, you can reroll a saving throw that you fail. If '
       'you do so, you must use the new roll, and you can''t use this feature '
       'again until you finish a long rest. You can use this feature twice '
       'between long rests starting at 13th level and three times between long '
       'rests starting at 17th level.')
  ) as v(level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*), count(*) filter (where choice = 'fighting_style')
    into v_count, v_choices
  from public.class_features
  where class_id = v_class and subclass_id is null and campaign_id is null;

  if v_count <> c_expected or v_choices <> 1 then
    raise exception
      '% has % shared base-class features (expected %), % with a fighting-style picker (expected 1). Rolled back.',
      c_class, v_count, c_expected, v_choices;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared class is named "%". 055 seeds it; check: select name from classes where campaign_id is null;',
      c_class;
  when too_many_rows then
    raise exception
      'More than one shared class is named "%". Resolve the duplicate before seeding its features.',
      c_class;
end
$$;

insert into public.schema_migrations (version) values ('081');

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

select
  (select count(*) = 6 from public.class_features f
     join public.classes c on c.id = f.class_id
    where c.name = 'Fighter' and c.campaign_id is null
      and f.campaign_id is null and f.subclass_id is null)          as count_6,
  (select array_agg(f.level order by f.level, f.name)
          = array[1, 1, 2, 4, 5, 9]::smallint[]
     from public.class_features f
     join public.classes c on c.id = f.class_id
    where c.name = 'Fighter' and c.campaign_id is null
      and f.campaign_id is null and f.subclass_id is null)          as levels_right,
  (select count(*) = 1 from public.class_features f
     join public.classes c on c.id = f.class_id
    where c.name = 'Fighter' and c.campaign_id is null
      and f.name = 'Action Surge' and f.level = 2)                  as action_surge,
  (select count(*) = 1 from public.schema_migrations
    where version = '081')                                          as ledger_row;

rollback;

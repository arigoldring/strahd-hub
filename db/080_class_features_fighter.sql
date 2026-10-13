-- db/080_class_features_fighter.sql
--
-- The Fighter's two level-1 class features: Fighting Style and Second Wind.
-- The first rows in 079's catalogue. RUN 079 FIRST.
--
-- These are CLASS features, not archetype ones: subclass_id is null. The
-- Martial Archetype arrives at level 3, and its features (Improved Critical,
-- Combat Superiority...) will be their own rows pointing at 071's subclasses.
--
-- Fighting Style carries choice = 'fighting_style', which is what makes the
-- sheet render a picker under it. The eleven styles' own text is in
-- FIGHTING_STYLES (src/data/rules.ts), beside the CHECK 079 puts on the pick.
--
-- Display only for now: no style changes a derived number yet, and Second
-- Wind's use isn't tracked. See KNOWN_ISSUES.
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
  c_expected constant int  := 2;

  v_class   uuid;
  v_count   int;
  v_choices int;
begin
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  insert into public.class_features (class_id, level, name, choice, description)
  select v_class, v.level, v.name, v.choice, v.description
  from (values
      (1, 'Fighting Style', 'fighting_style',
       'You adopt a particular style of fighting as your specialty. Choose one '
       'option. You can''t take the same Fighting Style option more than once, '
       'even if you later get to choose again.'),
      (1, 'Second Wind', null,
       'You have a limited well of stamina that you can draw on to protect '
       'yourself from harm. On your turn, you can use a bonus action to regain '
       'hit points equal to 1d10 + your fighter level. Once you use this '
       'feature, you must finish a short or long rest before you can use it again.')
  ) as v(level, name, choice, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*), count(*) filter (where choice = 'fighting_style')
    into v_count, v_choices
  from public.class_features
  where class_id = v_class and subclass_id is null and level = 1
    and campaign_id is null;

  if v_count <> c_expected or v_choices <> 1 then
    raise exception
      '% has % shared level-1 features (expected %), % with a fighting-style picker (expected 1). Rolled back.',
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

insert into public.schema_migrations (version) values ('080');

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
  (select count(*) = 2 from public.class_features f
     join public.classes c on c.id = f.class_id
    where c.name = 'Fighter' and c.campaign_id is null
      and f.campaign_id is null and f.subclass_id is null)          as count_2,
  (select count(*) = 1 from public.class_features f
     join public.classes c on c.id = f.class_id
    where c.name = 'Fighter' and c.campaign_id is null
      and f.name = 'Fighting Style' and f.choice = 'fighting_style') as picker_row,
  (select count(*) = 1 from public.class_features f
     join public.classes c on c.id = f.class_id
    where c.name = 'Fighter' and c.campaign_id is null
      and f.name = 'Second Wind' and f.choice is null)              as second_wind,
  (select count(*) = 1 from public.schema_migrations
    where version = '080')                                          as ledger_row;

rollback;

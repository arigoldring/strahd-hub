-- db/100_class_features_tcoe_bard.sql
--
-- The Bard's two Tasha's colleges: Creation and Eloquence. 9 rows, all
-- subclass features. Tasha's optional base-class features (Magical
-- Inspiration, Bardic Versatility) are not seeded here.
--
-- The Dancing Item's stat block is referenced, not reproduced.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 068.
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
  c_class constant text := 'Bard';
  c_creation             constant text := 'College of Creation';
  c_eloquence            constant text := 'College of Eloquence';
  c_creation_n           constant int  := 4;
  c_eloquence_n          constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_creation             uuid;
  v_eloquence            uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_creation;
  select id into strict v_creation
  from public.subclasses
  where class_id = v_class and name = c_creation and campaign_id is null;

  v_seeking := 'subclass ' || c_eloquence;
  select id into strict v_eloquence
  from public.subclasses
  where class_id = v_class and name = c_eloquence and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- College of Creation -----------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_creation::uuid, 3, 'Mote of Potential',
       concat_ws(E'\n',
       'When you give Bardic Inspiration, a tiny mote orbits the creature. '
       'When it uses the die:',
       '- Ability check: roll the die twice and use either.',
       '- Attack roll: on a hit, the target and creatures of the user''s '
       'choice within 5 feet of it make a Constitution save against your '
       'spell DC or take thunder damage equal to the roll.',
       '- Saving throw: the user also gains temporary hit points equal to '
       'the roll + your Charisma modifier (minimum 1).')),
      (v_creation, 3, 'Performance of Creation',
       'Action: create one nonmagical item within 10 feet, worth up to 20 gp '
       'x your bard level, Medium or smaller (Large at 6th level, Huge at '
       '14th). It shimmers faintly and lasts hours equal to your proficiency '
       'bonus. A new one ends the old. Once per long rest, or again by '
       'spending a spell slot of 2nd level or higher.'),
      (v_creation, 6, 'Animating Performance',
       'Action: animate a Large or smaller nonmagical item within 30 feet as '
       'a Dancing Item (Tasha''s stat block) for 1 hour. It is friendly, acts '
       'on your turn, and takes the Dodge action unless you command it with '
       'a bonus action. It ends at 0 hit points or if you die. Once per long '
       'rest, or again by spending a spell slot of 3rd level or higher.'),
      (v_creation, 14, 'Creative Crescendo',
       'Performance of Creation makes as many items as your Charisma '
       'modifier (minimum 2): one up to the usual size, the rest Small or '
       'smaller. The gold-value limit no longer applies. Past the limit, the '
       'oldest item vanishes.'),
      -- ---- College of Eloquence ----------------------------------------------
      (v_eloquence, 3, 'Silver Tongue',
       'On a Charisma (Persuasion) or (Deception) check, treat a d20 roll of '
       '9 or lower as a 10.'),
      (v_eloquence, 3, 'Unsettling Words',
       'Bonus action, spending one Bardic Inspiration use: roll the die, and '
       'one creature you can see within 60 feet subtracts the roll from the '
       'next saving throw it makes before the start of your next turn.'),
      (v_eloquence, 6, 'Unfailing Inspiration',
       'When a creature adds your Bardic Inspiration die to a roll and still '
       'fails, it keeps the die.'),
      (v_eloquence, 6, 'Universal Speech',
       'Action: up to your Charisma modifier (minimum 1) creatures within 60 '
       'feet can understand you, whatever language you speak, for 1 hour. '
       'Once per long rest, or again by spending a spell slot.'),
      (v_eloquence, 14, 'Infectious Inspiration',
       'When a creature within 60 feet succeeds on a roll using your Bardic '
       'Inspiration, you can use your reaction to give another creature '
       'within 60 feet that can hear you a Bardic Inspiration die without '
       'spending a use. Uses equal to your Charisma modifier (minimum 1) per '
       'long rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_creation and campaign_id is null;
  if v_count <> c_creation_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_creation, v_count, c_creation_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_eloquence and campaign_id is null;
  if v_count <> c_eloquence_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_eloquence, v_count, c_eloquence_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_creation, v_eloquence);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 068 the Bard''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('100');

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
   where c.name = 'Bard' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('College of Creation', 'College of Eloquence')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 6, 14]::smallint[]
     from f where subclass = 'College of Creation')           as creation_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 6, 6, 14]::smallint[]
     from f where subclass = 'College of Eloquence')          as eloquence_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '100')                                            as ledger_row;

rollback;

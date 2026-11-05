-- db/113_class_features_xgte_rogue.sql
--
-- The Rogue's four Xanathar's archetypes: Inquisitive, Mastermind, Scout and
-- Swashbuckler. 21 rows, all subclass features (the base class is 091's).
--
-- Picks the player notes by hand: the Mastermind's gaming set and two
-- languages.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 075.
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
  c_class constant text := 'Rogue';
  c_inquisitive          constant text := 'Inquisitive';
  c_mastermind           constant text := 'Mastermind';
  c_scout                constant text := 'Scout';
  c_swashbuckler         constant text := 'Swashbuckler';
  c_inquisitive_n        constant int  := 6;
  c_mastermind_n         constant int  := 5;
  c_scout_n              constant int  := 5;
  c_swashbuckler_n       constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_inquisitive          uuid;
  v_mastermind           uuid;
  v_scout                uuid;
  v_swashbuckler         uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_inquisitive;
  select id into strict v_inquisitive
  from public.subclasses
  where class_id = v_class and name = c_inquisitive and campaign_id is null;

  v_seeking := 'subclass ' || c_mastermind;
  select id into strict v_mastermind
  from public.subclasses
  where class_id = v_class and name = c_mastermind and campaign_id is null;

  v_seeking := 'subclass ' || c_scout;
  select id into strict v_scout
  from public.subclasses
  where class_id = v_class and name = c_scout and campaign_id is null;

  v_seeking := 'subclass ' || c_swashbuckler;
  select id into strict v_swashbuckler
  from public.subclasses
  where class_id = v_class and name = c_swashbuckler and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Inquisitive -------------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_inquisitive::uuid, 3, 'Ear for Deceit',
       'On a Wisdom (Insight) check to tell whether a creature is lying, '
       'treat a d20 roll of 7 or lower as an 8.'),
      (v_inquisitive, 3, 'Eye for Detail',
       'Bonus action: a Wisdom (Perception) check to spot a hidden creature '
       'or object, or an Intelligence (Investigation) check to find or read '
       'clues.'),
      (v_inquisitive, 3, 'Insightful Fighting',
       'Bonus action: a Wisdom (Insight) check against the Charisma '
       '(Deception) of a creature you can see that isn''t incapacitated. On a '
       'success, you can Sneak Attack it without advantage (never with '
       'disadvantage) for 1 minute, or until you use this on another target.'),
      (v_inquisitive, 9, 'Steady Eye',
       'Advantage on Perception and Investigation checks if you move no more '
       'than half your speed that turn.'),
      (v_inquisitive, 13, 'Unerring Eye',
       'Action: sense illusions, shapechangers out of their true form and '
       'other deceiving magic within 30 feet, though not what they hide. Not '
       'while blinded or deafened. Uses equal to your Wisdom modifier '
       '(minimum 1) per long rest.'),
      (v_inquisitive, 17, 'Eye for Weakness',
       'Your Sneak Attack deals an extra 3d6 against a creature your '
       'Insightful Fighting applies to.'),
      -- ---- Mastermind --------------------------------------------------------
      (v_mastermind, 3, 'Master of Intrigue',
       'Proficiency with the disguise kit, the forgery kit and one gaming '
       'set, and two languages (note your picks). After hearing a creature '
       'speak for 1 minute, you can mimic its speech and accent.'),
      (v_mastermind, 3, 'Master of Tactics',
       'Help as a bonus action. When you help an ally attack, the target can '
       'be up to 30 feet from you if it can see or hear you.'),
      (v_mastermind, 9, 'Insightful Manipulator',
       'After 1 minute observing or talking with a creature outside combat, '
       'learn whether it is your equal, superior or inferior in two of: '
       'Intelligence, Wisdom, Charisma or class levels. The DM may add a '
       'fact about its past or personality.'),
      (v_mastermind, 13, 'Misdirection',
       'Reaction: when you are attacked while a creature within 5 feet gives '
       'you cover against it, make the attack target that creature instead.'),
      (v_mastermind, 17, 'Soul of Deceit',
       'Telepathy and mind reading can''t reach your thoughts unless you '
       'allow it, and a Deception check against the reader''s Insight shows '
       'them false ones. Magic that detects lies reads you as truthful if '
       'you wish, and you can''t be magically compelled to tell the truth.'),
      -- ---- Scout -------------------------------------------------------------
      (v_scout, 3, 'Skirmisher',
       'Reaction: when an enemy ends its turn within 5 feet of you, move up '
       'to half your speed without provoking opportunity attacks.'),
      (v_scout, 3, 'Survivalist',
       'Proficiency in Nature and Survival, with your proficiency bonus '
       'doubled for them.'),
      (v_scout, 9, 'Superior Mobility',
       'Your walking speed rises by 10 feet, and so do any climbing and '
       'swimming speeds you have.'),
      (v_scout, 13, 'Ambush Master',
       'Advantage on initiative. The first creature you hit in the first '
       'round of a combat has attacks against it made with advantage until '
       'the start of your next turn.'),
      (v_scout, 17, 'Sudden Strike',
       'When you take the Attack action, you can make one more attack as a '
       'bonus action. It can Sneak Attack even if you already have this '
       'turn, but not the same target twice.'),
      -- ---- Swashbuckler ------------------------------------------------------
      (v_swashbuckler, 3, 'Fancy Footwork',
       'On your turn, a creature you make a melee attack against can''t make '
       'opportunity attacks against you for the rest of that turn.'),
      (v_swashbuckler, 3, 'Rakish Audacity',
       'Add your Charisma modifier to initiative. You can Sneak Attack '
       'without advantage when no creature but your target is within 5 feet '
       'of you and you don''t have disadvantage.'),
      (v_swashbuckler, 9, 'Panache',
       'Action: Charisma (Persuasion) against a creature''s Wisdom (Insight); '
       'it must hear you and share a language. If hostile, it has '
       'disadvantage on attacks against anyone but you and can''t make '
       'opportunity attacks against others, for 1 minute or until your '
       'allies attack it or you move 60 feet apart. If not hostile, it is '
       'charmed for 1 minute, ending if you or your allies harm it.'),
      (v_swashbuckler, 13, 'Elegant Maneuver',
       'Bonus action: advantage on your next Acrobatics or Athletics check '
       'this turn.'),
      (v_swashbuckler, 17, 'Master Duelist',
       'When you miss with an attack, reroll it with advantage. Once per '
       'short or long rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_inquisitive and campaign_id is null;
  if v_count <> c_inquisitive_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_inquisitive, v_count, c_inquisitive_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_mastermind and campaign_id is null;
  if v_count <> c_mastermind_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_mastermind, v_count, c_mastermind_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_scout and campaign_id is null;
  if v_count <> c_scout_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_scout, v_count, c_scout_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_swashbuckler and campaign_id is null;
  if v_count <> c_swashbuckler_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_swashbuckler, v_count, c_swashbuckler_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_inquisitive, v_mastermind, v_scout, v_swashbuckler);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 075 the Rogue''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('113');

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
   where c.name = 'Rogue' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Inquisitive', 'Mastermind', 'Scout', 'Swashbuckler')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 9, 13, 17]::smallint[]
     from f where subclass = 'Inquisitive')                   as inquisitive_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 9, 13, 17]::smallint[]
     from f where subclass = 'Mastermind')                    as mastermind_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 9, 13, 17]::smallint[]
     from f where subclass = 'Scout')                         as scout_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 9, 13, 17]::smallint[]
     from f where subclass = 'Swashbuckler')                  as swashbuckler_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '113')                                            as ledger_row;

rollback;

-- db/108_class_features_tcoe_monk.sql
--
-- The Monk's two Tasha's traditions: Mercy and the Astral Self. 10 rows, all
-- subclass features. Tasha's optional base-class features (Dedicated Weapon,
-- Ki-Fueled Attack, Quickened Healing, Focused Aim) are not seeded here.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 072.
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
  c_class constant text := 'Monk';
  c_mercy                constant text := 'Way of Mercy';
  c_astral_self          constant text := 'Way of the Astral Self';
  c_mercy_n              constant int  := 6;
  c_astral_self_n        constant int  := 4;

  v_seeking text;
  v_class   uuid;
  v_mercy                uuid;
  v_astral_self          uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_mercy;
  select id into strict v_mercy
  from public.subclasses
  where class_id = v_class and name = c_mercy and campaign_id is null;

  v_seeking := 'subclass ' || c_astral_self;
  select id into strict v_astral_self
  from public.subclasses
  where class_id = v_class and name = c_astral_self and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Way of Mercy ------------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_mercy::uuid, 3, 'Implements of Mercy',
       'Proficiency in Insight and Medicine and with the herbalism kit, and '
       'a mask you often wear.'),
      (v_mercy, 3, 'Hand of Healing',
       'Action, spending 1 ki: a creature you touch regains hit points equal '
       'to your Martial Arts die + your Wisdom modifier. When you use Flurry '
       'of Blows, you can swap one of its unarmed strikes for this, without '
       'spending ki.'),
      (v_mercy, 3, 'Hand of Harm',
       'Once per turn, when an unarmed strike hits and deals damage, spend 1 '
       'ki for extra necrotic damage equal to your Martial Arts die + your '
       'Wisdom modifier.'),
      (v_mercy, 6, 'Physician''s Touch',
       'Hand of Healing also ends one disease, or one of blinded, deafened, '
       'paralyzed, poisoned or stunned. Hand of Harm can also poison the '
       'target until the end of your next turn.'),
      (v_mercy, 11, 'Flurry of Healing and Harm',
       'Flurry of Blows can swap every unarmed strike for Hand of Healing, '
       'without spending ki. Its strikes can also use Hand of Harm without '
       'spending ki, still once per turn.'),
      (v_mercy, 17, 'Hand of Ultimate Mercy',
       'Action, spending 5 ki: touch the corpse of a creature dead for no '
       'more than 24 hours. It returns to life with 4d10 + your Wisdom '
       'modifier hit points, cured of the conditions Physician''s Touch ends. '
       'Once per long rest.'),
      -- ---- Way of the Astral Self --------------------------------------------
      (v_astral_self, 3, 'Arms of the Astral Self',
       'Bonus action, spending 1 ki: summon spectral arms for 10 minutes. '
       'Creatures of your choice within 10 feet make a Dexterity save or '
       'take force damage equal to two rolls of your Martial Arts die. While '
       'they last, use Wisdom for Strength checks and saves, and you can '
       'make unarmed strikes with the arms: 5 feet of extra reach, Wisdom or '
       'Dexterity for attack and damage, force damage.'),
      (v_astral_self, 6, 'Visage of the Astral Self',
       'Bonus action, spending 1 ki (or as part of summoning the arms): a '
       'spectral visage for 10 minutes. You see normally in any darkness out '
       'to 120 feet, have advantage on Insight and Intimidation checks, and '
       'can make your words heard by one creature within 60 feet only, or '
       'boom them out to 600 feet.'),
      (v_astral_self, 11, 'Body of the Astral Self',
       'With both arms and visage summoned: use your reaction to reduce '
       'acid, cold, fire, force, lightning or thunder damage you take by '
       '1d10 + your Wisdom modifier, and once per turn add your Martial Arts '
       'die to an arm''s hit.'),
      (v_astral_self, 17, 'Awakened Astral Self',
       'Bonus action, spending 5 ki: summon arms, visage and body for 10 '
       'minutes. You gain +2 AC, and Extra Attack makes three attacks with '
       'the arms instead of two.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_mercy and campaign_id is null;
  if v_count <> c_mercy_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_mercy, v_count, c_mercy_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_astral_self and campaign_id is null;
  if v_count <> c_astral_self_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_astral_self, v_count, c_astral_self_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_mercy, v_astral_self);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 072 the Monk''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('108');

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
   where c.name = 'Monk' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Way of Mercy', 'Way of the Astral Self')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 6, 11, 17]::smallint[]
     from f where subclass = 'Way of Mercy')                  as mercy_levels,
  (select array_agg(level order by level, name)
          = array[3, 6, 11, 17]::smallint[]
     from f where subclass = 'Way of the Astral Self')        as astral_self_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '108')                                            as ledger_row;

rollback;

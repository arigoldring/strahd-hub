-- db/107_class_features_xgte_monk.sql
--
-- The Monk's three Xanathar's traditions: Drunken Master, Kensei and Sun Soul.
-- 13 rows, all subclass features (the base class is 088's).
--
-- Picks the player notes by hand: the Kensei's weapons (two at 3rd, one more
-- at 6th, 11th and 17th), a many-pick feature, and Way of the Brush's tool.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
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
  c_drunken_master       constant text := 'Way of the Drunken Master';
  c_kensei               constant text := 'Way of the Kensei';
  c_sun_soul             constant text := 'Way of the Sun Soul';
  c_drunken_master_n     constant int  := 5;
  c_kensei_n             constant int  := 4;
  c_sun_soul_n           constant int  := 4;

  v_seeking text;
  v_class   uuid;
  v_drunken_master       uuid;
  v_kensei               uuid;
  v_sun_soul             uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_drunken_master;
  select id into strict v_drunken_master
  from public.subclasses
  where class_id = v_class and name = c_drunken_master and campaign_id is null;

  v_seeking := 'subclass ' || c_kensei;
  select id into strict v_kensei
  from public.subclasses
  where class_id = v_class and name = c_kensei and campaign_id is null;

  v_seeking := 'subclass ' || c_sun_soul;
  select id into strict v_sun_soul
  from public.subclasses
  where class_id = v_class and name = c_sun_soul and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Way of the Drunken Master -----------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_drunken_master::uuid, 3, 'Bonus Proficiencies',
       'Proficiency in Performance and with brewer''s supplies.'),
      (v_drunken_master, 3, 'Drunken Technique',
       'When you use Flurry of Blows, you also gain the benefit of the '
       'Disengage action, and your walking speed rises by 10 feet until the '
       'end of the turn.'),
      (v_drunken_master, 6, 'Tipsy Sway',
       concat_ws(E'\n',
       '- Leap to Your Feet: standing up from prone costs only 5 feet of '
       'movement.',
       '- Redirect Attack: when a creature misses you with a melee attack, '
       'spend 1 ki as a reaction to make it hit another creature of your '
       'choice within 5 feet of you instead.')),
      (v_drunken_master, 11, 'Drunkard''s Luck',
       'When you have disadvantage on an ability check, attack roll or '
       'saving throw, spend 2 ki to cancel it.'),
      (v_drunken_master, 17, 'Intoxicated Frenzy',
       'Flurry of Blows can make up to three extra attacks (five in all), as '
       'long as each one targets a different creature this turn.'),
      -- ---- Way of the Kensei -------------------------------------------------
      (v_kensei, 3, 'Path of the Kensei',
       concat_ws(E'\n',
       '- Kensei Weapons: pick two weapon types (note them), one melee and '
       'one ranged, simple or martial without the heavy or special property '
       '(a longbow also qualifies). You''re proficient with them and they '
       'count as monk weapons. One more at 6th, 11th and 17th level.',
       '- Agile Parry: if you make an unarmed strike as part of the Attack '
       'action while holding a kensei weapon, +2 AC until the start of your '
       'next turn, while you hold it and aren''t incapacitated.',
       '- Kensei''s Shot: bonus action, your ranged attacks with a kensei '
       'weapon deal an extra 1d4 damage this turn.',
       '- Way of the Brush: proficiency with calligrapher''s or painter''s '
       'supplies (note your pick).')),
      (v_kensei, 6, 'One with the Blade',
       concat_ws(E'\n',
       '- Magic Kensei Weapons: your attacks with kensei weapons count as '
       'magical.',
       '- Deft Strike: once per turn, when you hit with a kensei weapon, '
       'spend 1 ki for extra damage equal to your Martial Arts die.')),
      (v_kensei, 11, 'Sharpen the Blade',
       'Bonus action: spend up to 3 ki to give a kensei weapon you touch +1 '
       'to attack and damage rolls per ki spent, for 1 minute or until you '
       'use this again. No effect on a magic weapon that already has a '
       'bonus.'),
      (v_kensei, 17, 'Unerring Accuracy',
       'Once on each of your turns, when you miss with a monk weapon, you '
       'can reroll the attack.'),
      -- ---- Way of the Sun Soul -----------------------------------------------
      (v_sun_soul, 3, 'Radiant Sun Bolt',
       'A ranged spell attack at 30 feet, proficient, using Dexterity: '
       'radiant damage equal to your Martial Arts die + Dexterity modifier. '
       'It can replace any attack of the Attack action. If you use it that '
       'way, you can spend 1 ki to make it twice more as a bonus action.'),
      (v_sun_soul, 6, 'Searing Arc Strike',
       'Right after you take the Attack action, spend 2 ki to cast burning '
       'hands as a bonus action, plus 1 ki per spell level above 1st. The '
       'total ki can''t exceed half your monk level.'),
      (v_sun_soul, 11, 'Searing Sunburst',
       'Action: a 20-foot-radius burst at a point within 150 feet. Each '
       'creature in it makes a Constitution save against your ki save DC or '
       'takes 2d6 radiant damage; total cover protects. Spend up to 3 ki for '
       '+2d6 each.'),
      (v_sun_soul, 17, 'Sun Shield',
       'You shed bright light for 30 feet and dim light for 30 more, and can '
       'toggle it as a bonus action. While it shines, when a creature hits '
       'you with a melee attack, use your reaction to deal it 5 + your '
       'Wisdom modifier radiant damage.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_drunken_master and campaign_id is null;
  if v_count <> c_drunken_master_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_drunken_master, v_count, c_drunken_master_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_kensei and campaign_id is null;
  if v_count <> c_kensei_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_kensei, v_count, c_kensei_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_sun_soul and campaign_id is null;
  if v_count <> c_sun_soul_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_sun_soul, v_count, c_sun_soul_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_drunken_master, v_kensei, v_sun_soul);
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

insert into public.schema_migrations (version) values ('107');

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
     and s.name in ('Way of the Drunken Master', 'Way of the Kensei', 'Way of the Sun Soul')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 6, 11, 17]::smallint[]
     from f where subclass = 'Way of the Drunken Master')     as drunken_master_levels,
  (select array_agg(level order by level, name)
          = array[3, 6, 11, 17]::smallint[]
     from f where subclass = 'Way of the Kensei')             as kensei_levels,
  (select array_agg(level order by level, name)
          = array[3, 6, 11, 17]::smallint[]
     from f where subclass = 'Way of the Sun Soul')           as sun_soul_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '107')                                            as ledger_row;

rollback;

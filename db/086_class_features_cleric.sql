-- db/086_class_features_cleric.sql
--
-- The Cleric's base-class features (levels 1-20) and its seven PHB Divine
-- Domains. 52 rows. RUN 085 FIRST (ledger order only).
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision: the domain
-- is chosen at 1st level, and Divine Strike / Potent Spellcasting arrive at 8th.
--
-- 084's shape: one file per class, base + PHB subclass rows. 081's rule: one
-- row per named feature at its first level, later steps in the text
-- (Channel Divinity's uses, Destroy Undead's CR, Divine Strike's 2d8 at 14th).
--
-- Domain spells are one row per domain at 1st level, listing every pair with
-- the cleric level it unlocks at. They are always prepared and don't count
-- against the prepared total; nothing in the app enforces that.
--
-- Each domain's Channel Divinity option is its own row named
-- "Channel Divinity: <option>", beside the base row that says how many uses
-- there are. That is how the PHB names them, and it keeps the unique
-- (class_id, subclass_id, name) index happy.
--
-- TEXT: short summaries in our own words, mechanics intact.
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
  c_class         constant text := 'Cleric';
  c_knowledge     constant text := 'Knowledge Domain';
  c_life          constant text := 'Life Domain';
  c_light         constant text := 'Light Domain';
  c_nature        constant text := 'Nature Domain';
  c_tempest       constant text := 'Tempest Domain';
  c_trickery      constant text := 'Trickery Domain';
  c_war           constant text := 'War Domain';
  c_expected_base constant int  := 5;
  c_expected_kn   constant int  := 6;
  c_expected_li   constant int  := 7;
  c_expected_lt   constant int  := 7;
  c_expected_na   constant int  := 7;
  c_expected_te   constant int  := 7;
  c_expected_tr   constant int  := 6;
  c_expected_wa   constant int  := 7;

  v_seeking   text;

  v_class     uuid;
  v_knowledge uuid;
  v_life      uuid;
  v_light     uuid;
  v_nature    uuid;
  v_tempest   uuid;
  v_trickery  uuid;
  v_war       uuid;
  v_base int; v_kn int; v_li int; v_lt int; v_na int; v_te int; v_tr int; v_wa int;
  v_choices   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_knowledge;
  select id into strict v_knowledge from public.subclasses
  where class_id = v_class and name = c_knowledge and campaign_id is null;

  v_seeking := 'subclass ' || c_life;
  select id into strict v_life from public.subclasses
  where class_id = v_class and name = c_life and campaign_id is null;

  v_seeking := 'subclass ' || c_light;
  select id into strict v_light from public.subclasses
  where class_id = v_class and name = c_light and campaign_id is null;

  v_seeking := 'subclass ' || c_nature;
  select id into strict v_nature from public.subclasses
  where class_id = v_class and name = c_nature and campaign_id is null;

  v_seeking := 'subclass ' || c_tempest;
  select id into strict v_tempest from public.subclasses
  where class_id = v_class and name = c_tempest and campaign_id is null;

  v_seeking := 'subclass ' || c_trickery;
  select id into strict v_trickery from public.subclasses
  where class_id = v_class and name = c_trickery and campaign_id is null;

  v_seeking := 'subclass ' || c_war;
  select id into strict v_war from public.subclasses
  where class_id = v_class and name = c_war and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (null::uuid, 1, 'Spellcasting', concat_ws(E'\n',
       'Wisdom is your spellcasting ability. Spell save DC = 8 + proficiency '
       'bonus + Wisdom modifier; spell attack = proficiency bonus + Wisdom '
       'modifier. A holy symbol can be your focus. You can cast a prepared '
       'cleric spell as a ritual if it has the ritual tag.',
       '',
       'Cantrips known: 3; 4 at 4th, 5 at 10th.',
       'Prepared spells: Wisdom modifier + cleric level (minimum 1), chosen '
       'from the whole cleric list after each long rest.',
       '',
       'Spell slots (1st/2nd/.../9th), regained on a long rest:',
       '1: 2 | 2: 3 | 3: 4/2 | 4: 4/3 | 5: 4/3/2 | 6: 4/3/3 | 7: 4/3/3/1 | '
       '8: 4/3/3/2 | 9: 4/3/3/3/1 | 10: 4/3/3/3/2 | 11-12: 4/3/3/3/2/1 | '
       '13-14: +1 7th | 15-16: +1 8th | 17: +1 9th | 18: 5th becomes 3 | '
       '19: 6th becomes 2 | 20: 7th becomes 2')),
      (null, 2, 'Channel Divinity', concat_ws(E'\n',
       'You can channel divine energy for an effect: Turn Undead, or your '
       'domain''s option(s). Uses: 1 per short or long rest; 2 at 6th, 3 at '
       '18th. A save uses your spell save DC.',
       '',
       'Turn Undead: action. Each undead within 30 feet that can see or hear '
       'you makes a Wisdom save. On a failure it is turned for 1 minute or '
       'until it takes damage: it must spend its turns moving away from you, '
       'can''t take reactions, and can only Dash or try to escape.')),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 5, 'Destroy Undead',
       'When an undead fails its save against your Turn Undead, it is '
       'destroyed outright if its challenge rating is 1/2 or lower. The cap '
       'rises to CR 1 at 8th, 2 at 11th, 3 at 14th and 4 at 17th level.'),
      (null, 10, 'Divine Intervention',
       'Action: roll percentile dice. If you roll your cleric level or lower, '
       'your deity intervenes (the DM picks the effect; a cleric spell or domain '
       'spell is a good guide). On a success you can''t try again for 7 days; '
       'otherwise after a long rest. At 20th level it succeeds automatically.'),

      -- ---- Knowledge Domain -----------------------------------------------
      (v_knowledge, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: command, '
       'identify. 3rd: augury, suggestion. 5th: nondetection, speak with dead. '
       '7th: arcane eye, confusion. 9th: legend lore, scrying.'),
      (v_knowledge, 1, 'Blessings of Knowledge',
       'Learn two languages. Gain proficiency in two of Arcana, History, '
       'Nature or Religion, with your proficiency bonus doubled for them.'),
      (v_knowledge, 2, 'Channel Divinity: Knowledge of the Ages',
       'Action: choose a skill or tool. You are proficient with it for 10 '
       'minutes.'),
      (v_knowledge, 6, 'Channel Divinity: Read Thoughts',
       'Action: a creature within 60 feet makes a Wisdom save. On a failure '
       'you read its surface thoughts for 1 minute while it stays within 60 '
       'feet. During that time you can use an action to end the effect and cast '
       'suggestion on it without a slot; it fails the save automatically.'),
      (v_knowledge, 8, 'Potent Spellcasting',
       'Add your Wisdom modifier to the damage of any cleric cantrip.'),
      (v_knowledge, 17, 'Visions of the Past',
       'Meditate for a minute, then over up to as many minutes as your Wisdom '
       'score, see visions of an object you hold (its recent owners) or of your '
       'surroundings (events there). Once per short or long rest.'),

      -- ---- Life Domain ----------------------------------------------------
      (v_life, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: bless, cure '
       'wounds. 3rd: lesser restoration, spiritual weapon. 5th: beacon of hope, '
       'revivify. 7th: death ward, guardian of faith. 9th: mass cure wounds, '
       'raise dead.'),
      (v_life, 1, 'Bonus Proficiency',
       'You gain proficiency with heavy armour.'),
      (v_life, 1, 'Disciple of Life',
       'When a spell of 1st level or higher restores hit points, the target '
       'regains an extra 2 + the spell''s level.'),
      (v_life, 2, 'Channel Divinity: Preserve Life',
       'Action: share out hit points equal to five times your cleric level among '
       'creatures within 30 feet. None can be raised above half its hit point '
       'maximum. No effect on undead or constructs.'),
      (v_life, 6, 'Blessed Healer',
       'When a spell of 1st level or higher heals someone other than you, you '
       'also regain 2 + the spell''s level.'),
      (v_life, 8, 'Divine Strike',
       'Once on each of your turns, a weapon hit deals an extra 1d8 radiant '
       'damage; 2d8 at 14th level.'),
      (v_life, 17, 'Supreme Healing',
       'When you would roll dice to restore hit points with a spell, use the '
       'highest possible number on each die instead.'),

      -- ---- Light Domain ---------------------------------------------------
      (v_light, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: burning hands, '
       'faerie fire. 3rd: flaming sphere, scorching ray. 5th: daylight, '
       'fireball. 7th: guardian of faith, wall of fire. 9th: flame strike, '
       'scrying.'),
      (v_light, 1, 'Bonus Cantrip',
       'You learn the light cantrip if you don''t already know it.'),
      (v_light, 1, 'Warding Flare',
       'Reaction: when a creature you can see within 30 feet attacks you, give '
       'the attack disadvantage. No effect if it can''t be blinded. Uses equal '
       'to your Wisdom modifier (minimum 1), regained on a long rest.'),
      (v_light, 2, 'Channel Divinity: Radiance of the Dawn',
       'Action: dispel magical darkness within 30 feet, and each hostile '
       'creature within 30 feet makes a Constitution save: 2d10 + cleric level '
       'radiant damage, half on a success. Total cover protects.'),
      (v_light, 6, 'Improved Flare',
       'You can use Warding Flare when a creature attacks an ally within 30 '
       'feet of you, not just you.'),
      (v_light, 8, 'Potent Spellcasting',
       'Add your Wisdom modifier to the damage of any cleric cantrip.'),
      (v_light, 17, 'Corona of Light',
       'Action: for 1 minute you shed bright light for 60 feet and dim light 30 '
       'feet beyond. Enemies in the bright light have disadvantage on saves '
       'against spells that deal fire or radiant damage. End it as an action.'),

      -- ---- Nature Domain --------------------------------------------------
      (v_nature, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: animal '
       'friendship, speak with animals. 3rd: barkskin, spike growth. 5th: plant '
       'growth, wind wall. 7th: dominate beast, grasping vine. 9th: insect '
       'plague, tree stride.'),
      (v_nature, 1, 'Acolyte of Nature',
       'Learn one druid cantrip, and gain proficiency in one of Animal '
       'Handling, Nature or Survival.'),
      (v_nature, 1, 'Bonus Proficiency',
       'You gain proficiency with heavy armour.'),
      (v_nature, 2, 'Channel Divinity: Charm Animals and Plants',
       'Action: each beast or plant creature within 30 feet that can see you '
       'makes a Wisdom save or is charmed by you for 1 minute or until it takes '
       'damage. It is friendly to you and your allies while charmed.'),
      (v_nature, 6, 'Dampen Elements',
       'Reaction: when you or a creature within 30 feet takes acid, cold, fire, '
       'lightning or thunder damage, grant resistance to that instance.'),
      (v_nature, 8, 'Divine Strike',
       'Once on each of your turns, a weapon hit deals an extra 1d8 cold, fire '
       'or lightning damage (your choice); 2d8 at 14th level.'),
      (v_nature, 17, 'Master of Nature',
       'Bonus action: give verbal commands to creatures charmed by your Charm '
       'Animals and Plants; on their next turns they do as you say.'),

      -- ---- Tempest Domain -------------------------------------------------
      (v_tempest, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: fog cloud, '
       'thunderwave. 3rd: gust of wind, shatter. 5th: call lightning, sleet '
       'storm. 7th: control water, ice storm. 9th: destructive wave, insect '
       'plague.'),
      (v_tempest, 1, 'Bonus Proficiencies',
       'You gain proficiency with martial weapons and heavy armour.'),
      (v_tempest, 1, 'Wrath of the Storm',
       'Reaction: when a creature within 5 feet that you can see hits you, it '
       'makes a Dexterity save: 2d8 lightning or thunder damage (your choice), '
       'half on a success. Uses equal to your Wisdom modifier (minimum 1), '
       'regained on a long rest.'),
      (v_tempest, 2, 'Channel Divinity: Destructive Wrath',
       'When you roll lightning or thunder damage, you can deal maximum damage '
       'instead of rolling.'),
      (v_tempest, 6, 'Thunderbolt Strike',
       'When you deal lightning damage to a Large or smaller creature, you can '
       'also push it up to 10 feet away from you.'),
      (v_tempest, 8, 'Divine Strike',
       'Once on each of your turns, a weapon hit deals an extra 1d8 thunder '
       'damage; 2d8 at 14th level.'),
      (v_tempest, 17, 'Stormborn',
       'You have a flying speed equal to your walking speed while you are not '
       'underground or indoors.'),

      -- ---- Trickery Domain ------------------------------------------------
      (v_trickery, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: charm person, '
       'disguise self. 3rd: mirror image, pass without trace. 5th: blink, '
       'dispel magic. 7th: dimension door, polymorph. 9th: dominate person, '
       'modify memory.'),
      (v_trickery, 1, 'Blessing of the Trickster',
       'Action: a willing creature you touch, other than you, has advantage on '
       'Stealth checks for 1 hour or until you use this again.'),
      (v_trickery, 2, 'Channel Divinity: Invoke Duplicity',
       'Action: create an illusory copy of yourself within 30 feet for up to 1 '
       'minute (concentration). Bonus action: move it up to 30 feet, staying '
       'within 120 feet of you. You can cast spells as though you were in its '
       'space, and you have advantage on attacks against a creature when both '
       'you and the copy are within 5 feet of it.'),
      (v_trickery, 6, 'Channel Divinity: Cloak of Shadows',
       'Action: you become invisible until the end of your next turn, or until '
       'you attack or cast a spell.'),
      (v_trickery, 8, 'Divine Strike',
       'Once on each of your turns, a weapon hit deals an extra 1d8 poison '
       'damage; 2d8 at 14th level.'),
      (v_trickery, 17, 'Improved Duplicity',
       'Invoke Duplicity makes up to four copies instead of one, and the bonus '
       'action moves any number of them.'),

      -- ---- War Domain -----------------------------------------------------
      (v_war, 1, 'Domain Spells',
       'Always prepared, not counted against your total. 1st: divine favor, '
       'shield of faith. 3rd: magic weapon, spiritual weapon. 5th: crusader''s '
       'mantle, spirit guardians. 7th: freedom of movement, stoneskin. 9th: '
       'flame strike, hold monster.'),
      (v_war, 1, 'Bonus Proficiencies',
       'You gain proficiency with martial weapons and heavy armour.'),
      (v_war, 1, 'War Priest',
       'When you take the Attack action, you can make one weapon attack as a '
       'bonus action. Uses equal to your Wisdom modifier (minimum 1), regained '
       'on a long rest.'),
      (v_war, 2, 'Channel Divinity: Guided Strike',
       'When you make an attack roll, add +10 to it. Decide after seeing the '
       'roll but before the result is known.'),
      (v_war, 6, 'Channel Divinity: War God''s Blessing',
       'Reaction: when a creature within 30 feet makes an attack roll, add +10 '
       'to it. Decide after seeing the roll but before the result is known.'),
      (v_war, 8, 'Divine Strike',
       'Once on each of your turns, a weapon hit deals an extra 1d8 damage of '
       'the weapon''s type; 2d8 at 14th level.'),
      (v_war, 17, 'Avatar of Battle',
       'Resistance to bludgeoning, piercing and slashing damage from nonmagical '
       'weapons.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where subclass_id = v_knowledge),
         count(*) filter (where subclass_id = v_life),
         count(*) filter (where subclass_id = v_light),
         count(*) filter (where subclass_id = v_nature),
         count(*) filter (where subclass_id = v_tempest),
         count(*) filter (where subclass_id = v_trickery),
         count(*) filter (where subclass_id = v_war),
         count(*) filter (where choice is not null)
    into v_base, v_kn, v_li, v_lt, v_na, v_te, v_tr, v_wa, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_kn <> c_expected_kn then
    raise exception '% has % features (expected %). Rolled back.', c_knowledge, v_kn, c_expected_kn;
  elsif v_li <> c_expected_li then
    raise exception '% has % features (expected %). Rolled back.', c_life, v_li, c_expected_li;
  elsif v_lt <> c_expected_lt then
    raise exception '% has % features (expected %). Rolled back.', c_light, v_lt, c_expected_lt;
  elsif v_na <> c_expected_na then
    raise exception '% has % features (expected %). Rolled back.', c_nature, v_na, c_expected_na;
  elsif v_te <> c_expected_te then
    raise exception '% has % features (expected %). Rolled back.', c_tempest, v_te, c_expected_te;
  elsif v_tr <> c_expected_tr then
    raise exception '% has % features (expected %). Rolled back.', c_trickery, v_tr, c_expected_tr;
  elsif v_wa <> c_expected_wa then
    raise exception '% has % features (expected %). Rolled back.', c_war, v_wa, c_expected_wa;
  elsif v_choices <> 0 then
    raise exception '% % features carry a choice (expected 0). Rolled back.',
      v_choices, c_class;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 069 the Cleric''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('086');

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
    left join public.subclasses s on s.id = f.subclass_id
   where c.name = 'Cleric' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 2, 4, 5, 10]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 47 from f where subclass is not null)            as domains_47,
  (select count(*) = 7 from f where name = 'Domain Spells')           as seven_spell_lists,
  (select count(*) = 0 from f where choice is not null)               as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '086')                                            as ledger_row;

rollback;

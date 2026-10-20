-- db/088_class_features_monk.sql
--
-- The Monk's base-class features (levels 1-20) and its three PHB Monastic
-- Traditions: Open Hand, Shadow and Four Elements. 27 rows. RUN 087 FIRST
-- (ledger order only).
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision ("Focus
-- points", Heightened Focus); this is ki.
--
-- 084's shape: one file per class, base + PHB subclass rows. 081's rule: one
-- row per named feature at its first level, later steps in the text (Martial
-- Arts die, Unarmored Movement's speed).
--
-- Way of the Four Elements is one row: the PHB gives it a single feature,
-- Disciple of the Elements, that grows at 6th, 11th and 17th. Its seventeen
-- disciplines are listed in the text with their ki cost and minimum level;
-- the picks have nowhere to go yet (no `choice`, see KNOWN_ISSUES).
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
  c_class         constant text := 'Monk';
  c_open_hand     constant text := 'Way of the Open Hand';
  c_shadow        constant text := 'Way of Shadow';
  c_elements      constant text := 'Way of the Four Elements';
  c_expected_base constant int  := 18;
  c_expected_oh   constant int  := 4;
  c_expected_sh   constant int  := 4;
  c_expected_el   constant int  := 1;

  v_seeking   text;

  v_class     uuid;
  v_open_hand uuid;
  v_shadow    uuid;
  v_elements  uuid;
  v_base int; v_oh int; v_sh int; v_el int;
  v_choices   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_open_hand;
  select id into strict v_open_hand from public.subclasses
  where class_id = v_class and name = c_open_hand and campaign_id is null;

  v_seeking := 'subclass ' || c_shadow;
  select id into strict v_shadow from public.subclasses
  where class_id = v_class and name = c_shadow and campaign_id is null;

  v_seeking := 'subclass ' || c_elements;
  select id into strict v_elements from public.subclasses
  where class_id = v_class and name = c_elements and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (null::uuid, 1, 'Unarmored Defense',
       'With no armour and no shield, your AC is 10 + Dexterity modifier + '
       'Wisdom modifier.'),
      (null, 1, 'Martial Arts', concat_ws(E'\n',
       'While unarmed or wielding only monk weapons (shortswords and simple '
       'melee weapons without the two-handed or heavy property), with no armour '
       'or shield:',
       '- Use Dexterity instead of Strength for attack and damage rolls.',
       '- Roll your martial arts die in place of the normal damage: d4; d6 at '
       '5th, d8 at 11th, d10 at 17th.',
       '- When you take the Attack action with these, you can make one unarmed '
       'strike as a bonus action.')),
      (null, 2, 'Ki', concat_ws(E'\n',
       'You have ki points equal to your monk level, regained on a short or '
       'long rest. Ki save DC = 8 + proficiency bonus + Wisdom modifier.',
       '- Flurry of Blows: after the Attack action, spend 1 ki to make two '
       'unarmed strikes as a bonus action.',
       '- Patient Defense: spend 1 ki to Dodge as a bonus action.',
       '- Step of the Wind: spend 1 ki to Disengage or Dash as a bonus action; '
       'your jump distance doubles for the turn.')),
      (null, 2, 'Unarmored Movement',
       'With no armour or shield, your speed increases by 10 feet; 15 at 6th, '
       '20 at 10th, 25 at 14th, 30 at 18th. From 9th level you can move along '
       'vertical surfaces and across liquids on your turn without falling.'),
      (null, 3, 'Deflect Missiles',
       'Reaction: when a ranged weapon attack hits you, reduce the damage by '
       '1d10 + Dexterity modifier + monk level. If that makes it 0 and you have '
       'a hand free, you catch the missile, and can spend 1 ki to throw it back '
       'at once (range 20/60, proficient, counts as a monk weapon, martial arts '
       'die for damage).'),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 4, 'Slow Fall',
       'Reaction: when you fall, reduce the falling damage by five times your '
       'monk level.'),
      (null, 5, 'Extra Attack',
       'You attack twice when you take the Attack action on your turn.'),
      (null, 5, 'Stunning Strike',
       'When you hit with a melee weapon attack, spend 1 ki: the target makes a '
       'Constitution save or is stunned until the end of your next turn.'),
      (null, 6, 'Ki-Empowered Strikes',
       'Your unarmed strikes count as magical for overcoming resistance and '
       'immunity to nonmagical damage.'),
      (null, 7, 'Evasion',
       'When an effect lets you make a Dexterity save for half damage, you take '
       'none on a success and half on a failure.'),
      (null, 7, 'Stillness of Mind',
       'Action: end one effect on yourself that is making you charmed or '
       'frightened.'),
      (null, 10, 'Purity of Body',
       'You are immune to disease and poison.'),
      (null, 13, 'Tongue of the Sun and Moon',
       'You understand all spoken languages, and any creature that knows a '
       'language understands what you say.'),
      (null, 14, 'Diamond Soul',
       'You are proficient in all saving throws. When you fail one, you can '
       'spend 1 ki to reroll it and must use the new roll.'),
      (null, 15, 'Timeless Body',
       'You suffer none of the frailty of old age, can''t be aged magically, '
       'and no longer need food or water.'),
      (null, 18, 'Empty Body',
       'Action, 4 ki: become invisible for 1 minute and gain resistance to all '
       'damage but force damage. Action, 8 ki: cast astral projection without '
       'material components (only yourself).'),
      (null, 20, 'Perfect Self',
       'When you roll initiative with no ki left, you regain 4 ki.'),

      -- ---- Way of the Open Hand -------------------------------------------
      (v_open_hand, 3, 'Open Hand Technique',
       'When you hit with a Flurry of Blows strike, you can add one effect: the '
       'target makes a Dexterity save or is knocked prone; or a Strength save '
       'or is pushed up to 15 feet away; or it can''t take reactions until the '
       'end of your next turn.'),
      (v_open_hand, 6, 'Wholeness of Body',
       'Action: regain hit points equal to three times your monk level. Once '
       'per long rest.'),
      (v_open_hand, 11, 'Tranquility',
       'At the end of a long rest you gain the effect of sanctuary until your '
       'next long rest (save DC 8 + Wisdom modifier + proficiency bonus). It '
       'ends early as the spell does.'),
      (v_open_hand, 17, 'Quivering Palm',
       'When you hit with an unarmed strike, spend 3 ki to set up vibrations '
       'lasting a number of days equal to your monk level. Later, as an action, '
       'end them (on the same plane): the target makes a Constitution save, '
       'dropping to 0 hit points on a failure or taking 10d10 necrotic damage '
       'on a success. One creature at a time.'),

      -- ---- Way of Shadow --------------------------------------------------
      (v_shadow, 3, 'Shadow Arts',
       'Spend 2 ki to cast darkness, darkvision, pass without trace or silence '
       'without material components. You also learn minor illusion if you '
       'don''t know it.'),
      (v_shadow, 6, 'Shadow Step',
       'Bonus action: when you are in dim light or darkness, teleport up to 60 '
       'feet to a space you can see that is also in dim light or darkness. You '
       'have advantage on the first melee attack you make before the end of '
       'the turn.'),
      (v_shadow, 11, 'Cloak of Shadows',
       'Action: while in dim light or darkness, become invisible until you '
       'attack, cast a spell, or enter bright light.'),
      (v_shadow, 17, 'Opportunist',
       'Reaction: when a creature within 5 feet of you is hit by an attack from '
       'someone else, make a melee attack against it.'),

      -- ---- Way of the Four Elements ---------------------------------------
      (v_elements, 3, 'Disciple of the Elements', concat_ws(E'\n',
       'You know Elemental Attunement and one discipline at 3rd level, and one '
       'more at 6th, 11th and 17th. Each time you learn one you can swap one '
       'you know. Some disciplines cast a spell: they need no material '
       'components, use your ki save DC, and can be boosted by spending extra '
       'ki (1 per spell level). Most ki for one discipline: 2 at 3rd, 3 at '
       '5th, 4 at 9th, 5 at 13th, 6 at 17th.',
       '',
       'Any level:',
       '- Elemental Attunement (free): minor elemental tricks within 30 feet, '
       'e.g. light or snuff a candle, chill or warm something.',
       '- Fangs of the Fire Snake (1 ki): unarmed strikes this turn reach 10 '
       'feet and deal fire damage; +1 ki adds 1d10 fire on a hit.',
       '- Fist of Four Thunders (2 ki): cast thunderwave.',
       '- Fist of Unbroken Air (2 ki): a creature within 30 feet makes a '
       'Strength save or takes 3d10 bludgeoning (+1d10 per extra ki), is '
       'pushed up to 20 feet and knocked prone. Half damage only, on a success.',
       '- Rush of the Gale Spirits (2 ki): cast gust of wind.',
       '- Shape the Flowing River (1 ki): shape ice and water in a 30-foot cube '
       'within 120 feet.',
       '- Sweeping Cinder Strike (2 ki): cast burning hands.',
       '- Water Whip (2 ki): a creature within 30 feet makes a Dexterity save '
       'or takes 3d10 bludgeoning (+1d10 per extra ki) and is pulled 25 feet '
       'closer or knocked prone. Half damage only, on a success.',
       '',
       '6th level and up:',
       '- Clench of the North Wind (3 ki): cast hold person.',
       '- Gong of the Summit (3 ki): cast shatter.',
       '',
       '11th level and up:',
       '- Eternal Mountain Defense (5 ki): cast stoneskin on yourself.',
       '- Flames of the Phoenix (4 ki): cast fireball.',
       '- Mist Stance (4 ki): cast gaseous form on yourself.',
       '- Ride the Wind (4 ki): cast fly on yourself.',
       '',
       '17th level and up:',
       '- Breath of Winter (6 ki): cast cone of cold.',
       '- River of Hungry Flame (5 ki): cast wall of fire.',
       '- Wave of Rolling Earth (6 ki): cast wall of stone.'))
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where subclass_id = v_open_hand),
         count(*) filter (where subclass_id = v_shadow),
         count(*) filter (where subclass_id = v_elements),
         count(*) filter (where choice is not null)
    into v_base, v_oh, v_sh, v_el, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_oh <> c_expected_oh then
    raise exception '% has % features (expected %). Rolled back.', c_open_hand, v_oh, c_expected_oh;
  elsif v_sh <> c_expected_sh then
    raise exception '% has % features (expected %). Rolled back.', c_shadow, v_sh, c_expected_sh;
  elsif v_el <> c_expected_el then
    raise exception '% has % features (expected %). Rolled back.', c_elements, v_el, c_expected_el;
  elsif v_choices <> 0 then
    raise exception '% % features carry a choice (expected 0). Rolled back.',
      v_choices, c_class;
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

insert into public.schema_migrations (version) values ('088');

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
   where c.name = 'Monk' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 7, 7, 10, 13, 14, 15, 18, 20]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 4 from f where subclass = 'Way of the Open Hand')      as open_hand_4,
  (select count(*) = 4 from f where subclass = 'Way of Shadow')             as shadow_4,
  (select count(*) = 1 from f where subclass = 'Way of the Four Elements')  as elements_1,
  (select count(*) = 0 from f where choice is not null)               as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '088')                                            as ledger_row;

rollback;

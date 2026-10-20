-- db/094_class_features_wizard.sql
--
-- The Wizard's base-class features (levels 1-20) and its eight PHB Arcane
-- Traditions (the schools of magic). 45 rows. RUN 093 FIRST (ledger order
-- only). The last of 084-094.
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision: the
-- tradition is chosen at 2nd level, and every school has a Savant feature.
--
-- 084's shape: one file per class, base + PHB subclass rows. 081's rule: one
-- row per named feature at its first level, later steps in the text
-- (Portent's third die at 14th).
--
-- Each school's Savant feature is named for the school ("Evocation Savant"),
-- as the PHB does, so the eight are distinct rows rather than one shared name.
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
  c_class         constant text := 'Wizard';
  c_abjuration    constant text := 'School of Abjuration';
  c_conjuration   constant text := 'School of Conjuration';
  c_divination    constant text := 'School of Divination';
  c_enchantment   constant text := 'School of Enchantment';
  c_evocation     constant text := 'School of Evocation';
  c_illusion      constant text := 'School of Illusion';
  c_necromancy    constant text := 'School of Necromancy';
  c_transmutation constant text := 'School of Transmutation';
  c_expected_base constant int  := 5;
  -- Every PHB school has exactly five: Savant, then 2nd/6th/10th/14th.
  c_expected_each constant int  := 5;

  v_seeking text;

  v_class   uuid;
  v_ab uuid; v_co uuid; v_di uuid; v_en uuid;
  v_ev uuid; v_il uuid; v_ne uuid; v_tr uuid;
  v_base    int;
  v_short   text;
  v_choices int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_abjuration;
  select id into strict v_ab from public.subclasses
  where class_id = v_class and name = c_abjuration and campaign_id is null;

  v_seeking := 'subclass ' || c_conjuration;
  select id into strict v_co from public.subclasses
  where class_id = v_class and name = c_conjuration and campaign_id is null;

  v_seeking := 'subclass ' || c_divination;
  select id into strict v_di from public.subclasses
  where class_id = v_class and name = c_divination and campaign_id is null;

  v_seeking := 'subclass ' || c_enchantment;
  select id into strict v_en from public.subclasses
  where class_id = v_class and name = c_enchantment and campaign_id is null;

  v_seeking := 'subclass ' || c_evocation;
  select id into strict v_ev from public.subclasses
  where class_id = v_class and name = c_evocation and campaign_id is null;

  v_seeking := 'subclass ' || c_illusion;
  select id into strict v_il from public.subclasses
  where class_id = v_class and name = c_illusion and campaign_id is null;

  v_seeking := 'subclass ' || c_necromancy;
  select id into strict v_ne from public.subclasses
  where class_id = v_class and name = c_necromancy and campaign_id is null;

  v_seeking := 'subclass ' || c_transmutation;
  select id into strict v_tr from public.subclasses
  where class_id = v_class and name = c_transmutation and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (null::uuid, 1, 'Spellcasting', concat_ws(E'\n',
       'Intelligence is your spellcasting ability. Spell save DC = 8 + '
       'proficiency bonus + Intelligence modifier; spell attack = proficiency '
       'bonus + Intelligence modifier. An arcane focus can be your focus.',
       '',
       'Cantrips known: 3; 4 at 4th, 5 at 10th.',
       'Spellbook: six 1st-level wizard spells to start, plus two of your '
       'choice each wizard level. Copying a spell you find costs 2 hours and 50 '
       'gp per spell level.',
       'Prepared spells: Intelligence modifier + wizard level (minimum 1), from '
       'your spellbook, after each long rest. Rituals in your book can be cast '
       'as rituals without preparing them.',
       '',
       'Spell slots (1st/2nd/.../9th), regained on a long rest:',
       '1: 2 | 2: 3 | 3: 4/2 | 4: 4/3 | 5: 4/3/2 | 6: 4/3/3 | 7: 4/3/3/1 | '
       '8: 4/3/3/2 | 9: 4/3/3/3/1 | 10: 4/3/3/3/2 | 11-12: 4/3/3/3/2/1 | '
       '13-14: +1 7th | 15-16: +1 8th | 17: +1 9th | 18: 5th becomes 3 | '
       '19: 6th becomes 2 | 20: 7th becomes 2')),
      (null, 1, 'Arcane Recovery',
       'Once per day, during a short rest, recover expended spell slots whose '
       'levels add up to no more than half your wizard level (round up). None '
       'can be 6th level or higher.'),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 18, 'Spell Mastery',
       'Choose a 1st-level and a 2nd-level spell from your spellbook. While '
       'prepared, you can cast each at its lowest level without a slot. Casting '
       'them higher uses a slot as normal. Swap them with 8 hours of study.'),
      (null, 20, 'Signature Spells',
       'Choose two 3rd-level spells from your spellbook. They are always '
       'prepared and don''t count against your total, and you can cast each '
       'once at 3rd level without a slot per short or long rest.'),

      -- ---- School of Abjuration -------------------------------------------
      (v_ab, 2, 'Abjuration Savant',
       'Copying an abjuration spell into your spellbook takes half the gold '
       'and time.'),
      (v_ab, 2, 'Arcane Ward',
       'When you cast an abjuration spell of 1st level or higher, you can '
       'create a ward on yourself (once per long rest) with hit points equal '
       'to twice your wizard level + Intelligence modifier. It takes damage '
       'before you do. Each later abjuration spell of 1st level or higher '
       'restores twice the spell''s level in ward hit points.'),
      (v_ab, 6, 'Projected Ward',
       'Reaction: when a creature you can see within 30 feet takes damage, your '
       'Arcane Ward absorbs it instead, as if you had taken it.'),
      (v_ab, 10, 'Improved Abjuration',
       'When a spell you cast has you make an ability check (such as '
       'counterspell or dispel magic), add your proficiency bonus.'),
      (v_ab, 14, 'Spell Resistance',
       'Advantage on saving throws against spells, and resistance to damage '
       'from spells.'),

      -- ---- School of Conjuration ------------------------------------------
      (v_co, 2, 'Conjuration Savant',
       'Copying a conjuration spell into your spellbook takes half the gold '
       'and time.'),
      (v_co, 2, 'Minor Conjuration',
       'Action: conjure a nonmagical object you have seen, in your hand or on '
       'the ground within 10 feet. At most 3 feet on a side and 10 pounds. It '
       'glows faintly and lasts 1 hour, until it takes damage, or until you use '
       'this again.'),
      (v_co, 6, 'Benign Transposition',
       'Action: teleport up to 30 feet to a space you can see, or swap places '
       'with a willing Small or Medium creature there. Usable again after a '
       'long rest or after you cast a conjuration spell of 1st level or higher.'),
      (v_co, 10, 'Focused Conjuration',
       'Taking damage can''t break your concentration on a conjuration spell.'),
      (v_co, 14, 'Durable Summons',
       'Any creature you summon or create with a conjuration spell has 30 '
       'temporary hit points.'),

      -- ---- School of Divination -------------------------------------------
      (v_di, 2, 'Divination Savant',
       'Copying a divination spell into your spellbook takes half the gold and '
       'time.'),
      (v_di, 2, 'Portent',
       'After a long rest, roll two d20s and record them. You can replace any '
       'attack roll, saving throw or ability check made by you or a creature '
       'you can see with one of them, before the roll. Once per turn; each '
       'roll can be used once. Three dice from 14th level (Greater Portent).'),
      (v_di, 6, 'Expert Divination',
       'When you cast a divination spell of 2nd level or higher with a slot, '
       'regain one expended slot of a lower level than the spell, up to 5th.'),
      (v_di, 10, 'The Third Eye',
       'Action: gain one of these until you are incapacitated or take a short '
       'or long rest: darkvision 60 feet; see into the Ethereal Plane 60 feet; '
       'read any language; or see invisible creatures and objects within 10 '
       'feet. Once per short or long rest.'),
      (v_di, 14, 'Greater Portent',
       'You roll three d20s for Portent instead of two.'),

      -- ---- School of Enchantment ------------------------------------------
      (v_en, 2, 'Enchantment Savant',
       'Copying an enchantment spell into your spellbook takes half the gold '
       'and time.'),
      (v_en, 2, 'Hypnotic Gaze',
       'Action: a creature within 5 feet that can see or hear you makes a '
       'Wisdom save or is charmed until the end of your next turn: speed 0, '
       'incapacitated and dazed. You can spend your action each turn to keep '
       'it going. It ends if you move more than 5 feet away, it can''t see or '
       'hear you, or it takes damage. Once it ends or the save succeeds, you '
       'can''t use it on that creature again until a long rest.'),
      (v_en, 6, 'Instinctive Charm',
       'Reaction: when a creature you can see within 30 feet attacks you, it '
       'makes a Wisdom save or must attack the creature closest to it instead '
       '(not you or itself). Decide before knowing if the attack hits. On a '
       'success, that creature is immune for 24 hours. No effect on creatures '
       'that can''t be charmed.'),
      (v_en, 10, 'Split Enchantment',
       'When you cast an enchantment spell of 1st level or higher that targets '
       'only one creature, you can have it target a second.'),
      (v_en, 14, 'Alter Memories',
       'When you charm creatures with an enchantment spell, one of them can be '
       'left unaware it was charmed. Before the spell ends, you can also use an '
       'action to make that creature make an Intelligence save or forget up to '
       '1 + your Charisma modifier hours (minimum 1) of the time it was '
       'charmed.'),

      -- ---- School of Evocation --------------------------------------------
      (v_ev, 2, 'Evocation Savant',
       'Copying an evocation spell into your spellbook takes half the gold and '
       'time.'),
      (v_ev, 2, 'Sculpt Spells',
       'When you cast an evocation spell that affects creatures you can see, '
       'choose up to 1 + the spell''s level of them. They automatically succeed '
       'on its save and take no damage if they would take half on a success.'),
      (v_ev, 6, 'Potent Cantrip',
       'A creature that succeeds on a save against your damaging cantrip still '
       'takes half the damage, but none of its other effects.'),
      (v_ev, 10, 'Empowered Evocation',
       'Add your Intelligence modifier to one damage roll of any wizard '
       'evocation spell you cast.'),
      (v_ev, 14, 'Overchannel',
       'When you cast a damaging wizard spell of 1st to 5th level, you can deal '
       'maximum damage with it. The first use per long rest is free; each use '
       'after that deals you 2d12 necrotic damage per spell level, +1d12 per '
       'level for each further use, ignoring resistance and immunity.'),

      -- ---- School of Illusion ---------------------------------------------
      (v_il, 2, 'Illusion Savant',
       'Copying an illusion spell into your spellbook takes half the gold and '
       'time.'),
      (v_il, 2, 'Improved Minor Illusion',
       'You learn minor illusion if you don''t know it (it doesn''t count '
       'against your cantrips), and one casting can make both a sound and an '
       'image.'),
      (v_il, 6, 'Malleable Illusions',
       'When you cast an illusion spell lasting 1 minute or longer, you can use '
       'an action to change it (within the spell''s limits) while you can see '
       'it.'),
      (v_il, 10, 'Illusory Self',
       'Reaction: when a creature attacks you, an illusory double appears and '
       'the attack misses automatically. Once per short or long rest.'),
      (v_il, 14, 'Illusory Reality',
       'When you cast an illusion spell of 1st level or higher, bonus action: '
       'one inanimate, nonmagical object in the illusion becomes real for 1 '
       'minute. It can''t deal damage or directly harm anyone.'),

      -- ---- School of Necromancy -------------------------------------------
      (v_ne, 2, 'Necromancy Savant',
       'Copying a necromancy spell into your spellbook takes half the gold and '
       'time.'),
      (v_ne, 2, 'Grim Harvest',
       'Once per turn, when a spell of 1st level or higher kills one or more '
       'creatures, regain hit points equal to twice the spell''s level, or '
       'three times if it is necromancy. Not for constructs or undead.'),
      (v_ne, 6, 'Undead Thralls',
       'Add animate dead to your spellbook if it isn''t there. When you cast '
       'it, you can raise one more corpse. Undead you create with necromancy '
       'gain hit points equal to your wizard level, and add your proficiency '
       'bonus to weapon damage.'),
      (v_ne, 10, 'Inured to Undeath',
       'Resistance to necrotic damage, and your hit point maximum can''t be '
       'reduced.'),
      (v_ne, 14, 'Command Undead',
       'Action: an undead within 60 feet makes a Charisma save. On a failure '
       'it becomes friendly and obeys you until you use this again. Undead '
       'with Intelligence 8 or higher save with advantage; 12 or higher repeat '
       'the save every hour.'),

      -- ---- School of Transmutation ----------------------------------------
      (v_tr, 2, 'Transmutation Savant',
       'Copying a transmutation spell into your spellbook takes half the gold '
       'and time.'),
      (v_tr, 2, 'Minor Alchemy',
       'Spend 10 minutes per cubic foot to turn an object of wood, stone (not '
       'gemstone), iron, copper or silver into another of those materials. It '
       'reverts after 1 hour or if you lose concentration.'),
      (v_tr, 6, 'Transmuter''s Stone',
       'Spend 8 hours to make a stone. Its holder gains one benefit you pick: '
       'darkvision 60 feet; +10 feet speed while unencumbered; proficiency in '
       'Constitution saves; or resistance to acid, cold, fire, lightning or '
       'thunder. Change it when you cast a transmutation spell of 1st level or '
       'higher. Making a new stone ends the old one.'),
      (v_tr, 10, 'Shapechanger',
       'Add polymorph to your spellbook if it isn''t there. Once per short or '
       'long rest, cast it without a slot on yourself only, turning into a '
       'beast of CR 1 or lower.'),
      (v_tr, 14, 'Master Transmuter',
       'Action: destroy your transmuter''s stone for one effect. Major '
       'transformation: over 10 minutes, turn a nonmagical object up to a '
       '5-foot cube into another of similar size, mass and no greater value. '
       'Panacea: a creature you touch is cured of curses, diseases and poisons '
       'and regains all hit points. Restore life: cast raise dead without a '
       'slot. Restore youth: a willing creature''s apparent age drops by 3d10 '
       'years (minimum 13). Make a new stone after.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where choice is not null)
    into v_base, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  -- The first school whose count is off, if any.
  select s.name into v_short
  from public.subclasses s
  where s.id in (v_ab, v_co, v_di, v_en, v_ev, v_il, v_ne, v_tr)
    and (select count(*) from public.class_features f
          where f.subclass_id = s.id and f.campaign_id is null) <> c_expected_each
  order by s.name
  limit 1;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_short is not null then
    raise exception '% doesn''t have % shared features. Rolled back.',
      v_short, c_expected_each;
  elsif v_choices <> 0 then
    raise exception '% % features carry a choice (expected 0). Rolled back.',
      v_choices, c_class;
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

insert into public.schema_migrations (version) values ('094');

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
  select s.name as subclass, s.source, f.*
    from public.class_features f
    join public.classes c on c.id = f.class_id
    left join public.subclasses s on s.id = f.subclass_id
   where c.name = 'Wizard' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 4, 18, 20]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 40 from f where source = 'phb')                  as schools_40,
  (select count(distinct subclass) = 8 from f where source = 'phb')   as eight_schools,
  (select count(*) = 8 from f where name like '% Savant')             as eight_savants,
  (select count(*) = 0 from f where choice is not null)               as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '094')                                            as ledger_row;

rollback;

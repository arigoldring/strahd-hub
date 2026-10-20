-- db/089_class_features_paladin.sql
--
-- The Paladin's base-class features (levels 1-20) and its three PHB Sacred
-- Oaths: Devotion, Ancients and Vengeance. 31 rows. RUN 083 FIRST: the
-- Fighting Style row writes 083's fighting_style_options.
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision: Divine Smite
-- is a rider on any melee hit, not a spell, and Lay on Hands is an action.
--
-- 084's shape: one file per class, base + PHB subclass rows. 081's rule: one
-- row per named feature at its first level, later steps in the text (aura
-- range 30 feet at 18th).
--
-- FIGHTING STYLE carries choice = 'fighting_style' and the Paladin's own
-- list: the four PHB styles a Paladin may take (no Archery, no Two-Weapon)
-- plus Tasha's Blessed Warrior, Blind Fighting and Interception. It is a
-- separate insert so the other 30 rows don't need two more columns of nulls.
--
-- Channel Divinity is a base row at 3rd level saying how many uses; each
-- oath's options are their own "Channel Divinity: <option>" rows, as in 086.
-- The tenets are flavour and are left to the subclass description.
--
-- Spellcasting is one row with the half-caster slot table as text.
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
  c_class         constant text := 'Paladin';
  c_devotion      constant text := 'Oath of Devotion';
  c_ancients      constant text := 'Oath of the Ancients';
  c_vengeance     constant text := 'Oath of Vengeance';
  c_style_feature constant text := 'Fighting Style';
  c_styles        constant public.fighting_style[] := array[
    'defense', 'dueling', 'great_weapon', 'protection',
    'blind_fighting', 'interception', 'blessed_warrior'
  ]::public.fighting_style[];
  c_expected_base constant int  := 13;
  c_expected_de   constant int  := 6;
  c_expected_an   constant int  := 6;
  c_expected_ve   constant int  := 6;

  v_seeking   text;

  v_class     uuid;
  v_devotion  uuid;
  v_ancients  uuid;
  v_vengeance uuid;
  v_base int; v_de int; v_an int; v_ve int;
  v_choices   int;
  v_options   public.fighting_style[];
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_devotion;
  select id into strict v_devotion from public.subclasses
  where class_id = v_class and name = c_devotion and campaign_id is null;

  v_seeking := 'subclass ' || c_ancients;
  select id into strict v_ancients from public.subclasses
  where class_id = v_class and name = c_ancients and campaign_id is null;

  v_seeking := 'subclass ' || c_vengeance;
  select id into strict v_vengeance from public.subclasses
  where class_id = v_class and name = c_vengeance and campaign_id is null;

  -- The one picker row.
  insert into public.class_features
    (class_id, level, name, choice, fighting_style_options, description)
  values
    (v_class, 2, c_style_feature, 'fighting_style', c_styles,
     'You adopt a style of fighting as your specialty. Choose one option; you '
     'can''t take the same one twice, even if you later get to choose again.');

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (null::uuid, 1, 'Divine Sense',
       'Action: until the end of your next turn, you know the location and '
       'type of any celestial, fiend or undead within 60 feet not behind total '
       'cover, and of any consecrated or desecrated place or object. Uses: 1 + '
       'Charisma modifier per long rest.'),
      (null, 1, 'Lay on Hands',
       'You have a pool of healing equal to five times your paladin level, '
       'refilled on a long rest. Action: touch a creature and restore any '
       'number of hit points from the pool, or spend 5 to cure one disease or '
       'neutralise one poison on it. No effect on undead or constructs.'),
      (null, 2, 'Spellcasting', concat_ws(E'\n',
       'Charisma is your spellcasting ability. Spell save DC = 8 + proficiency '
       'bonus + Charisma modifier; spell attack = proficiency bonus + Charisma '
       'modifier. A holy symbol can be your focus.',
       '',
       'Prepared spells: Charisma modifier + half your paladin level (round '
       'down, minimum 1), chosen from the whole paladin list after each long '
       'rest.',
       '',
       'Spell slots (1st/.../5th), regained on a long rest:',
       '2: 2 | 3-4: 3 | 5-6: 4/2 | 7-8: 4/3 | 9-10: 4/3/2 | 11-12: 4/3/3 | '
       '13-14: 4/3/3/1 | 15-16: 4/3/3/2 | 17-18: 4/3/3/3/1 | 19-20: 4/3/3/3/2')),
      (null, 2, 'Divine Smite',
       'When you hit with a melee weapon attack, you can spend a spell slot to '
       'add 2d8 radiant damage for a 1st-level slot, +1d8 per slot level above '
       '1st (maximum 5d8). +1d8 more against an undead or fiend.'),
      (null, 3, 'Divine Health',
       'You are immune to disease.'),
      (null, 3, 'Channel Divinity',
       'Your oath gives you Channel Divinity options. Uses: 1 per short or long '
       'rest. A save uses your spell save DC.'),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 5, 'Extra Attack',
       'You attack twice when you take the Attack action on your turn.'),
      (null, 6, 'Aura of Protection',
       'While you are conscious, you and friendly creatures within 10 feet add '
       'your Charisma modifier (minimum +1) to saving throws. 30 feet at 18th '
       'level.'),
      (null, 10, 'Aura of Courage',
       'While you are conscious, you and friendly creatures within 10 feet '
       'can''t be frightened. 30 feet at 18th level.'),
      (null, 11, 'Improved Divine Smite',
       'Every melee weapon hit deals an extra 1d8 radiant damage. Divine Smite '
       'adds on top.'),
      (null, 14, 'Cleansing Touch',
       'Action: end one spell on yourself or a willing creature you touch. '
       'Uses: Charisma modifier (minimum 1) per long rest.'),

      -- ---- Oath of Devotion -----------------------------------------------
      (v_devotion, 3, 'Oath Spells',
       'Always prepared, not counted against your total. 3rd: protection from '
       'evil and good, sanctuary. 5th: lesser restoration, zone of truth. 9th: '
       'beacon of hope, dispel magic. 13th: freedom of movement, guardian of '
       'faith. 17th: commune, flame strike.'),
      (v_devotion, 3, 'Channel Divinity: Sacred Weapon',
       'Action: for 1 minute your weapon adds your Charisma modifier (minimum '
       '+1) to attack rolls, counts as magical, and sheds bright light for 20 '
       'feet. Ends early if you drop the weapon or fall unconscious.'),
      (v_devotion, 3, 'Channel Divinity: Turn the Unholy',
       'Action: each fiend or undead within 30 feet that can hear you makes a '
       'Wisdom save or is turned for 1 minute or until it takes damage.'),
      (v_devotion, 7, 'Aura of Devotion',
       'While you are conscious, you and friendly creatures within 10 feet '
       'can''t be charmed. 30 feet at 18th level.'),
      (v_devotion, 15, 'Purity of Spirit',
       'You are always under the effect of protection from evil and good.'),
      (v_devotion, 20, 'Holy Nimbus',
       'Action: for 1 minute you shed bright light for 30 feet. Enemies that '
       'start their turn in it take 10 radiant damage, and you have advantage '
       'on saves against spells cast by fiends or undead. Once per long rest.'),

      -- ---- Oath of the Ancients -------------------------------------------
      (v_ancients, 3, 'Oath Spells',
       'Always prepared, not counted against your total. 3rd: ensnaring '
       'strike, speak with animals. 5th: misty step, moonbeam. 9th: plant '
       'growth, protection from energy. 13th: ice storm, stoneskin. 17th: '
       'commune with nature, tree stride.'),
      (v_ancients, 3, 'Channel Divinity: Nature''s Wrath',
       'Action: spectral vines grab a creature within 10 feet. It makes a '
       'Strength or Dexterity save (its choice) or is restrained. It repeats '
       'the save at the end of each of its turns.'),
      (v_ancients, 3, 'Channel Divinity: Turn the Faithless',
       'Action: each fey or fiend within 30 feet that can hear you makes a '
       'Wisdom save or is turned for 1 minute or until it takes damage. A '
       'creature in disguise or illusion is revealed while turned.'),
      (v_ancients, 7, 'Aura of Warding',
       'You and friendly creatures within 10 feet have resistance to damage '
       'from spells. 30 feet at 18th level.'),
      (v_ancients, 15, 'Undying Sentinel',
       'When you drop to 0 hit points and aren''t killed outright, you drop to '
       '1 instead (once per long rest). You also suffer no drawbacks of old age '
       'and can''t be aged magically.'),
      (v_ancients, 20, 'Elder Champion',
       'Action: for 1 minute, regain 10 hit points at the start of each of your '
       'turns, cast paladin spells with a 1-action casting time as a bonus '
       'action, and enemies within 10 feet have disadvantage on saves against '
       'your paladin spells and Channel Divinity. Once per long rest.'),

      -- ---- Oath of Vengeance ----------------------------------------------
      (v_vengeance, 3, 'Oath Spells',
       'Always prepared, not counted against your total. 3rd: bane, hunter''s '
       'mark. 5th: hold person, misty step. 9th: haste, protection from energy. '
       '13th: banishment, dimension door. 17th: hold monster, scrying.'),
      (v_vengeance, 3, 'Channel Divinity: Abjure Enemy',
       'Action: a creature within 60 feet that you can see makes a Wisdom save '
       '(fiends and undead with disadvantage). On a failure it is frightened '
       'for 1 minute or until it takes damage, and its speed is 0. On a '
       'success its speed is halved for 1 minute or until it takes damage.'),
      (v_vengeance, 3, 'Channel Divinity: Vow of Enmity',
       'Bonus action: you have advantage on attack rolls against one creature '
       'within 10 feet for 1 minute, or until it drops to 0 hit points or '
       'falls unconscious.'),
      (v_vengeance, 7, 'Relentless Avenger',
       'When you hit a creature with an opportunity attack, you can move up to '
       'half your speed right away as part of the same reaction, without '
       'provoking opportunity attacks.'),
      (v_vengeance, 15, 'Soul of Vengeance',
       'When a creature under your Vow of Enmity attacks, you can use your '
       'reaction to make a melee weapon attack against it if it is in range.'),
      (v_vengeance, 20, 'Avenging Angel',
       'Action: for 1 hour you sprout wings (flying speed 60 feet) and emanate '
       'menace in a 30-foot aura. An enemy entering it or starting its turn '
       'there for the first time makes a Wisdom save or is frightened for 1 '
       'minute or until it takes damage; attacks against it have advantage. '
       'Once per long rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where subclass_id = v_devotion),
         count(*) filter (where subclass_id = v_ancients),
         count(*) filter (where subclass_id = v_vengeance),
         count(*) filter (where choice is not null)
    into v_base, v_de, v_an, v_ve, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  select fighting_style_options into strict v_options
  from public.class_features
  where class_id = v_class and subclass_id is null
    and name = c_style_feature and campaign_id is null;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_de <> c_expected_de then
    raise exception '% has % features (expected %). Rolled back.', c_devotion, v_de, c_expected_de;
  elsif v_an <> c_expected_an then
    raise exception '% has % features (expected %). Rolled back.', c_ancients, v_an, c_expected_an;
  elsif v_ve <> c_expected_ve then
    raise exception '% has % features (expected %). Rolled back.', c_vengeance, v_ve, c_expected_ve;
  elsif v_choices <> 1 then
    raise exception '% % features carry a choice (expected 1). Rolled back.',
      v_choices, c_class;
  elsif v_options is distinct from c_styles then
    raise exception '% % offers % (expected %). Rolled back.',
      c_class, c_style_feature, v_options, c_styles;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 073 the Paladin''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('089');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the rows, the picker's list and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

with f as (
  select s.name as subclass, f.*
    from public.class_features f
    join public.classes c on c.id = f.class_id
    left join public.subclasses s on s.id = f.subclass_id
   where c.name = 'Paladin' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 2, 2, 2, 3, 3, 4, 5, 6, 10, 11, 14]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 6 from f where subclass = 'Oath of Devotion')    as devotion_6,
  (select count(*) = 6 from f where subclass = 'Oath of the Ancients') as ancients_6,
  (select count(*) = 6 from f where subclass = 'Oath of Vengeance')   as vengeance_6,
  (select cardinality(fighting_style_options) = 7
      and 'blessed_warrior' = any(fighting_style_options)
      and not ('archery' = any(fighting_style_options))
     from f where choice = 'fighting_style')                          as styles_7,
  (select count(*) = 1 from public.schema_migrations
    where version = '089')                                            as ledger_row;

rollback;

-- db/090_class_features_ranger.sql
--
-- The Ranger's base-class features (levels 1-20) and its two PHB Ranger
-- Archetypes: Hunter and Beast Master. 20 rows. RUN 083 FIRST: the Fighting
-- Style row writes 083's fighting_style_options.
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision, and not
-- Tasha's optional replacements (Deft Explorer, Favored Foe, Primal
-- Awareness): those are optional class features, left out by decision.
--
-- 084's shape: one file per class, base + PHB subclass rows. 081's rule: one
-- row per named feature at its first level, later steps in the text (Favored
-- Enemy and Natural Explorer's extra picks).
--
-- FIGHTING STYLE carries choice = 'fighting_style' and the Ranger's own list:
-- the four PHB styles a Ranger may take (no Great Weapon, no Protection) plus
-- Tasha's Blind Fighting, Druidic Warrior and Thrown Weapon Fighting. A
-- separate insert, as in 089.
--
-- Favored Enemy, Natural Explorer and each Hunter feature are picks with
-- nowhere to go (no `choice`, see KNOWN_ISSUES); their options are listed in
-- the text.
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
  c_class         constant text := 'Ranger';
  c_hunter        constant text := 'Hunter';
  c_beast_master  constant text := 'Beast Master';
  c_style_feature constant text := 'Fighting Style';
  c_styles        constant public.fighting_style[] := array[
    'archery', 'defense', 'dueling', 'two_weapon',
    'blind_fighting', 'thrown_weapon', 'druidic_warrior'
  ]::public.fighting_style[];
  c_expected_base constant int  := 12;
  c_expected_hu   constant int  := 4;
  c_expected_bm   constant int  := 4;

  v_seeking      text;

  v_class        uuid;
  v_hunter       uuid;
  v_beast_master uuid;
  v_base int; v_hu int; v_bm int;
  v_choices      int;
  v_options      public.fighting_style[];
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_hunter;
  select id into strict v_hunter from public.subclasses
  where class_id = v_class and name = c_hunter and campaign_id is null;

  v_seeking := 'subclass ' || c_beast_master;
  select id into strict v_beast_master from public.subclasses
  where class_id = v_class and name = c_beast_master and campaign_id is null;

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
      (null::uuid, 1, 'Favored Enemy', concat_ws(E'\n',
       'Choose a type of favored enemy: aberrations, beasts, celestials, '
       'constructs, dragons, elementals, fey, fiends, giants, monstrosities, '
       'oozes, plants or undead; or two races of humanoid. Choose another at '
       '6th and 14th level. Note your picks.',
       '- Advantage on Wisdom (Survival) checks to track them, and on '
       'Intelligence checks to recall information about them.',
       '- Learn one language spoken by each favored enemy, if they speak one.')),
      (null, 1, 'Natural Explorer', concat_ws(E'\n',
       'Choose a favored terrain: arctic, coast, desert, forest, grassland, '
       'mountain, swamp or the Underdark. Choose another at 6th and 10th level. '
       'Note your picks.',
       '- Double your proficiency bonus on Intelligence or Wisdom checks about '
       'that terrain that use a skill you are proficient in.',
       '- Travelling for an hour or more there: difficult terrain doesn''t slow '
       'your group; you can''t get lost except by magic; you stay alert to '
       'danger while foraging, navigating or tracking; you can move stealthily '
       'at a normal pace when alone; you find twice as much food; and when '
       'tracking you learn the creatures'' number, size and how long ago they '
       'passed.')),
      (null, 2, 'Spellcasting', concat_ws(E'\n',
       'Wisdom is your spellcasting ability. Spell save DC = 8 + proficiency '
       'bonus + Wisdom modifier; spell attack = proficiency bonus + Wisdom '
       'modifier.',
       '',
       'Spells known: 2 at 2nd; 3 at 3rd, 4 at 5th, 5 at 7th, 6 at 9th, 7 at '
       '11th, 8 at 13th, 9 at 15th, 10 at 17th, 11 at 19th. On each ranger '
       'level you may swap one known spell for another.',
       '',
       'Spell slots (1st/.../5th), regained on a long rest:',
       '2: 2 | 3-4: 3 | 5-6: 4/2 | 7-8: 4/3 | 9-10: 4/3/2 | 11-12: 4/3/3 | '
       '13-14: 4/3/3/1 | 15-16: 4/3/3/2 | 17-18: 4/3/3/3/1 | 19-20: 4/3/3/3/2')),
      (null, 3, 'Primeval Awareness',
       'Action, spending a spell slot: for 1 minute per slot level, you sense '
       'whether aberrations, celestials, dragons, elementals, fey, fiends or '
       'undead are within 1 mile (6 miles in a favored terrain). You learn the '
       'types, not their number or location.'),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 5, 'Extra Attack',
       'You attack twice when you take the Attack action on your turn.'),
      (null, 8, 'Land''s Stride',
       'Nonmagical difficult terrain costs you no extra movement, and nonmagical '
       'plants don''t slow or hurt you. Advantage on saves against plants '
       'magically made to impede movement, such as entangle.'),
      (null, 10, 'Hide in Plain Sight',
       'Spend 1 minute camouflaging yourself against a natural surface you are '
       'next to: +10 to Dexterity (Stealth) checks while you stay still. '
       'Moving, or taking an action or reaction, ends it.'),
      (null, 14, 'Vanish',
       'You can Hide as a bonus action, and you can''t be tracked by nonmagical '
       'means unless you choose to leave a trail.'),
      (null, 18, 'Feral Senses',
       'Attacking a creature you can''t see doesn''t give you disadvantage, and '
       'you know where any invisible creature within 30 feet is, unless it is '
       'hidden from you or you are blinded or deafened.'),
      (null, 20, 'Foe Slayer',
       'Once on each of your turns, add your Wisdom modifier to the attack roll '
       'or the damage roll of an attack against a favored enemy.'),

      -- ---- Hunter ---------------------------------------------------------
      (v_hunter, 3, 'Hunter''s Prey', concat_ws(E'\n',
       'Choose one, and note it:',
       '- Colossus Slayer: once per turn, +1d8 damage to a weapon hit on a '
       'creature below its hit point maximum.',
       '- Giant Killer: reaction, when a Large or larger creature within 5 feet '
       'hits or misses you, attack it right after.',
       '- Horde Breaker: once per turn, when you make a weapon attack, make '
       'another against a different creature within 5 feet of the first and '
       'within range.')),
      (v_hunter, 7, 'Defensive Tactics', concat_ws(E'\n',
       'Choose one, and note it:',
       '- Escape the Horde: opportunity attacks against you have disadvantage.',
       '- Multiattack Defense: after a creature hits you, you gain +4 AC '
       'against its other attacks this turn.',
       '- Steel Will: advantage on saves against being frightened.')),
      (v_hunter, 11, 'Multiattack', concat_ws(E'\n',
       'Choose one, and note it:',
       '- Volley: action, make a ranged attack against every creature within 10 '
       'feet of a point you can see in range (ammunition for each).',
       '- Whirlwind Attack: action, make a melee attack against every creature '
       'within 5 feet of you.')),
      (v_hunter, 15, 'Superior Hunter''s Defense', concat_ws(E'\n',
       'Choose one, and note it:',
       '- Evasion: on a Dexterity save for half damage, take none on a success '
       'and half on a failure.',
       '- Stand Against the Tide: reaction, when a hostile creature misses you '
       'with a melee attack, make it repeat the attack against another '
       'creature of your choice.',
       '- Uncanny Dodge: reaction, halve the damage of an attack from an '
       'attacker you can see.')),

      -- ---- Beast Master ---------------------------------------------------
      (v_beast_master, 3, 'Ranger''s Companion',
       'A beast of Medium or smaller size and CR 1/4 or lower becomes your '
       'companion. Add your proficiency bonus to its AC, attack and damage '
       'rolls, and to saves and skills it is proficient in. Its hit point '
       'maximum is its normal one or four times your ranger level, whichever '
       'is higher. It obeys you and acts on your turn; it takes an action only '
       'when you spend yours to command it (Attack, Dash, Disengage, Dodge or '
       'Help). If it dies, you can bond a new one with 8 hours of work.'),
      (v_beast_master, 7, 'Exceptional Training',
       'When your companion doesn''t attack on your turn, you can command it as '
       'a bonus action to Dash, Disengage, Dodge or Help.'),
      (v_beast_master, 11, 'Bestial Fury',
       'When you command your companion to Attack, it can make two attacks, or '
       'use Multiattack if it has it.'),
      (v_beast_master, 15, 'Share Spells',
       'When you cast a spell targeting yourself, you can also affect your '
       'companion if it is within 30 feet.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where subclass_id = v_hunter),
         count(*) filter (where subclass_id = v_beast_master),
         count(*) filter (where choice is not null)
    into v_base, v_hu, v_bm, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  select fighting_style_options into strict v_options
  from public.class_features
  where class_id = v_class and subclass_id is null
    and name = c_style_feature and campaign_id is null;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_hu <> c_expected_hu then
    raise exception '% has % features (expected %). Rolled back.', c_hunter, v_hu, c_expected_hu;
  elsif v_bm <> c_expected_bm then
    raise exception '% has % features (expected %). Rolled back.', c_beast_master, v_bm, c_expected_bm;
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
      'No shared % found. 055 seeds classes, 074 the Ranger''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('090');

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
   where c.name = 'Ranger' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 2, 2, 3, 4, 5, 8, 10, 14, 18, 20]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 4 from f where subclass = 'Hunter')              as hunter_4,
  (select count(*) = 4 from f where subclass = 'Beast Master')        as beast_master_4,
  (select cardinality(fighting_style_options) = 7
      and 'druidic_warrior' = any(fighting_style_options)
      and not ('great_weapon' = any(fighting_style_options))
     from f where choice = 'fighting_style')                          as styles_7,
  (select count(*) = 1 from public.schema_migrations
    where version = '090')                                            as ledger_row;

rollback;

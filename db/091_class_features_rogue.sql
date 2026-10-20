-- db/091_class_features_rogue.sql
--
-- The Rogue's base-class features (levels 1-20) and its three PHB Roguish
-- Archetypes: Thief, Assassin and Arcane Trickster. 27 rows. RUN 090 FIRST
-- (ledger order only).
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision (no Cunning
-- Strike, no Weapon Mastery).
--
-- 084's shape: one file per class, base + PHB subclass rows. 081's rule: one
-- row per named feature at its first level, later steps in the text (Sneak
-- Attack's dice, Expertise's second pair). The Rogue's ASI levels include
-- 10th.
--
-- Arcane Trickster's Spellcasting is the second third-caster after 082's
-- Eldritch Knight, with the same slot table and the same "two schools, a few
-- any-school picks" rule (enchantment and illusion here). 075 already gives
-- the subclass spell_ability = 'int', which the sheet uses for DC and attack.
-- Nothing enforces the schools or the slots (KNOWN_ISSUES).
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
  c_class         constant text := 'Rogue';
  c_thief         constant text := 'Thief';
  c_assassin      constant text := 'Assassin';
  c_trickster     constant text := 'Arcane Trickster';
  c_expected_base constant int  := 12;
  c_expected_th   constant int  := 5;
  c_expected_as   constant int  := 5;
  c_expected_at   constant int  := 5;

  v_seeking   text;

  v_class     uuid;
  v_thief     uuid;
  v_assassin  uuid;
  v_trickster uuid;
  v_base int; v_th int; v_as int; v_at int;
  v_choices   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_thief;
  select id into strict v_thief from public.subclasses
  where class_id = v_class and name = c_thief and campaign_id is null;

  v_seeking := 'subclass ' || c_assassin;
  select id into strict v_assassin from public.subclasses
  where class_id = v_class and name = c_assassin and campaign_id is null;

  v_seeking := 'subclass ' || c_trickster;
  select id into strict v_trickster from public.subclasses
  where class_id = v_class and name = c_trickster and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (null::uuid, 1, 'Expertise',
       'Pick two of your skill proficiencies, or one skill and thieves'' tools: '
       'your proficiency bonus is doubled for them. Pick two more at 6th level. '
       'Mark them as expertise in your skills.'),
      (null, 1, 'Sneak Attack',
       'Once per turn, deal extra damage to one creature you hit with a finesse '
       'or ranged weapon attack, if you have advantage on the roll, or if '
       'another enemy of the target is within 5 feet of it (not incapacitated) '
       'and you don''t have disadvantage. Extra damage: 1d6 at 1st, +1d6 at '
       'every odd level (2d6 at 3rd ... 10d6 at 19th).'),
      (null, 1, 'Thieves'' Cant',
       'You know thieves'' cant, a mix of jargon and code that hides messages '
       'in ordinary talk (it takes four times as long to convey), plus secret '
       'signs and symbols for short messages.'),
      (null, 2, 'Cunning Action',
       'On each of your turns, you can Dash, Disengage or Hide as a bonus '
       'action.'),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 10th, 12th, 16th and 19th level: +2 to one ability score '
       'or +1 to two (maximum 20), or a feat if your DM allows them.'),
      (null, 5, 'Uncanny Dodge',
       'Reaction: when an attacker you can see hits you, halve the attack''s '
       'damage against you.'),
      (null, 7, 'Evasion',
       'When an effect lets you make a Dexterity save for half damage, you take '
       'none on a success and half on a failure.'),
      (null, 11, 'Reliable Talent',
       'When you make an ability check with a skill you are proficient in, '
       'treat a d20 roll of 9 or lower as a 10.'),
      (null, 14, 'Blindsense',
       'If you can hear, you know where any hidden or invisible creature within '
       '10 feet of you is.'),
      (null, 15, 'Slippery Mind',
       'You gain proficiency in Wisdom saving throws. Record it with your '
       'saves.'),
      (null, 18, 'Elusive',
       'No attack roll has advantage against you while you aren''t '
       'incapacitated.'),
      (null, 20, 'Stroke of Luck',
       'Turn a missed attack into a hit, or treat a failed ability check''s d20 '
       'as a 20. Once per short or long rest.'),

      -- ---- Thief ----------------------------------------------------------
      (v_thief, 3, 'Fast Hands',
       'Your Cunning Action bonus action can also be a Dexterity (Sleight of '
       'Hand) check, using thieves'' tools to disarm a trap or open a lock, or '
       'the Use an Object action.'),
      (v_thief, 3, 'Second-Story Work',
       'Climbing costs you no extra movement, and a running jump goes a number '
       'of feet further equal to your Dexterity modifier.'),
      (v_thief, 9, 'Supreme Sneak',
       'Advantage on Dexterity (Stealth) checks if you move no more than half '
       'your speed that turn.'),
      (v_thief, 13, 'Use Magic Device',
       'You ignore all class, race and level requirements on the use of magic '
       'items.'),
      (v_thief, 17, 'Thief''s Reflexes',
       'In the first round of combat you take two turns: one at your initiative '
       'and one at your initiative minus 10. Not if you are surprised.'),

      -- ---- Assassin -------------------------------------------------------
      (v_assassin, 3, 'Bonus Proficiencies',
       'You gain proficiency with the disguise kit and the poisoner''s kit. '
       'Record them with your tool proficiencies.'),
      (v_assassin, 3, 'Assassinate',
       'Advantage on attacks against any creature that hasn''t taken a turn yet '
       'in the combat. Any hit you score against a surprised creature is a '
       'critical hit.'),
      (v_assassin, 9, 'Infiltration Expertise',
       'Spend seven days and 25 gp to build a false identity: history, '
       'profession, documents and acquaintances. Others believe you are that '
       'person until given an obvious reason not to.'),
      (v_assassin, 13, 'Impostor',
       'After studying a person''s speech, writing and behaviour for at least '
       'three hours, you can mimic them unerringly. Casual observers can''t '
       'tell; a wary one''s Wisdom (Insight) check is opposed by your Charisma '
       '(Deception) check with advantage.'),
      (v_assassin, 17, 'Death Strike',
       'When you hit a surprised creature, it makes a Constitution save (DC 8 + '
       'Dexterity modifier + proficiency bonus). On a failure, the attack''s '
       'damage is doubled.'),

      -- ---- Arcane Trickster -----------------------------------------------
      (v_trickster, 3, 'Spellcasting', concat_ws(E'\n',
       'You cast wizard spells, with Intelligence as your spellcasting ability. '
       'Spell save DC = 8 + proficiency bonus + Intelligence modifier; spell '
       'attack = proficiency bonus + Intelligence modifier.',
       '',
       'Cantrips: mage hand plus two other wizard cantrips; a third at 10th '
       'level.',
       '',
       'Spells known: 3 at 3rd level, 4 at 4th, 5 at 7th, 6 at 8th, 7 at 10th, '
       '8 at 11th, 9 at 13th, 10 at 14th, 11 at 16th, 12 at 19th, 13 at 20th. '
       'They must be enchantment or illusion, except one of your first three '
       'and the new spell at 8th, 14th and 20th level, which can be any school. '
       'Each time you gain a rogue level you may replace one spell you know '
       'with another you have slots for; it must be enchantment or illusion '
       'unless it replaces an any-school spell.',
       '',
       'Spell slots (1st/2nd/3rd/4th), all regained on a long rest:',
       'Level 3: 2 | 4-6: 3 | 7-9: 4/2 | 10-12: 4/3 | 13-15: 4/3/2 | '
       '16-18: 4/3/3 | 19-20: 4/3/3/1')),
      (v_trickster, 3, 'Mage Hand Legerdemain',
       'Your mage hand is invisible, and with it you can stow or take an object '
       'a creature is carrying, use thieves'' tools at range, or open locks and '
       'disarm traps. Stealing unnoticed is a Dexterity (Sleight of Hand) check '
       'against the target''s Wisdom (Perception). You can control the hand as a '
       'bonus action through Cunning Action.'),
      (v_trickster, 9, 'Magical Ambush',
       'If you are hidden from a creature when you cast a spell on it, it has '
       'disadvantage on any save against that spell this turn.'),
      (v_trickster, 13, 'Versatile Trickster',
       'Bonus action: use your mage hand to distract a creature within 5 feet '
       'of the hand. You have advantage on attacks against it until the end of '
       'the turn.'),
      (v_trickster, 17, 'Spell Thief',
       'Reaction: when a creature casts a spell that targets you or includes '
       'you in its area, it makes a save with its spellcasting ability against '
       'your spell save DC. On a failure, the spell has no effect on you and, '
       'if it is 1st level or higher and of a level you can cast, you steal '
       'it: you know it for 8 hours and the caster can''t cast it for that '
       'long. Once per long rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where subclass_id = v_thief),
         count(*) filter (where subclass_id = v_assassin),
         count(*) filter (where subclass_id = v_trickster),
         count(*) filter (where choice is not null)
    into v_base, v_th, v_as, v_at, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_th <> c_expected_th then
    raise exception '% has % features (expected %). Rolled back.', c_thief, v_th, c_expected_th;
  elsif v_as <> c_expected_as then
    raise exception '% has % features (expected %). Rolled back.', c_assassin, v_as, c_expected_as;
  elsif v_at <> c_expected_at then
    raise exception '% has % features (expected %). Rolled back.', c_trickster, v_at, c_expected_at;
  elsif v_choices <> 0 then
    raise exception '% % features carry a choice (expected 0). Rolled back.',
      v_choices, c_class;
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

insert into public.schema_migrations (version) values ('091');

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
   where c.name = 'Rogue' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 1, 2, 4, 5, 7, 11, 14, 15, 18, 20]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 5 from f where subclass = 'Thief')               as thief_5,
  (select count(*) = 5 from f where subclass = 'Assassin')            as assassin_5,
  (select count(*) = 5 from f where subclass = 'Arcane Trickster')    as trickster_5,
  (select count(*) = 0 from f where choice is not null)               as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '091')                                            as ledger_row;

rollback;

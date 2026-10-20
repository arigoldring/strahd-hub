-- db/092_class_features_sorcerer.sql
--
-- The Sorcerer's base-class features (levels 1-20) and its two PHB Sorcerous
-- Origins: Draconic Bloodline and Wild Magic. 15 rows. RUN 091 FIRST (ledger
-- order only).
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision: the origin
-- is chosen at 1st level, and Metamagic arrives at 3rd.
--
-- 084's shape: one file per class, base + PHB subclass rows. 081's rule: one
-- row per named feature at its first level, later steps in the text.
--
-- Metamagic and Dragon Ancestor are picks with nowhere to go (no `choice`,
-- see KNOWN_ISSUES); their options are listed in the text. The Wild Magic
-- Surge table itself is not reproduced; the row points at the PHB.
--
-- Display only: Draconic Resilience's extra hit points and AC 13 + Dex
-- aren't applied to the sheet's numbers, and sorcery points aren't tracked.
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
  c_class         constant text := 'Sorcerer';
  c_draconic      constant text := 'Draconic Bloodline';
  c_wild          constant text := 'Wild Magic';
  c_expected_base constant int  := 5;
  c_expected_dr   constant int  := 5;
  c_expected_wm   constant int  := 5;

  v_seeking  text;

  v_class    uuid;
  v_draconic uuid;
  v_wild     uuid;
  v_base int; v_dr int; v_wm int;
  v_choices  int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_draconic;
  select id into strict v_draconic from public.subclasses
  where class_id = v_class and name = c_draconic and campaign_id is null;

  v_seeking := 'subclass ' || c_wild;
  select id into strict v_wild from public.subclasses
  where class_id = v_class and name = c_wild and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (null::uuid, 1, 'Spellcasting', concat_ws(E'\n',
       'Charisma is your spellcasting ability. Spell save DC = 8 + proficiency '
       'bonus + Charisma modifier; spell attack = proficiency bonus + Charisma '
       'modifier. An arcane focus can be your focus.',
       '',
       'Cantrips known: 4; 5 at 4th, 6 at 10th.',
       'Spells known: 2 at 1st, +1 per level to 11 at 10th; 12 at 11th, 13 at '
       '13th, 14 at 15th, 15 at 17th. On each sorcerer level you may swap one '
       'known spell for another.',
       '',
       'Spell slots (1st/2nd/.../9th), regained on a long rest:',
       '1: 2 | 2: 3 | 3: 4/2 | 4: 4/3 | 5: 4/3/2 | 6: 4/3/3 | 7: 4/3/3/1 | '
       '8: 4/3/3/2 | 9: 4/3/3/3/1 | 10: 4/3/3/3/2 | 11-12: 4/3/3/3/2/1 | '
       '13-14: +1 7th | 15-16: +1 8th | 17: +1 9th | 18: 5th becomes 3 | '
       '19: 6th becomes 2 | 20: 7th becomes 2')),
      (null, 2, 'Font of Magic', concat_ws(E'\n',
       'You have sorcery points equal to your sorcerer level, regained on a '
       'long rest.',
       '- Bonus action: turn a spell slot into sorcery points equal to its '
       'level.',
       '- Bonus action: turn sorcery points into a spell slot of up to 5th '
       'level. Cost: 1st 2, 2nd 3, 3rd 5, 4th 6, 5th 7. Slots made this way '
       'vanish on a long rest.')),
      (null, 3, 'Metamagic', concat_ws(E'\n',
       'Learn two options; one more at 10th and 17th level. Only one per spell, '
       'unless an option says otherwise. Note your picks.',
       '- Careful Spell (1): up to Charisma modifier creatures automatically '
       'succeed on the spell''s save.',
       '- Distant Spell (1): double the range, or make a touch spell reach 30 '
       'feet.',
       '- Empowered Spell (1): reroll up to Charisma modifier damage dice; can '
       'be combined with another option.',
       '- Extended Spell (1): double a duration of 1 minute or longer, to a '
       'maximum of 24 hours.',
       '- Heightened Spell (3): one target has disadvantage on its first save '
       'against the spell.',
       '- Quickened Spell (2): cast a 1-action spell as a bonus action.',
       '- Subtle Spell (1): no verbal or somatic components.',
       '- Twinned Spell (spell level, 1 for a cantrip): a spell that targets '
       'one creature and can''t target more also targets a second.')),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 20, 'Sorcerous Restoration',
       'You regain 4 expended sorcery points when you finish a short rest.'),

      -- ---- Draconic Bloodline ---------------------------------------------
      (v_draconic, 1, 'Dragon Ancestor', concat_ws(E'\n',
       'Choose a dragon ancestor and note it; it sets your damage type for '
       'later features. Black: acid. Blue: lightning. Brass: fire. Bronze: '
       'lightning. Copper: acid. Gold: fire. Green: poison. Red: fire. Silver: '
       'cold. White: cold.',
       'You speak, read and write Draconic. When you make a Charisma check with '
       'dragons, double your proficiency bonus if it applies.')),
      (v_draconic, 1, 'Draconic Resilience',
       'Your hit point maximum increases by 1 per sorcerer level. Without '
       'armour, your AC is 13 + Dexterity modifier. The sheet doesn''t apply '
       'either yet.'),
      (v_draconic, 6, 'Elemental Affinity',
       'When you cast a spell that deals your ancestry''s damage type, add your '
       'Charisma modifier to one damage roll of it. You can also spend 1 '
       'sorcery point to gain resistance to that type for 1 hour.'),
      (v_draconic, 14, 'Dragon Wings',
       'Bonus action: sprout wings and gain a flying speed equal to your '
       'current speed, until you dismiss them. Not while wearing armour not '
       'made for them.'),
      (v_draconic, 18, 'Draconic Presence',
       'Action, 5 sorcery points: for 1 minute (concentration), a 60-foot aura '
       'of awe or fear. Each hostile creature starting its turn in it makes a '
       'Wisdom save or is charmed (awe) or frightened (fear) until the aura '
       'ends. A creature that succeeds is immune for 24 hours.'),

      -- ---- Wild Magic -----------------------------------------------------
      (v_wild, 1, 'Wild Magic Surge',
       'After you cast a sorcerer spell of 1st level or higher, the DM can have '
       'you roll a d20. On a 1, roll on the Wild Magic Surge table in the PHB '
       'for a random magical effect.'),
      (v_wild, 1, 'Tides of Chaos',
       'Gain advantage on one attack roll, ability check or saving throw. Once '
       'used, it returns on a long rest, or earlier if the DM has you roll on '
       'the surge table (which they can do any time before then, after you cast '
       'a sorcerer spell of 1st level or higher).'),
      (v_wild, 6, 'Bend Luck',
       'Reaction, 2 sorcery points: when a creature you can see makes an attack '
       'roll, ability check or saving throw, roll 1d4 and add or subtract it '
       'from the roll. Decide after the roll but before any effects occur.'),
      (v_wild, 14, 'Controlled Chaos',
       'When you roll on the Wild Magic Surge table, roll twice and use either '
       'result.'),
      (v_wild, 18, 'Spell Bombardment',
       'When you roll damage for a spell and a die shows its highest number, '
       'roll that die again and add it to the damage. Once per turn.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where subclass_id = v_draconic),
         count(*) filter (where subclass_id = v_wild),
         count(*) filter (where choice is not null)
    into v_base, v_dr, v_wm, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_dr <> c_expected_dr then
    raise exception '% has % features (expected %). Rolled back.', c_draconic, v_dr, c_expected_dr;
  elsif v_wm <> c_expected_wm then
    raise exception '% has % features (expected %). Rolled back.', c_wild, v_wm, c_expected_wm;
  elsif v_choices <> 0 then
    raise exception '% % features carry a choice (expected 0). Rolled back.',
      v_choices, c_class;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 076 the Sorcerer''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('092');

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
   where c.name = 'Sorcerer' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 2, 3, 4, 20]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 5 from f where subclass = 'Draconic Bloodline')  as draconic_5,
  (select count(*) = 5 from f where subclass = 'Wild Magic')          as wild_magic_5,
  (select count(*) = 0 from f where choice is not null)               as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '092')                                            as ledger_row;

rollback;

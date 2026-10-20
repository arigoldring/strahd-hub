-- db/085_class_features_bard.sql
--
-- The Bard's base-class features (levels 1-20) and its two PHB colleges:
-- Lore and Valor. 18 rows. RUN 084 FIRST (ledger order only).
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision.
--
-- 084's shape: one file per class, base + PHB subclass rows. 081's rule: one
-- row per named feature at its first level, later steps in the text
-- (Bardic Inspiration's die, Expertise's second pair, Magical Secrets' later
-- picks).
--
-- Spellcasting is one row with the full-caster slot table as text. Slots
-- aren't tracked and the picker offers every spell (KNOWN_ISSUES).
-- Expertise and Magical Secrets are many-pick features: text only, no
-- `choice`.
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
  c_class         constant text := 'Bard';
  c_lore          constant text := 'College of Lore';
  c_valor         constant text := 'College of Valor';
  c_expected_base constant int  := 10;
  c_expected_lo   constant int  := 4;
  c_expected_va   constant int  := 4;

  v_seeking text;

  v_class   uuid;
  v_lore    uuid;
  v_valor   uuid;
  v_base    int;
  v_lo      int;
  v_va      int;
  v_choices int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_lore;
  select id into strict v_lore
  from public.subclasses
  where class_id = v_class and name = c_lore and campaign_id is null;

  v_seeking := 'subclass ' || c_valor;
  select id into strict v_valor
  from public.subclasses
  where class_id = v_class and name = c_valor and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (null::uuid, 1, 'Spellcasting', concat_ws(E'\n',
       'Charisma is your spellcasting ability. Spell save DC = 8 + proficiency '
       'bonus + Charisma modifier; spell attack = proficiency bonus + Charisma '
       'modifier. A musical instrument can be your focus. You can cast a bard '
       'spell you know as a ritual if it has the ritual tag.',
       '',
       'Cantrips known: 2; 3 at 4th, 4 at 10th.',
       'Spells known: 4 at 1st, +1 per level to 12 at 9th; 14 at 10th, 15 at '
       '11th, 16 at 13th, 18 at 14th, 19 at 15th, 20 at 17th, 22 at 18th. On '
       'each bard level you may swap one known spell for another.',
       '',
       'Spell slots (1st/2nd/.../9th), regained on a long rest:',
       '1: 2 | 2: 3 | 3: 4/2 | 4: 4/3 | 5: 4/3/2 | 6: 4/3/3 | 7: 4/3/3/1 | '
       '8: 4/3/3/2 | 9: 4/3/3/3/1 | 10: 4/3/3/3/2 | 11-12: 4/3/3/3/2/1 | '
       '13-14: +1 7th | 15-16: +1 8th | 17: +1 9th | 18: 5th becomes 3 | '
       '19: 6th becomes 2 | 20: 7th becomes 2')),
      (null, 1, 'Bardic Inspiration',
       'Bonus action: a creature other than you within 60 feet that can hear '
       'you gains an inspiration die. Within the next 10 minutes it can add the '
       'die to one ability check, attack roll or saving throw, after rolling '
       'but before the result is known. Die: d6; d8 at 5th, d10 at 10th, d12 '
       'at 15th. Uses equal to your Charisma modifier (minimum 1), regained on '
       'a long rest.'),
      (null, 2, 'Jack of All Trades',
       'Add half your proficiency bonus (round down) to any ability check that '
       'doesn''t already include your proficiency bonus.'),
      (null, 2, 'Song of Rest',
       'During a short rest, allies who hear you perform and spend hit dice '
       'regain an extra 1d6 hit points; d8 at 9th, d10 at 13th, d12 at 17th.'),
      (null, 3, 'Expertise',
       'Pick two of your skill proficiencies: your proficiency bonus is doubled '
       'for them. Pick two more at 10th level. Mark them as expertise in your '
       'skills.'),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 5, 'Font of Inspiration',
       'You regain all uses of Bardic Inspiration on a short rest as well as a '
       'long one.'),
      (null, 6, 'Countercharm',
       'Action: until the end of your next turn, you and friendly creatures '
       'within 30 feet who can hear you have advantage on saves against being '
       'frightened or charmed. Ends early if you are incapacitated or silenced, '
       'or end it voluntarily.'),
      (null, 10, 'Magical Secrets',
       'Learn two spells from any class''s list (cantrips allowed, at a level '
       'you can cast). They count as bard spells and toward your spells known. '
       'Two more at 14th and at 18th level.'),
      (null, 20, 'Superior Inspiration',
       'When you roll initiative with no Bardic Inspiration uses left, you '
       'regain one.'),

      -- ---- College of Lore ------------------------------------------------
      (v_lore, 3, 'Bonus Proficiencies',
       'You gain proficiency in three skills of your choice.'),
      (v_lore, 3, 'Cutting Words',
       'When a creature you can see within 60 feet makes an attack roll, '
       'ability check or damage roll, you can use your reaction and a Bardic '
       'Inspiration use to subtract the die from the roll. Decide after the '
       'roll but before the result is known. Creatures that can''t hear you or '
       'can''t be charmed are immune.'),
      (v_lore, 6, 'Additional Magical Secrets',
       'Learn two spells from any class''s list, at a level you can cast. They '
       'count as bard spells but not toward your spells known.'),
      (v_lore, 14, 'Peerless Skill',
       'When you make an ability check, you can spend a Bardic Inspiration use '
       'and add the die to the check, after seeing the roll.'),

      -- ---- College of Valor -----------------------------------------------
      (v_valor, 3, 'Bonus Proficiencies',
       'You gain proficiency with medium armour, shields and martial weapons.'),
      (v_valor, 3, 'Combat Inspiration',
       'A creature with your inspiration die can also add it to a weapon damage '
       'roll, or use its reaction to add it to its AC against one attack after '
       'seeing the roll.'),
      (v_valor, 6, 'Extra Attack',
       'You attack twice when you take the Attack action on your turn.'),
      (v_valor, 14, 'Battle Magic',
       'When you use your action to cast a bard spell, you can make one weapon '
       'attack as a bonus action.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where subclass_id = v_lore),
         count(*) filter (where subclass_id = v_valor),
         count(*) filter (where choice is not null)
    into v_base, v_lo, v_va, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_lo <> c_expected_lo then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_lore, v_lo, c_expected_lo;
  elsif v_va <> c_expected_va then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_valor, v_va, c_expected_va;
  elsif v_choices <> 0 then
    raise exception '% % features carry a choice (expected 0). Rolled back.',
      v_choices, c_class;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 068 the Bard''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('085');

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
   where c.name = 'Bard' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 2, 2, 3, 4, 5, 6, 10, 20]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 4 from f where subclass = 'College of Lore')     as lore_4,
  (select count(*) = 4 from f where subclass = 'College of Valor')    as valor_4,
  (select count(*) = 0 from f where choice is not null)               as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '085')                                            as ledger_row;

rollback;

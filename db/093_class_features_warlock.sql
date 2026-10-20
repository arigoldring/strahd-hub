-- db/093_class_features_warlock.sql
--
-- The Warlock's base-class features (levels 1-20) and its three PHB
-- Otherworldly Patrons: the Archfey, the Fiend and the Great Old One. 21 rows.
-- RUN 092 FIRST (ledger order only).
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision: the patron
-- is chosen at 1st level, the Pact Boon at 3rd, and invocations are the PHB's
-- list.
--
-- 084's shape: one file per class, base + PHB subclass rows. 081's rule: one
-- row per named feature at its first level, later steps in the text
-- (invocations known, Mystic Arcanum's later levels).
--
-- Pact Magic is its own row (not "Spellcasting"): few slots, all of one level,
-- back on a short rest. Eldritch Invocations and Pact Boon are picks with
-- nowhere to go (no `choice`, see KNOWN_ISSUES); all 32 PHB invocations are
-- listed in one line each, with their prerequisite.
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
  c_class         constant text := 'Warlock';
  c_archfey       constant text := 'The Archfey';
  c_fiend         constant text := 'The Fiend';
  c_old_one       constant text := 'The Great Old One';
  c_expected_base constant int  := 6;
  c_expected_af   constant int  := 5;
  c_expected_fi   constant int  := 5;
  c_expected_go   constant int  := 5;

  v_seeking text;

  v_class   uuid;
  v_archfey uuid;
  v_fiend   uuid;
  v_old_one uuid;
  v_base int; v_af int; v_fi int; v_go int;
  v_choices int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_archfey;
  select id into strict v_archfey from public.subclasses
  where class_id = v_class and name = c_archfey and campaign_id is null;

  v_seeking := 'subclass ' || c_fiend;
  select id into strict v_fiend from public.subclasses
  where class_id = v_class and name = c_fiend and campaign_id is null;

  v_seeking := 'subclass ' || c_old_one;
  select id into strict v_old_one from public.subclasses
  where class_id = v_class and name = c_old_one and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (null::uuid, 1, 'Pact Magic', concat_ws(E'\n',
       'Charisma is your spellcasting ability. Spell save DC = 8 + proficiency '
       'bonus + Charisma modifier; spell attack = proficiency bonus + Charisma '
       'modifier. An arcane focus can be your focus.',
       '',
       'Cantrips known: 2; 3 at 4th, 4 at 10th.',
       'Spells known: 2 at 1st, +1 per level to 10 at 9th; 11 at 11th, 12 at '
       '13th, 13 at 15th, 14 at 17th, 15 at 19th. On each warlock level you may '
       'swap one known spell for another.',
       '',
       'Spell slots are all the same level and come back on a short or long '
       'rest. You cast every warlock spell at that level.',
       '1: one 1st | 2: two 1st | 3-4: two 2nd | 5-6: two 3rd | 7-8: two 4th | '
       '9-10: two 5th | 11-16: three 5th | 17-20: four 5th')),
      (null, 2, 'Eldritch Invocations', concat_ws(E'\n',
       'Learn two invocations; 3 at 5th, 4 at 7th, 5 at 9th, 6 at 12th, 7 at '
       '15th, 8 at 18th. On each warlock level you may swap one. Prerequisites '
       'in brackets; "at will" means without a slot. Note your picks.',
       '- Agonizing Blast (eldritch blast): add Charisma modifier to its damage.',
       '- Armor of Shadows: mage armor on yourself at will.',
       '- Ascendant Step (9th): levitate on yourself at will.',
       '- Beast Speech: speak with animals at will.',
       '- Beguiling Influence: proficiency in Deception and Persuasion.',
       '- Bewitching Whispers (7th): compulsion once per long rest, with a slot.',
       '- Book of Ancient Secrets (Pact of the Tome): two 1st-level rituals in '
       'your book, and you can copy more you find.',
       '- Chains of Carceri (15th, Pact of the Chain): hold monster at will on a '
       'celestial, fiend or elemental; once per long rest per creature.',
       '- Devil''s Sight: see normally in darkness, magical or not, to 120 feet.',
       '- Dreadful Word (7th): confusion once per long rest, with a slot.',
       '- Eldritch Sight: detect magic at will.',
       '- Eldritch Spear (eldritch blast): its range becomes 300 feet.',
       '- Eyes of the Rune Keeper: you can read all writing.',
       '- Fiendish Vigor: false life on yourself at will, as a 1st-level spell.',
       '- Gaze of Two Minds: action, perceive through a willing humanoid''s '
       'senses until your next turn.',
       '- Lifedrinker (12th, Pact of the Blade): pact weapon hits add Charisma '
       'modifier necrotic damage.',
       '- Mask of Many Faces: disguise self at will.',
       '- Master of Myriad Forms (15th): alter self at will.',
       '- Minions of Chaos (9th): conjure elemental once per long rest, with a '
       'slot.',
       '- Mire the Mind (5th): slow once per long rest, with a slot.',
       '- Misty Visions: silent image at will.',
       '- One with Shadows (5th): in dim light or darkness, action to become '
       'invisible until you move or act.',
       '- Otherworldly Leap (9th): jump on yourself at will.',
       '- Repelling Blast (eldritch blast): a beam that hits pushes the target '
       'up to 10 feet.',
       '- Sculptor of Flesh (7th): polymorph once per long rest, with a slot.',
       '- Sign of Ill Omen (5th): bestow curse once per long rest, with a slot.',
       '- Thief of Five Fates: bane once per long rest, with a slot.',
       '- Thirsting Blade (5th, Pact of the Blade): attack twice with your pact '
       'weapon when you take the Attack action.',
       '- Visions of Distant Realms (15th): arcane eye at will.',
       '- Voice of the Chain Master (Pact of the Chain): talk telepathically '
       'with your familiar and perceive and speak through it, on the same plane.',
       '- Whispers of the Grave (9th): speak with dead at will.',
       '- Witch Sight (15th): see the true form of shapechangers and creatures '
       'hidden by illusion or transmutation within 30 feet.')),
      (null, 3, 'Pact Boon', concat_ws(E'\n',
       'Choose one, and note it:',
       '- Pact of the Chain: learn find familiar and cast it as a ritual. It can '
       'also be an imp, pseudodragon, quasit or sprite. When you take the '
       'Attack action, you can skip one attack to let the familiar attack with '
       'its reaction.',
       '- Pact of the Blade: action, create a pact weapon in your hand (any '
       'melee form). You are proficient with it and it counts as magical. You '
       'can also bond a magic weapon with a 1-hour ritual.',
       '- Pact of the Tome: a Book of Shadows with three cantrips from any '
       'class''s list, cast at will while you have it.')),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 11, 'Mystic Arcanum',
       'Choose one 6th-level warlock spell; you can cast it once per long rest '
       'without a slot. Add a 7th-level spell at 13th, 8th at 15th and 9th at '
       '17th, each once per long rest.'),
      (null, 20, 'Eldritch Master',
       'Spend 1 minute entreating your patron to regain all expended Pact Magic '
       'slots. Once per long rest.'),

      -- ---- The Archfey ----------------------------------------------------
      (v_archfey, 1, 'Expanded Spell List',
       'These count as warlock spells for you. 1st: faerie fire, sleep. 2nd: '
       'calm emotions, phantasmal force. 3rd: blink, plant growth. 4th: '
       'dominate beast, greater invisibility. 5th: dominate person, seeming.'),
      (v_archfey, 1, 'Fey Presence',
       'Action: each creature in a 10-foot cube from you makes a Wisdom save or '
       'is charmed or frightened by you (your choice) until the end of your '
       'next turn. Once per short or long rest.'),
      (v_archfey, 6, 'Misty Escape',
       'Reaction: when you take damage, turn invisible and teleport up to 60 '
       'feet to a space you can see. You stay invisible until the start of '
       'your next turn or until you attack or cast a spell. Once per short or '
       'long rest.'),
      (v_archfey, 10, 'Beguiling Defenses',
       'You can''t be charmed. When a creature tries to charm you, you can use '
       'your reaction to turn it back: the creature makes a Wisdom save or is '
       'charmed by you for 1 minute or until it takes damage.'),
      (v_archfey, 14, 'Dark Delirium',
       'Action: a creature within 60 feet makes a Wisdom save or is charmed or '
       'frightened by you for 1 minute (concentration), lost in an illusory '
       'realm, seeing and hearing only itself, you and the illusion. Ends if it '
       'takes damage. Once per short or long rest.'),

      -- ---- The Fiend ------------------------------------------------------
      (v_fiend, 1, 'Expanded Spell List',
       'These count as warlock spells for you. 1st: burning hands, command. '
       '2nd: blindness/deafness, scorching ray. 3rd: fireball, stinking cloud. '
       '4th: fire shield, wall of fire. 5th: flame strike, hallow.'),
      (v_fiend, 1, 'Dark One''s Blessing',
       'When you reduce a hostile creature to 0 hit points, you gain temporary '
       'hit points equal to your Charisma modifier + warlock level (minimum 1).'),
      (v_fiend, 6, 'Dark One''s Own Luck',
       'When you make an ability check or saving throw, add a d10 to it, after '
       'seeing the roll but before any effects occur. Once per short or long '
       'rest.'),
      (v_fiend, 10, 'Fiendish Resilience',
       'After a short or long rest, choose a damage type: you have resistance '
       'to it until you choose another. Damage from magical or silvered weapons '
       'ignores this resistance.'),
      (v_fiend, 14, 'Hurl Through Hell',
       'When you hit a creature with an attack, send it through the lower '
       'planes until the end of your next turn. When it returns, it takes 10d10 '
       'psychic damage if it isn''t a fiend. Once per long rest.'),

      -- ---- The Great Old One ----------------------------------------------
      (v_old_one, 1, 'Expanded Spell List',
       'These count as warlock spells for you. 1st: dissonant whispers, '
       'Tasha''s hideous laughter. 2nd: detect thoughts, phantasmal force. 3rd: '
       'clairvoyance, sending. 4th: dominate beast, Evard''s black tentacles. '
       '5th: dominate person, telekinesis.'),
      (v_old_one, 1, 'Awakened Mind',
       'You can speak telepathically to any creature you can see within 30 '
       'feet. It must understand a language to understand you.'),
      (v_old_one, 6, 'Entropic Ward',
       'Reaction: impose disadvantage on an attack roll against you. If it '
       'misses, you have advantage on your next attack against that attacker '
       'before the end of your next turn. Once per short or long rest.'),
      (v_old_one, 10, 'Thought Shield',
       'Your thoughts can''t be read unless you allow it. You have resistance '
       'to psychic damage, and a creature that deals psychic damage to you '
       'takes the same amount.'),
      (v_old_one, 14, 'Create Thrall',
       'Action: touch an incapacitated humanoid to charm it until remove curse '
       'is cast on it, it is freed of the charm, or you use this again. You can '
       'talk to it telepathically while you are on the same plane.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where subclass_id = v_archfey),
         count(*) filter (where subclass_id = v_fiend),
         count(*) filter (where subclass_id = v_old_one),
         count(*) filter (where choice is not null)
    into v_base, v_af, v_fi, v_go, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_af <> c_expected_af then
    raise exception '% has % features (expected %). Rolled back.', c_archfey, v_af, c_expected_af;
  elsif v_fi <> c_expected_fi then
    raise exception '% has % features (expected %). Rolled back.', c_fiend, v_fi, c_expected_fi;
  elsif v_go <> c_expected_go then
    raise exception '% has % features (expected %). Rolled back.', c_old_one, v_go, c_expected_go;
  elsif v_choices <> 0 then
    raise exception '% % features carry a choice (expected 0). Rolled back.',
      v_choices, c_class;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 077 the Warlock''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('093');

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
   where c.name = 'Warlock' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 2, 3, 4, 11, 20]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 5 from f where subclass = 'The Archfey')         as archfey_5,
  (select count(*) = 5 from f where subclass = 'The Fiend')           as fiend_5,
  (select count(*) = 5 from f where subclass = 'The Great Old One')   as old_one_5,
  (select count(*) = 0 from f where choice is not null)               as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '093')                                            as ledger_row;

rollback;

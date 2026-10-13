-- db/082_class_features_fighter_phb.sql
--
-- The PHB Martial Archetypes' features: Champion (5), Battle Master (5),
-- Eldritch Knight (6). 16 rows pointing at 071's subclasses. RUN 081 FIRST
-- (not a hard dependency, but the ledger should read in order).
-- XGtE and TCoE archetypes get their own files, one book at a time.
--
-- 081's rule holds: one row per named feature, at its first level, with any
-- later step in the text. Improved Combat Superiority is one row at 10 that
-- says "d12 at 18th", as the PHB writes it.
--
-- EACH SUBCLASS IS RESOLVED ONCE, BY NAME, WITH `into strict`, and the insert
-- reads the resolved ids. No join on subclass name inside the insert: a join
-- that matches nothing drops its rows and succeeds, which is 050's bug.
-- 066's unique (class_id, name) index makes "two matches" unwritable, so
-- strict's too_many_rows is belt and braces.
--
-- NO ROW HERE CARRIES A `choice`:
--   * Combat Superiority lists all sixteen maneuvers in its text. Picking
--     them needs many picks per feature, which is character_feature_choices,
--     a later step (079's header, KNOWN_ISSUES).
--   * Additional Fighting Style (Champion 10) must NOT be 'fighting_style':
--     a second picker would write the same character_classes column and
--     overwrite the first pick. Its text tells the player to note it.
--
-- TEXT: Champion is SRD 5.1 text. Battle Master and Eldritch Knight are not in
-- the SRD, so their rules are restated in our own words, mechanics intact.
-- Multi-line texts use concat_ws(E'\n', ...): adjacent literals across lines
-- concatenate WITHOUT a newline, and the sheet renders \n via pre-line.
--
-- Display only: crit ranges, Remarkable Athlete, superiority dice and spell
-- slots change no derived number and track no use. See KNOWN_ISSUES.
--
-- THE SQL EDITOR WILL OFFER "Run and enable RLS": it misreads plpgsql's
-- `into strict` as a table being created (CLAUDE.md). This file creates no
-- table. Take the option that runs WITHOUT enabling.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class           constant text := 'Fighter';
  c_champion        constant text := 'Champion';
  c_battle_master   constant text := 'Battle Master';
  c_eldritch_knight constant text := 'Eldritch Knight';
  c_expected_ch     constant int  := 5;
  c_expected_bm     constant int  := 5;
  c_expected_ek     constant int  := 6;

  -- What the current `into strict` is looking for, so the handler can say.
  v_seeking         text;

  v_class           uuid;
  v_champion        uuid;
  v_battle_master   uuid;
  v_eldritch_knight uuid;
  v_ch              int;
  v_bm              int;
  v_ek              int;
  v_choices         int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_champion;
  select id into strict v_champion
  from public.subclasses
  where class_id = v_class and name = c_champion and campaign_id is null;

  v_seeking := 'subclass ' || c_battle_master;
  select id into strict v_battle_master
  from public.subclasses
  where class_id = v_class and name = c_battle_master and campaign_id is null;

  v_seeking := 'subclass ' || c_eldritch_knight;
  select id into strict v_eldritch_knight
  from public.subclasses
  where class_id = v_class and name = c_eldritch_knight and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Champion (SRD 5.1) ---------------------------------------------
      (v_champion, 3, 'Improved Critical',
       'Beginning when you choose this archetype at 3rd level, your weapon '
       'attacks score a critical hit on a roll of 19 or 20.'),
      (v_champion, 7, 'Remarkable Athlete',
       'Starting at 7th level, you can add half your proficiency bonus (round up) '
       'to any Strength, Dexterity, or Constitution check you make that doesn''t '
       'already use your proficiency bonus. In addition, when you make a running '
       'long jump, the distance you can cover increases by a number of feet equal '
       'to your Strength modifier.'),
      (v_champion, 10, 'Additional Fighting Style',
       'At 10th level, you can choose a second option from the Fighting Style '
       'class feature. The sheet stores one style per class, so note your second '
       'one yourself.'),
      (v_champion, 15, 'Superior Critical',
       'Starting at 15th level, your weapon attacks score a critical hit on a '
       'roll of 18-20.'),
      (v_champion, 18, 'Survivor',
       'At 18th level, you attain the pinnacle of resilience in battle. At the '
       'start of each of your turns, you regain hit points equal to 5 + your '
       'Constitution modifier if you have no more than half of your hit points '
       'left. You don''t gain this benefit if you have 0 hit points.'),

      -- ---- Battle Master --------------------------------------------------
      (v_battle_master, 3, 'Combat Superiority', concat_ws(E'\n',
       'You learn three maneuvers of your choice from the list below, two more '
       'at 7th, 10th and 15th level, and each time you learn new ones you may '
       'swap one you know for another. You can use only one maneuver per attack.',
       '',
       'Superiority dice: you have four d8s, a fifth at 7th level and a sixth at '
       '15th. A maneuver spends one. You regain all spent dice when you finish a '
       'short or long rest.',
       '',
       'Saving throws: DC = 8 + your proficiency bonus + your Strength or '
       'Dexterity modifier (your choice).',
       '',
       'Maneuvers ("the die" is the superiority die you spend):',
       '- Commander''s Strike: give up one of your attacks and spend a bonus '
       'action; an ally who can see or hear you uses their reaction to make one '
       'weapon attack, adding the die to its damage.',
       '- Disarming Attack: on a hit, add the die to damage; the target makes a '
       'Strength save or drops one held item of your choice at its feet.',
       '- Distracting Strike: on a hit, add the die to damage; the next attack '
       'against the target by someone other than you, before the start of your '
       'next turn, has advantage.',
       '- Evasive Footwork: when you move, add the die to your AC until you stop '
       'moving.',
       '- Feinting Attack: spend a bonus action on a creature within 5 feet; you '
       'have advantage on your next attack against it this turn, and add the die '
       'to that attack''s damage if it hits.',
       '- Goading Attack: on a hit, add the die to damage; the target makes a '
       'Wisdom save or has disadvantage on attacks against anyone but you until '
       'the end of your next turn.',
       '- Lunging Attack: one melee weapon attack on your turn gets 5 extra feet '
       'of reach; on a hit, add the die to damage.',
       '- Maneuvering Attack: on a hit, add the die to damage; an ally who can '
       'see or hear you may use their reaction to move up to half their speed '
       'without provoking opportunity attacks from the target.',
       '- Menacing Attack: on a hit, add the die to damage; the target makes a '
       'Wisdom save or is frightened of you until the end of your next turn.',
       '- Parry: when a creature damages you with a melee attack, use your '
       'reaction to reduce the damage by the die + your Dexterity modifier.',
       '- Precision Attack: add the die to a weapon attack roll, before or after '
       'rolling but before you know whether it hits.',
       '- Pushing Attack: on a hit, add the die to damage; a Large or smaller '
       'target makes a Strength save or is pushed up to 15 feet away.',
       '- Rally: spend a bonus action; an ally who can see or hear you gains '
       'temporary hit points equal to the die + your Charisma modifier.',
       '- Riposte: when a creature misses you with a melee attack, use your '
       'reaction to make a melee weapon attack against it; on a hit, add the die '
       'to damage.',
       '- Sweeping Attack: when you hit with a melee weapon attack, pick another '
       'creature within 5 feet of the target and within your reach; if the '
       'original roll would hit it, it takes damage equal to the die, of the '
       'same type.',
       '- Trip Attack: on a hit, add the die to damage; a Large or smaller target '
       'makes a Strength save or is knocked prone.')),
      (v_battle_master, 3, 'Student of War',
       'You gain proficiency with one type of artisan''s tools of your choice. '
       'Record it with your tool proficiencies.'),
      (v_battle_master, 7, 'Know Your Enemy',
       'Spend at least 1 minute watching or talking with a creature outside '
       'combat and you can size it up against yourself. Pick two of: Strength, '
       'Dexterity or Constitution score; Armor Class; current hit points; total '
       'class levels; fighter levels. The DM tells you whether the creature is '
       'your equal, superior or inferior in each.'),
      (v_battle_master, 10, 'Improved Combat Superiority',
       'Your superiority dice become d10s. At 18th level they become d12s.'),
      (v_battle_master, 15, 'Relentless',
       'When you roll initiative and have no superiority dice left, you regain '
       'one.'),

      -- ---- Eldritch Knight ------------------------------------------------
      (v_eldritch_knight, 3, 'Spellcasting', concat_ws(E'\n',
       'You cast wizard spells, with Intelligence as your spellcasting ability. '
       'Spell save DC = 8 + proficiency bonus + Intelligence modifier; spell '
       'attack = proficiency bonus + Intelligence modifier.',
       '',
       'Cantrips: two wizard cantrips, a third at 10th level.',
       '',
       'Spells known: 3 at 3rd level, 4 at 4th, 5 at 7th, 6 at 8th, 7 at 10th, '
       '8 at 11th, 9 at 13th, 10 at 14th, 11 at 16th, 12 at 19th, 13 at 20th. '
       'They must be abjuration or evocation, except one of your first three and '
       'the new spell at 8th, 14th and 20th level, which can be any school. Each '
       'time you gain a fighter level you may replace one spell you know with '
       'another you have slots for; it must be abjuration or evocation unless it '
       'replaces an any-school spell.',
       '',
       'Spell slots (1st/2nd/3rd/4th), all regained on a long rest:',
       'Level 3: 2 | 4-6: 3 | 7-9: 4/2 | 10-12: 4/3 | 13-15: 4/3/2 | '
       '16-18: 4/3/3 | 19-20: 4/3/3/1')),
      (v_eldritch_knight, 3, 'Weapon Bond',
       'A 1-hour ritual, which you can do during a short rest, bonds you to one '
       'weapon within reach. You can''t be disarmed of a bonded weapon unless '
       'you are incapacitated. While it is on the same plane as you, a bonus '
       'action teleports it to your hand. You can have two bonded weapons, but '
       'summon only one per bonus action; bonding a third breaks one of the '
       'other two.'),
      (v_eldritch_knight, 7, 'War Magic',
       'When you use your action to cast a cantrip, you can make one weapon '
       'attack as a bonus action.'),
      (v_eldritch_knight, 10, 'Eldritch Strike',
       'When you hit a creature with a weapon attack, it has disadvantage on the '
       'next saving throw it makes against a spell you cast before the end of '
       'your next turn.'),
      (v_eldritch_knight, 15, 'Arcane Charge',
       'When you use Action Surge, you can also teleport up to 30 feet to an '
       'unoccupied space you can see, before or after the extra action.'),
      (v_eldritch_knight, 18, 'Improved War Magic',
       'When you use your action to cast a spell, you can make one weapon attack '
       'as a bonus action.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id = v_champion),
         count(*) filter (where subclass_id = v_battle_master),
         count(*) filter (where subclass_id = v_eldritch_knight),
         count(*) filter (where choice is not null)
    into v_ch, v_bm, v_ek, v_choices
  from public.class_features
  where class_id = v_class
    and subclass_id in (v_champion, v_battle_master, v_eldritch_knight)
    and campaign_id is null;

  if v_ch <> c_expected_ch then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_champion, v_ch, c_expected_ch;
  elsif v_bm <> c_expected_bm then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_battle_master, v_bm, c_expected_bm;
  elsif v_ek <> c_expected_ek then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_eldritch_knight, v_ek, c_expected_ek;
  elsif v_choices <> 0 then
    raise exception '% PHB archetype features carry a choice (expected 0). Rolled back.',
      v_choices;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 071 the Fighter''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('082');

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
   where c.name = 'Fighter' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select count(*) = 5 from f where subclass = 'Champion')          as champion_5,
  (select count(*) = 5 from f where subclass = 'Battle Master')     as battle_master_5,
  (select count(*) = 6 from f where subclass = 'Eldritch Knight')   as eldritch_knight_6,
  (select count(*) = 0 from f
    where subclass in ('Champion', 'Battle Master', 'Eldritch Knight')
      and choice is not null)                                        as no_pickers,
  (select position(E'\n' in description) > 0 from f
    where name = 'Combat Superiority')                              as has_newlines,
  (select count(*) = 1 from public.schema_migrations
    where version = '082')                                          as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: 079's composite FK refuses a feature on the wrong class's subclass
-- ---------------------------------------------------------------------------
--
-- 071 BLOCK 1's shape, on class_features: a probe feature hung on Fighter +
-- Champion must land; Fighter + Path of the Berserker (067) must be refused,
-- because (subclass_id, class_id) has no match in subclasses. Runs as the
-- table owner: this is about the FK, not RLS. Rolled back either way.
--
-- CORRECT OUTPUT: two rows: right_class = 'ok',
--                           wrong_class = 'refused (23503)'.

begin;

do $$
declare
  v_fighter   uuid;
  v_champion  uuid;
  v_berserker uuid;
begin
  select id into strict v_fighter from public.classes
   where name = 'Fighter' and campaign_id is null;
  select id into strict v_champion from public.subclasses
   where class_id = v_fighter and name = 'Champion' and campaign_id is null;
  select s.id into strict v_berserker from public.subclasses s
    join public.classes c on c.id = s.class_id
   where c.name = 'Barbarian' and c.campaign_id is null
     and s.name = 'Path of the Berserker' and s.campaign_id is null;

  begin
    insert into public.class_features (class_id, subclass_id, level, name, description)
    values (v_fighter, v_champion, 3, 'Verification probe (right)', 'probe');
    perform set_config('verification.right_class', 'ok', true);
  exception when foreign_key_violation then
    perform set_config('verification.right_class', 'REFUSED -- should have passed', true);
  end;

  begin
    insert into public.class_features (class_id, subclass_id, level, name, description)
    values (v_fighter, v_berserker, 3, 'Verification probe (wrong)', 'probe');
    perform set_config('verification.wrong_class', 'ACCEPTED -- FK MISSING', true);
  exception when foreign_key_violation then
    perform set_config('verification.wrong_class', 'refused (23503)', true);
  end;
end
$$;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'right_class', current_setting('verification.right_class'),
         'wrong_class', current_setting('verification.wrong_class')
       ));

rollback;

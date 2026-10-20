-- db/084_class_features_barbarian.sql
--
-- The Barbarian's base-class features (levels 1-20) and its two PHB Primal
-- Paths: Berserker and Totem Warrior. 22 rows. RUN 083 FIRST (ledger order
-- only; nothing here uses its column).
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision.
--
-- One file per class from here on: base + PHB subclass rows together, which
-- loosens "one book per file" for the PHB only. XGtE and TCoE paths get their
-- own files later.
--
-- 081's rule: one row per named feature at the level it first arrives, later
-- steps in its text (Rage's uses and damage, Brutal Critical's dice).
--
-- TEXT: every row is a short summary in our own words, mechanics intact, not
-- the book's wording. Totem Spirit, Aspect of the Beast and Totemic Attunement
-- list all three PHB animals; the pick is per feature and noted by the player
-- (no `choice`: one feature, many picks, see KNOWN_ISSUES).
--
-- Display only: Rage's damage and resistance, Unarmored Defense (the class's
-- unarmored_ability already drives AC), Fast Movement, etc. change no number
-- and track no use. See KNOWN_ISSUES.
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
  c_class         constant text := 'Barbarian';
  c_berserker     constant text := 'Path of the Berserker';
  c_totem         constant text := 'Path of the Totem Warrior';
  c_expected_base constant int  := 13;
  c_expected_be   constant int  := 4;
  c_expected_tw   constant int  := 5;

  v_seeking   text;

  v_class     uuid;
  v_berserker uuid;
  v_totem     uuid;
  v_base      int;
  v_be        int;
  v_tw        int;
  v_choices   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_berserker;
  select id into strict v_berserker
  from public.subclasses
  where class_id = v_class and name = c_berserker and campaign_id is null;

  v_seeking := 'subclass ' || c_totem;
  select id into strict v_totem
  from public.subclasses
  where class_id = v_class and name = c_totem and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (null::uuid, 1, 'Rage', concat_ws(E'\n',
       'Bonus action to start; lasts 1 minute. Needs no heavy armour.',
       '- Advantage on Strength checks and saves.',
       '- Bonus damage on Strength melee weapon attacks: +2, +3 at 9th, +4 at 16th.',
       '- Resistance to bludgeoning, piercing and slashing damage.',
       '- No spellcasting or concentration while raging.',
       'Ends early if you are knocked out, or if a turn passes in which you '
       'neither attacked a hostile creature nor took damage. You can end it as '
       'a bonus action.',
       'Uses per long rest: 2; 3 at 3rd, 4 at 6th, 5 at 12th, 6 at 17th, '
       'unlimited at 20th.')),
      (null, 1, 'Unarmored Defense',
       'With no armour on, your AC is 10 + Dexterity modifier + Constitution '
       'modifier. A shield still adds its bonus.'),
      (null, 2, 'Reckless Attack',
       'On your first attack of a turn you can choose to attack recklessly: '
       'advantage on Strength melee weapon attacks this turn, but attacks '
       'against you have advantage until your next turn.'),
      (null, 2, 'Danger Sense',
       'Advantage on Dexterity saves against effects you can see, such as traps '
       'and spells, unless you are blinded, deafened or incapacitated.'),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 5, 'Extra Attack',
       'You attack twice when you take the Attack action on your turn.'),
      (null, 5, 'Fast Movement',
       'Your speed increases by 10 feet while you aren''t wearing heavy armour.'),
      (null, 7, 'Feral Instinct',
       'Advantage on initiative rolls. If you are surprised, you can still act '
       'on your first turn, provided you rage before doing anything else.'),
      (null, 9, 'Brutal Critical',
       'Roll one extra weapon damage die on a melee critical hit; two extra '
       'dice at 13th level, three at 17th.'),
      (null, 11, 'Relentless Rage',
       'If you drop to 0 hit points while raging and don''t die outright, make '
       'a DC 10 Constitution save to drop to 1 instead. The DC rises by 5 each '
       'time and resets to 10 after a short or long rest.'),
      (null, 15, 'Persistent Rage',
       'Your rage ends early only if you fall unconscious or choose to end it.'),
      (null, 18, 'Indomitable Might',
       'If a Strength check totals less than your Strength score, use the score '
       'instead.'),
      (null, 20, 'Primal Champion',
       'Your Strength and Constitution each increase by 4, and their maximum '
       'becomes 24.'),

      -- ---- Path of the Berserker ------------------------------------------
      (v_berserker, 3, 'Frenzy',
       'When you rage you can frenzy: for that rage, you can make one melee '
       'weapon attack as a bonus action on each of your later turns. When the '
       'rage ends you gain one level of exhaustion.'),
      (v_berserker, 6, 'Mindless Rage',
       'You can''t be charmed or frightened while raging. A charm or fear '
       'already on you is suspended for the rage.'),
      (v_berserker, 10, 'Intimidating Presence',
       'Action: one creature within 30 feet that can see or hear you makes a '
       'Wisdom save (DC 8 + proficiency bonus + Charisma modifier) or is '
       'frightened of you until the end of your next turn. You can spend your '
       'action on later turns to extend it. It ends if the creature finishes a '
       'turn out of sight or more than 60 feet away. On a success, you can''t '
       'use this on that creature for 24 hours.'),
      (v_berserker, 14, 'Retaliation',
       'When a creature within 5 feet damages you, you can use your reaction to '
       'make a melee weapon attack against it.'),

      -- ---- Path of the Totem Warrior --------------------------------------
      (v_totem, 3, 'Spirit Seeker',
       'You can cast beast sense and speak with animals, but only as rituals.'),
      (v_totem, 3, 'Totem Spirit', concat_ws(E'\n',
       'Choose a totem animal; it shapes your rage. Note your pick.',
       '- Bear: while raging, resistance to all damage except psychic.',
       '- Eagle: while raging without heavy armour, opportunity attacks against '
       'you have disadvantage, and you can Dash as a bonus action.',
       '- Wolf: while raging, your allies have advantage on melee attacks '
       'against hostile creatures within 5 feet of you.')),
      (v_totem, 6, 'Aspect of the Beast', concat_ws(E'\n',
       'Choose a totem animal again (it can differ from your Totem Spirit):',
       '- Bear: double carrying capacity, and advantage on Strength checks to '
       'push, pull, lift or break things.',
       '- Eagle: you see clearly up to a mile away, and dim light doesn''t give '
       'you disadvantage on Perception checks.',
       '- Wolf: you can track at a fast pace and move stealthily at a normal '
       'pace.')),
      (v_totem, 10, 'Spirit Walker',
       'You can cast commune with nature, but only as a ritual.'),
      (v_totem, 14, 'Totemic Attunement', concat_ws(E'\n',
       'Choose a totem animal again:',
       '- Bear: while raging, hostile creatures within 5 feet have '
       'disadvantage on attacks against anyone but you (or another with this '
       'feature). No effect on those that can''t see or hear you or can''t be '
       'frightened.',
       '- Eagle: while raging, you have a flying speed equal to your walking '
       'speed, but you fall if you end your turn in the air.',
       '- Wolf: while raging, when you hit a Large or smaller creature with a '
       'melee weapon attack, you can knock it prone as a bonus action.'))
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where subclass_id = v_berserker),
         count(*) filter (where subclass_id = v_totem),
         count(*) filter (where choice is not null)
    into v_base, v_be, v_tw, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_be <> c_expected_be then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_berserker, v_be, c_expected_be;
  elsif v_tw <> c_expected_tw then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_totem, v_tw, c_expected_tw;
  elsif v_choices <> 0 then
    raise exception '% % features carry a choice (expected 0). Rolled back.',
      v_choices, c_class;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 067 the Barbarian''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('084');

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
   where c.name = 'Barbarian' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 2, 2, 4, 5, 5, 7, 9, 11, 15, 18, 20]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 4 from f where subclass = 'Path of the Berserker')     as berserker_4,
  (select count(*) = 5 from f where subclass = 'Path of the Totem Warrior') as totem_5,
  (select count(*) = 0 from f where choice is not null)               as no_pickers,
  (select position(E'\n' in description) > 0 from f where name = 'Rage') as has_newlines,
  (select count(*) = 1 from public.schema_migrations
    where version = '084')                                            as ledger_row;

rollback;

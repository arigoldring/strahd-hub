-- db/106_class_features_tcoe_fighter.sql
--
-- The Fighter's two Tasha's archetypes: Psi Warrior and Rune Knight. 12 rows,
-- all subclass features. Tasha's optional base-class features (Fighting Style
-- Options, Martial Versatility) are not seeded here; the Tasha's styles are
-- already in 095's options.
--
-- Picks the player notes by hand: Rune Carver's runes (two at 3rd, one more at
-- 7th, 10th and 15th), a many-pick feature like Arcane Shot. All six runes are
-- listed in the row.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 071.
--
-- TEXT: every row is a short summary in our own words, mechanics intact, not
-- the book's wording. Tables are referenced, not reproduced.
--
-- NO PICKERS: no row here is linked to a feature option (095). The end-state
-- check counts class_feature_options links on these subclasses' features and
-- requires zero. Display only, like every feature row (KNOWN_ISSUES).
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
  c_class constant text := 'Fighter';
  c_psi_warrior          constant text := 'Psi Warrior';
  c_rune_knight          constant text := 'Rune Knight';
  c_psi_warrior_n        constant int  := 5;
  c_rune_knight_n        constant int  := 7;

  v_seeking text;
  v_class   uuid;
  v_psi_warrior          uuid;
  v_rune_knight          uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_psi_warrior;
  select id into strict v_psi_warrior
  from public.subclasses
  where class_id = v_class and name = c_psi_warrior and campaign_id is null;

  v_seeking := 'subclass ' || c_rune_knight;
  select id into strict v_rune_knight
  from public.subclasses
  where class_id = v_class and name = c_rune_knight and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Psi Warrior -------------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_psi_warrior::uuid, 3, 'Psionic Power',
       concat_ws(E'\n',
       'You have Psionic Energy dice equal to twice your proficiency bonus: '
       'd6, d8 at 5th level, d10 at 11th, d12 at 17th. Regain all on a long '
       'rest, or one as a bonus action once per short rest.',
       '- Protective Field: reaction when you or a creature you can see '
       'within 30 feet takes damage. Spend a die to reduce the damage by the '
       'roll + your Intelligence modifier (minimum 1).',
       '- Psionic Strike: once per turn, right after you hit a target within '
       '30 feet with a weapon, spend a die for extra force damage equal to '
       'the roll + your Intelligence modifier.',
       '- Telekinetic Movement: action, once per short rest or by spending a '
       'die. Move a Large or smaller unattended object, or a willing '
       'creature other than you, up to 30 feet within 30 feet of you.')),
      (v_psi_warrior, 7, 'Telekinetic Adept',
       concat_ws(E'\n',
       '- Psi-Powered Leap: bonus action, once per short rest or by spending '
       'a die. Gain a flying speed of twice your walking speed until the end '
       'of the turn.',
       '- Telekinetic Thrust: when Psionic Strike damages a target, it makes '
       'a Strength save (DC 8 + proficiency bonus + Intelligence modifier) '
       'or you knock it prone or push it up to 10 feet.')),
      (v_psi_warrior, 10, 'Guarded Mind',
       'Resistance to psychic damage. If you start your turn charmed or '
       'frightened, you can spend a Psionic Energy die to end every effect '
       'causing it.'),
      (v_psi_warrior, 15, 'Bulwark of Force',
       'Bonus action: up to your Intelligence modifier (minimum 1) creatures '
       'within 30 feet, you included, have half cover for 1 minute or until '
       'you are incapacitated. Once per long rest, or again by spending a '
       'die.'),
      (v_psi_warrior, 18, 'Telekinetic Master',
       'Cast telekinesis without components or a slot (Intelligence). While '
       'concentrating on it, you can make one weapon attack as a bonus '
       'action on each of your turns. Once per long rest, or again by '
       'spending a die.'),
      -- ---- Rune Knight -------------------------------------------------------
      (v_rune_knight, 3, 'Bonus Proficiencies',
       'Proficiency with smith''s tools, and you learn Giant.'),
      (v_rune_knight, 3, 'Rune Carver',
       concat_ws(E'\n',
       'Learn two runes (note them), and one more at 7th, 10th and 15th '
       'level. Inscribe each on a weapon, armor, shield or jewelry you hold, '
       'one rune per object. Each rune''s active effect is once per short or '
       'long rest. Save DC 8 + proficiency bonus + Constitution modifier.',
       '- Cloud: advantage on Sleight of Hand and Deception. Reaction: '
       'redirect an attack that hits you or a creature within 30 feet to '
       'another creature within 30 feet, other than the attacker.',
       '- Fire: double proficiency bonus on tool checks. On a weapon hit, '
       'the target takes an extra 2d6 fire and makes a Strength save or is '
       'restrained for 1 minute, taking 2d6 fire each turn and repeating the '
       'save.',
       '- Frost: advantage on Animal Handling and Intimidation. Bonus '
       'action: +2 to Strength and Constitution checks and saves for 10 '
       'minutes.',
       '- Stone: advantage on Insight, and darkvision 120 feet. Reaction: a '
       'creature ending its turn within 30 feet makes a Wisdom save or is '
       'charmed for 1 minute, incapacitated with speed 0, repeating the save '
       'each turn.',
       '- Hill (7th level): advantage on saves against poison, and '
       'resistance to poison damage. Bonus action: resistance to '
       'bludgeoning, piercing and slashing for 1 minute.',
       '- Storm (7th level): advantage on Arcana, and you can''t be surprised '
       'unless incapacitated. Bonus action: for 1 minute, use your reaction '
       'to give advantage or disadvantage to an attack, save or check by a '
       'creature within 60 feet.')),
      (v_rune_knight, 3, 'Giant''s Might',
       'Bonus action, for 1 minute: you become Large if there is room, have '
       'advantage on Strength checks and saves, and once per turn deal an '
       'extra 1d6 damage with a weapon or unarmed hit. Uses equal to your '
       'proficiency bonus per long rest.'),
      (v_rune_knight, 7, 'Runic Shield',
       'Reaction: when a creature you can see within 60 feet is hit, force '
       'the attacker to reroll the d20 and use the new roll. Uses equal to '
       'your proficiency bonus per long rest.'),
      (v_rune_knight, 10, 'Great Stature',
       'When Giant''s Might starts, you grow 1d8 inches taller permanently, '
       'and its extra damage becomes 1d8.'),
      (v_rune_knight, 15, 'Master of Runes',
       'Each rune''s active effect works twice per short or long rest.'),
      (v_rune_knight, 18, 'Runic Juggernaut',
       'Giant''s Might deals an extra 1d10, lets you become Huge if there is '
       'room, and adds 5 feet of reach while you''re Huge.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_psi_warrior and campaign_id is null;
  if v_count <> c_psi_warrior_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_psi_warrior, v_count, c_psi_warrior_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_rune_knight and campaign_id is null;
  if v_count <> c_rune_knight_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_rune_knight, v_count, c_rune_knight_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_psi_warrior, v_rune_knight);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
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

insert into public.schema_migrations (version) values ('106');

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
     and s.name in ('Psi Warrior', 'Rune Knight')
)
select
  (select array_agg(level order by level, name)
          = array[3, 7, 10, 15, 18]::smallint[]
     from f where subclass = 'Psi Warrior')                   as psi_warrior_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 7, 10, 15, 18]::smallint[]
     from f where subclass = 'Rune Knight')                   as rune_knight_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '106')                                            as ledger_row;

rollback;

-- db/099_class_features_xgte_bard.sql
--
-- The Bard's three Xanathar's colleges: Glamour, Swords and Whispers. 13 rows,
-- all subclass features (the base class is 085's).
--
-- College of Swords' Fighting Style is a real picker, and this is the first
-- seed file to write its own option links (095 linked Champion's): it offers Dueling and Two-Weapon Fighting, linked to 095's
-- shared options. Its Extra Attack row repeats the name of the Fighter's base
-- feature; the unique name index is per class and subclass, so that's allowed.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 068.
--
-- TEXT: every row is a short summary in our own words, mechanics intact, not
-- the book's wording. Tables are referenced, not reproduced.
--
-- PICKERS (095): Fighting Style (College of Swords) offers dueling, two_weapon.
-- Linked by key to the shared feature_options rows; the end-state check
-- requires exactly 2 links on these subclasses' features. Every other
-- row is display only (KNOWN_ISSUES).
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
  c_class constant text := 'Bard';
  c_glamour              constant text := 'College of Glamour';
  c_swords               constant text := 'College of Swords';
  c_whispers             constant text := 'College of Whispers';
  c_glamour_n            constant int  := 4;
  c_swords_n             constant int  := 5;
  c_whispers_n           constant int  := 4;

  v_seeking text;
  v_class   uuid;
  v_glamour              uuid;
  v_swords               uuid;
  v_whispers             uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_glamour;
  select id into strict v_glamour
  from public.subclasses
  where class_id = v_class and name = c_glamour and campaign_id is null;

  v_seeking := 'subclass ' || c_swords;
  select id into strict v_swords
  from public.subclasses
  where class_id = v_class and name = c_swords and campaign_id is null;

  v_seeking := 'subclass ' || c_whispers;
  select id into strict v_whispers
  from public.subclasses
  where class_id = v_class and name = c_whispers and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- College of Glamour ------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_glamour::uuid, 3, 'Mantle of Inspiration',
       'Bonus action, spending one Bardic Inspiration use: up to your '
       'Charisma modifier (minimum 1) creatures within 60 feet that can see '
       'you each gain 5 temporary hit points (8 at 5th level, 11 at 10th, 14 '
       'at 15th) and can use their reaction to move up to their speed '
       'without provoking opportunity attacks.'),
      (v_glamour, 3, 'Enthralling Performance',
       'After performing for at least 1 minute, up to your Charisma modifier '
       'humanoids within 60 feet who watched and listened make a Wisdom save '
       'against your spell DC or are charmed by you for 1 hour: they idolize '
       'you and hinder your opponents, though they won''t fight for you '
       'unless already inclined to. It ends if a target takes damage, you '
       'attack it, or it sees you attack or harm its allies. A target that '
       'succeeds has no hint you tried. Once per short or long rest.'),
      (v_glamour, 6, 'Mantle of Majesty',
       'Bonus action: cast command without a spell slot, then keep a '
       'majestic presence for 1 minute (concentration, as for a spell), '
       'casting command as a bonus action on each of your turns without a '
       'slot. A creature charmed by you fails its save against this command '
       'automatically. Once per long rest.'),
      (v_glamour, 14, 'Unbreakable Majesty',
       'Bonus action: for 1 minute, or until you are incapacitated, the '
       'first time each turn a creature attacks you it makes a Charisma save '
       'against your spell DC. On a failure it must pick a new target or '
       'lose the attack. On a success it can attack you, but has '
       'disadvantage on saves against your spells on your next turn. Once '
       'per short or long rest.'),
      -- ---- College of Swords -------------------------------------------------
      (v_swords, 3, 'Bonus Proficiencies',
       'Proficiency with medium armor and the scimitar. A simple or martial '
       'melee weapon you''re proficient with can be your spellcasting focus '
       'for bard spells.'),
      (v_swords, 3, 'Fighting Style',
       'Pick Dueling or Two-Weapon Fighting.'),
      (v_swords, 3, 'Blade Flourish',
       concat_ws(E'\n',
       'When you take the Attack action, your walking speed rises by 10 feet '
       'until the end of the turn. Once per turn, when a weapon attack hits, '
       'you can spend a Bardic Inspiration die for one flourish; the die''s '
       'roll is added to the attack''s damage, plus:',
       '- Defensive Flourish: add the roll to your AC until the start of '
       'your next turn.',
       '- Slashing Flourish: another creature of your choice within 5 feet '
       'of you takes damage equal to the roll, of the weapon''s type.',
       '- Mobile Flourish: push the target 5 feet plus the roll, then use '
       'your reaction to move up to your walking speed to a space within 5 '
       'feet of it.')),
      (v_swords, 6, 'Extra Attack',
       'You attack twice when you take the Attack action on your turn.'),
      (v_swords, 14, 'Master''s Flourish',
       'When you use a Blade Flourish, you can roll a d6 for it instead of '
       'spending a Bardic Inspiration die.'),
      -- ---- College of Whispers -----------------------------------------------
      (v_whispers, 3, 'Psychic Blades',
       'Once per round on your turn, when you hit with a weapon attack, you '
       'can spend one Bardic Inspiration use for an extra 2d6 psychic '
       'damage; 3d6 at 5th level, 5d6 at 10th, 8d6 at 15th.'),
      (v_whispers, 3, 'Words of Terror',
       'After talking alone with a creature for at least 1 minute, it makes '
       'a Wisdom save against your spell DC or is frightened of you, or of '
       'another creature you name, for 1 hour. It ends early if the target '
       'is attacked or harmed, or sees its allies attacked. A target that '
       'succeeds has no hint you tried. Once per short or long rest.'),
      (v_whispers, 6, 'Mantle of Whispers',
       'When a humanoid dies within 30 feet of you, you can use your '
       'reaction to capture its shadow. Later, as an action, take on its '
       'appearance for 1 hour (end it as a bonus action). Others take you '
       'for that person unless an Insight check beats your Deception check + '
       '5, and you know its general facts and habits, but not its secrets. '
       'Once per short or long rest.'),
      (v_whispers, 14, 'Shadow Lore',
       'Action: whisper to one creature within 30 feet that can hear you and '
       'shares a language. It makes a Wisdom save against your spell DC or '
       'is charmed by you for 8 hours, or until you or your allies attack or '
       'harm it, believing you know its most shameful secret: it obeys you '
       'to keep it hidden, but won''t risk its life or fight for you. A '
       'target that succeeds has no hint you tried. Once per long rest.')
  ) as v(subclass_id, level, name, description);

  -- Fighting Style's picker: the shared options named by key.
  insert into public.class_feature_options (feature_id, option_id)
  select f.id, o.id
    from public.class_features f
    join public.feature_options o
      on o.kind = 'fighting_style' and o.campaign_id is null
     and o.key in ('dueling', 'two_weapon')
   where f.class_id = v_class and f.subclass_id = v_swords
     and f.name = 'Fighting Style' and f.campaign_id is null;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_glamour and campaign_id is null;
  if v_count <> c_glamour_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_glamour, v_count, c_glamour_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_swords and campaign_id is null;
  if v_count <> c_swords_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_swords, v_count, c_swords_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_whispers and campaign_id is null;
  if v_count <> c_whispers_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_whispers, v_count, c_whispers_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_glamour, v_swords, v_whispers);
  if v_links <> 2 then
    raise exception '% option links on these features (expected 2). Rolled back.', v_links;
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

insert into public.schema_migrations (version) values ('099');

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
   where c.name = 'Bard' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('College of Glamour', 'College of Swords', 'College of Whispers')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 6, 14]::smallint[]
     from f where subclass = 'College of Glamour')            as glamour_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 6, 14]::smallint[]
     from f where subclass = 'College of Swords')             as swords_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 6, 14]::smallint[]
     from f where subclass = 'College of Whispers')           as whispers_levels,
  (select count(*) = 2 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as links_2,
  (select count(*) = 1 from public.schema_migrations
    where version = '099')                                            as ledger_row;

rollback;

-- db/114_class_features_tcoe_rogue.sql
--
-- The Rogue's two Tasha's archetypes: Phantom and Soulknife. 10 rows, all
-- subclass features. Tasha's optional base-class feature (Steady Aim) is not
-- seeded here.
--
-- Whispers of the Dead's proficiency changes on every rest, so it isn't a
-- stored pick.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 075.
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
  c_class constant text := 'Rogue';
  c_phantom              constant text := 'Phantom';
  c_soulknife            constant text := 'Soulknife';
  c_phantom_n            constant int  := 5;
  c_soulknife_n          constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_phantom              uuid;
  v_soulknife            uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_phantom;
  select id into strict v_phantom
  from public.subclasses
  where class_id = v_class and name = c_phantom and campaign_id is null;

  v_seeking := 'subclass ' || c_soulknife;
  select id into strict v_soulknife
  from public.subclasses
  where class_id = v_class and name = c_soulknife and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Phantom -----------------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_phantom::uuid, 3, 'Whispers of the Dead',
       'After each short or long rest, gain proficiency with one skill or '
       'tool of your choice, replacing the last one this gave you.'),
      (v_phantom, 3, 'Wails from the Grave',
       'Right after you deal Sneak Attack damage on your turn, a second '
       'creature you can see within 30 feet of the first takes necrotic '
       'damage equal to half your Sneak Attack dice (rounded up). Uses equal '
       'to your proficiency bonus per long rest.'),
      (v_phantom, 9, 'Tokens of the Departed',
       concat_ws(E'\n',
       'Reaction: when a creature dies within 30 feet of you, create a soul '
       'trinket. You can hold up to your proficiency bonus of them. While '
       'you hold one:',
       '- Advantage on death saves and Constitution saves.',
       '- When you deal Sneak Attack damage, destroy one to use Wails from '
       'the Grave without spending a use.',
       '- Action: destroy one to ask its spirit a single question, which it '
       'answers.')),
      (v_phantom, 13, 'Ghost Walk',
       'Bonus action, for 10 minutes: a 10-foot flying speed and hover, '
       'attacks against you have disadvantage, and you can move through '
       'creatures and objects as difficult terrain, taking 1d10 force if you '
       'end your turn inside one. Once per long rest, or again by destroying '
       'a soul trinket.'),
      (v_phantom, 17, 'Death''s Friend',
       'Wails from the Grave damages both the first and the second creature. '
       'At the end of a long rest, if you hold no soul trinket, one appears '
       'in your hand.'),
      -- ---- Soulknife ---------------------------------------------------------
      (v_soulknife, 3, 'Psionic Power',
       concat_ws(E'\n',
       'You have Psionic Energy dice equal to twice your proficiency bonus: '
       'd6, d8 at 5th level, d10 at 11th, d12 at 17th. Regain all on a long '
       'rest, or one as a bonus action once per short rest.',
       '- Psi-Bolstered Knack: when you fail a check with a skill or tool '
       'you''re proficient in, roll a die and add it. The die is spent only '
       'if you then succeed.',
       '- Psychic Whispers: action, up to your proficiency bonus creatures '
       'you can see can talk with you telepathically for a number of hours '
       'equal to a die''s roll. Free once per long rest, then a die per use.')),
      (v_soulknife, 3, 'Psychic Blades',
       'When you take the Attack action, manifest a blade in a free hand and '
       'attack with it: a simple melee weapon with finesse and thrown (60 '
       'feet), dealing 1d6 psychic. After that attack, you can make a second '
       'one with your other free hand as a bonus action, for 1d4 psychic. '
       'The blades vanish after each attack.'),
      (v_soulknife, 9, 'Soul Blades',
       concat_ws(E'\n',
       '- Homing Strikes: when a Psychic Blade attack misses, add a die''s '
       'roll to it. The die is spent only if the attack then hits.',
       '- Psychic Teleportation: bonus action, spend a die. Teleport to a '
       'space you can see up to 10 times its roll in feet away.')),
      (v_soulknife, 13, 'Psychic Veil',
       'Action: become invisible for 1 hour, ending early right after you '
       'damage a creature or force it to make a save. Once per long rest, or '
       'again by spending a die.'),
      (v_soulknife, 17, 'Rend Mind',
       'When your Psychic Blades deal Sneak Attack damage, the target makes '
       'a Wisdom save (DC 8 + proficiency bonus + Dexterity modifier) or is '
       'stunned for 1 minute, repeating the save each turn. Once per long '
       'rest, or again by spending three dice.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_phantom and campaign_id is null;
  if v_count <> c_phantom_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_phantom, v_count, c_phantom_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_soulknife and campaign_id is null;
  if v_count <> c_soulknife_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_soulknife, v_count, c_soulknife_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_phantom, v_soulknife);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
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

insert into public.schema_migrations (version) values ('114');

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
   where c.name = 'Rogue' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Phantom', 'Soulknife')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 9, 13, 17]::smallint[]
     from f where subclass = 'Phantom')                       as phantom_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 9, 13, 17]::smallint[]
     from f where subclass = 'Soulknife')                     as soulknife_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '114')                                            as ledger_row;

rollback;

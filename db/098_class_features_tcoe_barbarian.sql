-- db/098_class_features_tcoe_barbarian.sql
--
-- The Barbarian's two Tasha's Primal Paths: Beast and Wild Magic. 9 rows, all
-- subclass features. Tasha's optional base-class features (Primal Knowledge,
-- Instinctive Pounce) are a separate decision and not seeded here.
--
-- Form of the Beast's weapon and Bestial Soul's adaptation are chosen each time
-- (per rage, per rest), not stored picks. The Wild Magic table is referenced,
-- not reproduced.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 067.
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
  c_class constant text := 'Barbarian';
  c_beast                constant text := 'Path of the Beast';
  c_wild_magic           constant text := 'Path of Wild Magic';
  c_beast_n              constant int  := 4;
  c_wild_magic_n         constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_beast                uuid;
  v_wild_magic           uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_beast;
  select id into strict v_beast
  from public.subclasses
  where class_id = v_class and name = c_beast and campaign_id is null;

  v_seeking := 'subclass ' || c_wild_magic;
  select id into strict v_wild_magic
  from public.subclasses
  where class_id = v_class and name = c_wild_magic and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Path of the Beast -------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_beast::uuid, 3, 'Form of the Beast',
       concat_ws(E'\n',
       'When you rage, you grow a natural weapon until the rage ends. Pick '
       'one each time; it uses Strength and you''re proficient with it.',
       '- Bite: 1d8 piercing. Once per turn, if you hit while below half '
       'your hit points, regain hit points equal to your proficiency bonus.',
       '- Claws: 1d6 slashing, one per hand. When you attack with a claw as '
       'part of the Attack action, make one extra claw attack.',
       '- Tail: 1d8 piercing, reach. When a creature within 10 feet hits '
       'you, use your reaction to roll a d8 and add it to your AC against '
       'that attack.')),
      (v_beast, 6, 'Bestial Soul',
       'Your natural weapons count as magical. After each short or long '
       'rest, pick one: a swimming speed equal to your walking speed and '
       'water breathing; a climbing speed equal to your walking speed, '
       'including on ceilings, with no check; or, once per turn when you '
       'jump, a Strength (Athletics) check that extends the jump by that '
       'many feet.'),
      (v_beast, 10, 'Infectious Fury',
       'While raging, when you hit with a natural weapon, the target makes a '
       'Wisdom save (DC 8 + proficiency bonus + Constitution modifier) or '
       'you pick: it uses its reaction to make a melee attack against a '
       'creature you choose, or it takes 2d12 psychic damage. Uses equal to '
       'your proficiency bonus per long rest.'),
      (v_beast, 14, 'Call the Hunt',
       'When you rage, up to your Constitution modifier (minimum 1) willing '
       'creatures within 30 feet can join. You gain 5 temporary hit points '
       'per creature that does, and until the rage ends each of them can '
       'deal an extra 1d6 damage once per turn when it hits. Uses equal to '
       'your proficiency bonus per long rest.'),
      -- ---- Path of Wild Magic ------------------------------------------------
      (v_wild_magic, 3, 'Magic Awareness',
       'Action: until the end of your next turn, you sense the location of '
       'any spell or magic item within 60 feet that isn''t behind total '
       'cover, and the school of any spell you sense. Uses equal to your '
       'proficiency bonus per long rest.'),
      (v_wild_magic, 3, 'Wild Surge',
       'When you rage, roll on the Wild Magic table (Tasha''s) and apply the '
       'effect. Save DC 8 + proficiency bonus + Constitution modifier.'),
      (v_wild_magic, 6, 'Bolstering Magic',
       'Action: touch a creature (you included) and pick one: for 10 minutes '
       'it adds a d3 to attack rolls and ability checks; or it recovers one '
       'spell slot of a level equal to a d3 roll or lower. Uses equal to '
       'your proficiency bonus per long rest.'),
      (v_wild_magic, 10, 'Unstable Backlash',
       'While raging, when you take damage or fail a saving throw, you can '
       'use your reaction to roll on the Wild Magic table again, replacing '
       'your current effect.'),
      (v_wild_magic, 14, 'Controlled Surge',
       'When you roll on the Wild Magic table, roll twice and use either '
       'result. If both rolls match, pick any effect on the table instead.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_beast and campaign_id is null;
  if v_count <> c_beast_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_beast, v_count, c_beast_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_wild_magic and campaign_id is null;
  if v_count <> c_wild_magic_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_wild_magic, v_count, c_wild_magic_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_beast, v_wild_magic);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
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

insert into public.schema_migrations (version) values ('098');

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
   where c.name = 'Barbarian' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Path of the Beast', 'Path of Wild Magic')
)
select
  (select array_agg(level order by level, name)
          = array[3, 6, 10, 14]::smallint[]
     from f where subclass = 'Path of the Beast')             as beast_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 6, 10, 14]::smallint[]
     from f where subclass = 'Path of Wild Magic')            as wild_magic_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '098')                                            as ledger_row;

rollback;

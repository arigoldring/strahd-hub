-- db/118_class_features_tcoe_warlock.sql
--
-- The Warlock's two Tasha's patrons: the Fathomless and the Genie. 12 rows,
-- all subclass features, in 093's row naming. Tasha's optional base-class
-- features (Pact of the Talisman, the extra invocations, Eldritch
-- Versatility) are not seeded here.
--
-- Picks the player notes by hand: the Genie's kind (dao, djinni, efreeti or
-- marid), which decides its extra spells, Genie's Wrath's damage type and
-- Elemental Gift's resistance.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 077.
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
  c_class constant text := 'Warlock';
  c_fathomless           constant text := 'The Fathomless';
  c_genie                constant text := 'The Genie';
  c_fathomless_n         constant int  := 7;
  c_genie_n              constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_fathomless           uuid;
  v_genie                uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_fathomless;
  select id into strict v_fathomless
  from public.subclasses
  where class_id = v_class and name = c_fathomless and campaign_id is null;

  v_seeking := 'subclass ' || c_genie;
  select id into strict v_genie
  from public.subclasses
  where class_id = v_class and name = c_genie and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- The Fathomless ----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_fathomless::uuid, 1, 'Expanded Spell List',
       'These count as warlock spells for you; the levels are spell levels. '
       '1st: create or destroy water, thunderwave. 2nd: gust of wind, '
       'silence. 3rd: lightning bolt, sleet storm. 4th: control water, '
       'summon elemental (water only). 5th: Bigby''s hand (a tentacle), cone '
       'of cold.'),
      (v_fathomless, 1, 'Tentacle of the Deeps',
       'Bonus action: a 10-foot spectral tentacle appears at a point you can '
       'see within 60 feet for 1 minute. When it appears, and as a bonus '
       'action when you move it up to 30 feet, make a melee spell attack '
       'against a creature within 10 feet of it: 1d8 cold damage (2d8 at '
       '10th level) and its speed drops by 10 feet until the start of your '
       'next turn. Uses equal to your proficiency bonus per long rest.'),
      (v_fathomless, 1, 'Gift of the Sea',
       'A 40-foot swimming speed, and you can breathe underwater.'),
      (v_fathomless, 6, 'Oceanic Soul',
       'Resistance to cold damage. While you and another creature are both '
       'fully underwater, you understand each other''s speech.'),
      (v_fathomless, 6, 'Guardian Coil',
       'Reaction: when you or a creature you can see takes damage within 10 '
       'feet of your tentacle, reduce it by 1d8 (2d8 at 10th level).'),
      (v_fathomless, 10, 'Grasping Tentacles',
       'You learn Evard''s black tentacles, a warlock spell not counted '
       'against your spells known, and can cast it once per long rest '
       'without a slot. When you cast it, gain temporary hit points equal to '
       'your warlock level, and damage can''t break your concentration on it.'),
      (v_fathomless, 14, 'Fathomless Plunge',
       'Action: you and up to five willing creatures you can see within 30 '
       'feet teleport to spaces within 30 feet of a body of water you have '
       'seen within 1 mile, pond-sized or larger. Once per short or long '
       'rest.'),
      -- ---- The Genie ---------------------------------------------------------
      (v_genie, 1, 'Expanded Spell List',
       'These count as warlock spells for you; the levels are spell levels. '
       '1st: detect evil and good. 2nd: phantasmal force. 3rd: create food '
       'and water. 4th: phantasmal killer. 5th: creation. 9th: wish. Plus by '
       'your genie''s kind (note it), from 1st to 5th level: dao, sanctuary, '
       'spike growth, meld into stone, stone shape, wall of stone; djinni, '
       'thunderwave, gust of wind, wind wall, greater invisibility, seeming; '
       'efreeti, burning hands, scorching ray, fireball, fire shield, flame '
       'strike; marid, fog cloud, blur, sleet storm, control water, cone of '
       'cold.'),
      (v_genie, 1, 'Genie''s Vessel',
       concat_ws(E'\n',
       'A Tiny vessel that is your spellcasting focus: AC equal to your '
       'spell DC, hit points equal to your warlock level + proficiency '
       'bonus, immune to poison and psychic.',
       '- Bottled Respite: action, vanish into the vessel for up to twice '
       'your proficiency bonus in hours, leaving early as a bonus action. '
       'Once per long rest.',
       '- Genie''s Wrath: once on each of your turns when you hit with an '
       'attack roll, deal extra damage equal to your proficiency bonus: '
       'bludgeoning (dao), thunder (djinni), fire (efreeti) or cold (marid).')),
      (v_genie, 6, 'Elemental Gift',
       'Resistance to your genie''s damage type. Bonus action: a 30-foot '
       'flying speed and hover for 10 minutes. Uses equal to your '
       'proficiency bonus per long rest.'),
      (v_genie, 10, 'Sanctuary Vessel',
       'Bottled Respite can bring up to five willing creatures within 30 '
       'feet with you; eject any of them as a bonus action. Anyone who stays '
       'inside for 10 minutes gains a short rest''s benefit and adds your '
       'proficiency bonus to hit points regained from Hit Dice.'),
      (v_genie, 14, 'Limited Wish',
       'Action: ask the vessel for the effect of one spell of 6th level or '
       'lower from any class''s list with a casting time of 1 action. It '
       'takes effect at once, needing no components. Once every 1d4 long '
       'rests.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_fathomless and campaign_id is null;
  if v_count <> c_fathomless_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_fathomless, v_count, c_fathomless_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_genie and campaign_id is null;
  if v_count <> c_genie_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_genie, v_count, c_genie_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_fathomless, v_genie);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
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

insert into public.schema_migrations (version) values ('118');

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
   where c.name = 'Warlock' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('The Fathomless', 'The Genie')
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 1, 6, 6, 10, 14]::smallint[]
     from f where subclass = 'The Fathomless')                as fathomless_levels,
  (select array_agg(level order by level, name)
          = array[1, 1, 6, 10, 14]::smallint[]
     from f where subclass = 'The Genie')                     as genie_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '118')                                            as ledger_row;

rollback;

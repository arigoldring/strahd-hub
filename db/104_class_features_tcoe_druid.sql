-- db/104_class_features_tcoe_druid.sql
--
-- The Druid's three Tasha's circles: Spores, Stars and Wildfire. 16 rows, all
-- subclass features. Tasha's optional base-class features (Wild Companion,
-- Cantrip Versatility) are not seeded here.
--
-- Starry Form's constellation is chosen each time, not stored. The wildfire
-- spirit's stat block is referenced, not reproduced.
--
-- RULES EDITION: D&D 5e 2014 (Tasha's Cauldron of Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 070.
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
  c_class constant text := 'Druid';
  c_spores               constant text := 'Circle of Spores';
  c_stars                constant text := 'Circle of Stars';
  c_wildfire             constant text := 'Circle of Wildfire';
  c_spores_n             constant int  := 6;
  c_stars_n              constant int  := 5;
  c_wildfire_n           constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_spores               uuid;
  v_stars                uuid;
  v_wildfire             uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_spores;
  select id into strict v_spores
  from public.subclasses
  where class_id = v_class and name = c_spores and campaign_id is null;

  v_seeking := 'subclass ' || c_stars;
  select id into strict v_stars
  from public.subclasses
  where class_id = v_class and name = c_stars and campaign_id is null;

  v_seeking := 'subclass ' || c_wildfire;
  select id into strict v_wildfire
  from public.subclasses
  where class_id = v_class and name = c_wildfire and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Circle of Spores --------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_spores::uuid, 2, 'Circle Spells',
       'Always prepared, not counted against your total; the levels are '
       'druid levels. 2nd: chill touch (cantrip). 3rd: blindness/deafness, '
       'gentle repose. 5th: animate dead, gaseous form. 7th: blight, '
       'confusion. 9th: cloudkill, contagion.'),
      (v_spores, 2, 'Halo of Spores',
       'Reaction: when a creature you can see moves into a space within 10 '
       'feet of you or starts its turn there, it makes a Constitution save '
       'against your spell DC or takes 1d4 necrotic damage; 1d6 at 6th '
       'level, 1d8 at 10th, 1d10 at 14th.'),
      (v_spores, 2, 'Symbiotic Entity',
       'Action, spending a Wild Shape use: gain 4 temporary hit points per '
       'druid level for 10 minutes, until they are gone, or until you Wild '
       'Shape again. Meanwhile Halo of Spores rolls its damage die twice, '
       'and your melee weapon attacks deal an extra 1d6 necrotic damage.'),
      (v_spores, 6, 'Fungal Infestation',
       'Reaction: when a Small or Medium beast or humanoid dies within 10 '
       'feet, raise it as a zombie with 1 hit point. It acts right after '
       'you, takes only the Attack action on your mental command, and '
       'collapses after 1 hour. Uses equal to your Wisdom modifier (minimum '
       '1) per long rest.'),
      (v_spores, 10, 'Spreading Spores',
       'Bonus action while Symbiotic Entity is active: fill a 10-foot cube '
       'within 30 feet with spores for 1 minute. A creature that moves into '
       'it or starts its turn there takes your Halo of Spores damage on a '
       'failed save, once per turn. While the cube lasts, you can''t use the '
       'Halo''s reaction.'),
      (v_spores, 14, 'Fungal Body',
       'You can''t be blinded, deafened, frightened or poisoned, and a '
       'critical hit against you is a normal hit unless you are '
       'incapacitated.'),
      -- ---- Circle of Stars ---------------------------------------------------
      (v_stars, 2, 'Star Map',
       'A star chart that is a spellcasting focus for you. You know '
       'guidance, and have guiding bolt prepared (not counted against your '
       'total), casting it without a slot a number of times equal to your '
       'proficiency bonus per long rest.'),
      (v_stars, 2, 'Starry Form',
       concat_ws(E'\n',
       'Action, spending a Wild Shape use: take a starry form for 10 '
       'minutes, shedding bright light for 10 feet and dim light for 10 '
       'more. Pick a constellation each time:',
       '- Archer: bonus action ranged spell attack within 60 feet, 1d8 + '
       'your Wisdom modifier radiant damage.',
       '- Chalice: when you heal with a spell slot, you or a creature within '
       '30 feet regains 1d8 + your Wisdom modifier hit points.',
       '- Dragon: on Intelligence and Wisdom checks, and Constitution saves '
       'to keep concentration, treat a d20 roll of 9 or lower as 10.')),
      (v_stars, 6, 'Cosmic Omen',
       'After a long rest, roll a die: even is Weal, odd is Woe. Reaction: '
       'when a creature you can see within 30 feet makes an attack roll, '
       'saving throw or ability check, add a d6 to it (Weal) or subtract one '
       '(Woe). Uses equal to your proficiency bonus per long rest.'),
      (v_stars, 10, 'Twinkling Constellations',
       'Archer and Chalice deal or heal 2d8 instead of 1d8. Dragon also '
       'gives a 20-foot flying speed and hover. At the start of each of your '
       'turns in Starry Form, you can switch constellation.'),
      (v_stars, 14, 'Full of Stars',
       'In Starry Form you have resistance to bludgeoning, piercing and '
       'slashing damage.'),
      -- ---- Circle of Wildfire ------------------------------------------------
      (v_wildfire, 2, 'Circle Spells',
       'Always prepared, not counted against your total; the levels are '
       'druid levels. 2nd: burning hands, cure wounds. 3rd: flaming sphere, '
       'scorching ray. 5th: plant growth, revivify. 7th: aura of life, fire '
       'shield. 9th: flame strike, mass cure wounds.'),
      (v_wildfire, 2, 'Summon Wildfire Spirit',
       'Action, spending a Wild Shape use: summon your wildfire spirit '
       '(Tasha''s stat block) within 30 feet. Creatures other than you within '
       '10 feet of it make a Dexterity save or take 2d6 fire damage. It '
       'lasts 1 hour, until it drops to 0 hit points, until you summon it '
       'again or until you die. It acts on your turn, dodging unless you '
       'command it with a bonus action.'),
      (v_wildfire, 6, 'Enhanced Bond',
       'While the spirit is summoned, your spells that deal fire damage or '
       'heal add a d8 to one damage or healing roll, and your spells with a '
       'range other than self can originate from the spirit.'),
      (v_wildfire, 10, 'Cauterizing Flames',
       'When a Small or larger creature dies within 30 feet of you or your '
       'spirit, a flame burns in its space for 1 minute. Reaction: when a '
       'creature you can see enters that space, put the flame out to heal it '
       'or burn it for 2d10 + your Wisdom modifier. Uses equal to your '
       'proficiency bonus per long rest.'),
      (v_wildfire, 14, 'Blazing Revival',
       'When you drop to 0 hit points and don''t die outright, if your spirit '
       'is within 120 feet you can drop it to 0 hit points instead: you '
       'regain half your hit point maximum and stand up. Once per long rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_spores and campaign_id is null;
  if v_count <> c_spores_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_spores, v_count, c_spores_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_stars and campaign_id is null;
  if v_count <> c_stars_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_stars, v_count, c_stars_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_wildfire and campaign_id is null;
  if v_count <> c_wildfire_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_wildfire, v_count, c_wildfire_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_spores, v_stars, v_wildfire);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 070 the Druid''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('104');

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
   where c.name = 'Druid' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Circle of Spores', 'Circle of Stars', 'Circle of Wildfire')
)
select
  (select array_agg(level order by level, name)
          = array[2, 2, 2, 6, 10, 14]::smallint[]
     from f where subclass = 'Circle of Spores')              as spores_levels,
  (select array_agg(level order by level, name)
          = array[2, 2, 6, 10, 14]::smallint[]
     from f where subclass = 'Circle of Stars')               as stars_levels,
  (select array_agg(level order by level, name)
          = array[2, 2, 6, 10, 14]::smallint[]
     from f where subclass = 'Circle of Wildfire')            as wildfire_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '104')                                            as ledger_row;

rollback;

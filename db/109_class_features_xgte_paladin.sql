-- db/109_class_features_xgte_paladin.sql
--
-- The Paladin's two Xanathar's oaths: Conquest and Redemption. 12 rows, all
-- subclass features (the base class is 089's), in 089's row naming: Oath
-- Spells, then one "Channel Divinity: <option>" row per option.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 073.
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
  c_class constant text := 'Paladin';
  c_conquest             constant text := 'Oath of Conquest';
  c_redemption           constant text := 'Oath of Redemption';
  c_conquest_n           constant int  := 6;
  c_redemption_n         constant int  := 6;

  v_seeking text;
  v_class   uuid;
  v_conquest             uuid;
  v_redemption           uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_conquest;
  select id into strict v_conquest
  from public.subclasses
  where class_id = v_class and name = c_conquest and campaign_id is null;

  v_seeking := 'subclass ' || c_redemption;
  select id into strict v_redemption
  from public.subclasses
  where class_id = v_class and name = c_redemption and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Oath of Conquest --------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_conquest::uuid, 3, 'Oath Spells',
       'Always prepared, not counted against your total; the levels are '
       'paladin levels. 3rd: armor of Agathys, command. 5th: hold person, '
       'spiritual weapon. 9th: bestow curse, fear. 13th: dominate beast, '
       'stoneskin. 17th: cloudkill, dominate person.'),
      (v_conquest, 3, 'Channel Divinity: Conquering Presence',
       'Action: creatures of your choice within 30 feet make a Wisdom save '
       'or are frightened of you for 1 minute, repeating the save at the end '
       'of each of their turns.'),
      (v_conquest, 3, 'Channel Divinity: Guided Strike',
       'When you make an attack roll, add +10 to it, after seeing the roll '
       'but before knowing whether it hits.'),
      (v_conquest, 7, 'Aura of Conquest',
       'While you aren''t incapacitated, a creature frightened of you within '
       '10 feet (30 feet at 18th level) has speed 0, and takes psychic '
       'damage equal to half your paladin level if it starts its turn there.'),
      (v_conquest, 15, 'Scornful Rebuke',
       'When a creature hits you with an attack, it takes psychic damage '
       'equal to your Charisma modifier (minimum 1), unless you are '
       'incapacitated.'),
      (v_conquest, 20, 'Invincible Conqueror',
       'Action, for 1 minute: resistance to all damage, one extra attack '
       'when you take the Attack action, and your melee weapon attacks crit '
       'on a 19 or 20. Once per long rest.'),
      -- ---- Oath of Redemption ------------------------------------------------
      (v_redemption, 3, 'Oath Spells',
       'Always prepared, not counted against your total; the levels are '
       'paladin levels. 3rd: sanctuary, sleep. 5th: calm emotions, hold '
       'person. 9th: counterspell, hypnotic pattern. 13th: Otiluke''s '
       'resilient sphere, stoneskin. 17th: hold monster, wall of force.'),
      (v_redemption, 3, 'Channel Divinity: Emissary of Peace',
       'Bonus action: +5 to Charisma (Persuasion) checks for 10 minutes.'),
      (v_redemption, 3, 'Channel Divinity: Rebuke the Violent',
       'Reaction: right after an attacker within 30 feet damages a creature '
       'other than you, it makes a Wisdom save, taking radiant damage equal '
       'to the damage it dealt, or half on a success.'),
      (v_redemption, 7, 'Aura of the Guardian',
       'Reaction: when a creature within 10 feet (30 feet at 18th level) '
       'takes damage, you take it instead. Other effects of the attack still '
       'apply to the creature.'),
      (v_redemption, 15, 'Protective Spirit',
       'At the end of your turn, if you are below half your hit point '
       'maximum and not incapacitated, regain 1d6 + half your paladin level '
       'hit points.'),
      (v_redemption, 20, 'Emissary of Redemption',
       'Resistance to all damage other creatures deal, and a creature that '
       'hits you takes radiant damage equal to half the damage you took. You '
       'lose both against a creature you attack, force to save or damage, '
       'until you finish a long rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_conquest and campaign_id is null;
  if v_count <> c_conquest_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_conquest, v_count, c_conquest_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_redemption and campaign_id is null;
  if v_count <> c_redemption_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_redemption, v_count, c_redemption_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_conquest, v_redemption);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 073 the Paladin''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('109');

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
   where c.name = 'Paladin' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Oath of Conquest', 'Oath of Redemption')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 7, 15, 20]::smallint[]
     from f where subclass = 'Oath of Conquest')              as conquest_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 7, 15, 20]::smallint[]
     from f where subclass = 'Oath of Redemption')            as redemption_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '109')                                            as ledger_row;

rollback;

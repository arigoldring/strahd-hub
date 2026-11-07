-- db/155_resources_martial.sql
--
-- Use counters for the Barbarian, Monk, Paladin, Ranger and Rogue: 40 rows
-- in 153's feature_resources, 154's shape. RUN 153 FIRST. Each row is a
-- feature whose own text says it recharges on a rest, base class and every
-- seeded archetype. Highlights:
--
--   Rage            2 per long rest; 3 at 3rd, 4 at 6th, 5 at 12th, 6 at
--                   17th. Unlimited at 20th, which is a step to 0: the sheet
--                   hides a counter at 0, and an unlimited one needs no
--                   counting.
--   Ki Points       monk level per short rest (Ki is a 2nd-level feature,
--                   so it starts there)
--   Divine Sense    1 + CHA modifier per long rest
--   Lay on Hands    5 x paladin level, a pool: the sheet shows an amount
--                   field above 10 uses, not pips
--   Channel Divinity (Paladin) 1 per short rest
--   Soulknife       Psionic Energy Dice (twice proficiency bonus) and
--                   Psychic Whispers' free use, 154's Psi Warrior shape
--
-- Left out, and why (KNOWN_ISSUES, "Use counters and rests"):
--   * Partial recoveries: Psionic Power's one die per short rest.
--   * Not a spend: Relentless Rage's DC, Slayer's Prey's mark, Bestial
--     Soul's and Whispers of the Dead's after-rest choice, Tranquility,
--     Emissary of Redemption.
--   * Options of a feature that already counts: the Channel Divinity
--     options of each oath spend Channel Divinity.
--
-- class_features and feature_resources have no write policy for shared rows,
-- so this is a plain INSERT as the table owner (121's shape).
--
-- AFTERWARDS: nothing. No schema changes, so no reload or gen:types.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  c_expected constant int := 40;
  r         record;
  v_seeking text;
  v_feature uuid;
  v_count   int;
begin
  for r in
    select * from (values
      -- (class, subclass or null, feature, counter, recharge, short_rest_from,
      --  formula, ability, multiplier, bonus, step levels, step totals, sort)
      ('Barbarian', null::text, 'Rage', 'Rage', 'long', null::smallint,
       'steps', null::text, 1, 0, '{1,3,6,12,17,20}'::smallint[], '{2,3,4,5,6,0}'::smallint[], 0),
      ('Barbarian', 'Path of the Ancestral Guardian', 'Consult the Spirits', 'Consult the Spirits', 'short', null,
       'steps', null, 1, 0, '{10}', '{1}', 0),
      ('Barbarian', 'Path of the Zealot', 'Zealous Presence', 'Zealous Presence', 'long', null,
       'steps', null, 1, 0, '{10}', '{1}', 0),
      ('Barbarian', 'Path of the Beast', 'Infectious Fury', 'Infectious Fury', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Barbarian', 'Path of the Beast', 'Call the Hunt', 'Call the Hunt', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Barbarian', 'Path of Wild Magic', 'Magic Awareness', 'Magic Awareness', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Barbarian', 'Path of Wild Magic', 'Bolstering Magic', 'Bolstering Magic', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Monk', null, 'Ki', 'Ki Points', 'short', null,
       'level', null, 1, 0, '{}', '{}', 0),
      ('Monk', 'Way of the Open Hand', 'Wholeness of Body', 'Wholeness of Body', 'long', null,
       'steps', null, 1, 0, '{6}', '{1}', 0),
      ('Monk', 'Way of Mercy', 'Hand of Ultimate Mercy', 'Hand of Ultimate Mercy', 'long', null,
       'steps', null, 1, 0, '{17}', '{1}', 0),
      ('Paladin', null, 'Divine Sense', 'Divine Sense', 'long', null,
       'ability', 'cha', 1, 1, '{}', '{}', 0),
      ('Paladin', null, 'Lay on Hands', 'Lay on Hands Pool', 'long', null,
       'level', null, 5, 0, '{}', '{}', 0),
      ('Paladin', null, 'Channel Divinity', 'Channel Divinity', 'short', null,
       'steps', null, 1, 0, '{3}', '{1}', 0),
      ('Paladin', null, 'Cleansing Touch', 'Cleansing Touch', 'long', null,
       'ability', 'cha', 1, 0, '{}', '{}', 0),
      ('Paladin', 'Oath of Devotion', 'Holy Nimbus', 'Holy Nimbus', 'long', null,
       'steps', null, 1, 0, '{20}', '{1}', 0),
      ('Paladin', 'Oath of the Ancients', 'Undying Sentinel', 'Undying Sentinel', 'long', null,
       'steps', null, 1, 0, '{15}', '{1}', 0),
      ('Paladin', 'Oath of the Ancients', 'Elder Champion', 'Elder Champion', 'long', null,
       'steps', null, 1, 0, '{20}', '{1}', 0),
      ('Paladin', 'Oath of Vengeance', 'Avenging Angel', 'Avenging Angel', 'long', null,
       'steps', null, 1, 0, '{20}', '{1}', 0),
      ('Paladin', 'Oath of Conquest', 'Invincible Conqueror', 'Invincible Conqueror', 'long', null,
       'steps', null, 1, 0, '{20}', '{1}', 0),
      ('Paladin', 'Oath of Glory', 'Glorious Defense', 'Glorious Defense', 'long', null,
       'ability', 'cha', 1, 0, '{}', '{}', 0),
      ('Paladin', 'Oath of Glory', 'Living Legend', 'Living Legend', 'long', null,
       'steps', null, 1, 0, '{20}', '{1}', 0),
      ('Paladin', 'Oath of the Watchers', 'Mortal Bulwark', 'Mortal Bulwark', 'long', null,
       'steps', null, 1, 0, '{20}', '{1}', 0),
      ('Ranger', 'Horizon Walker', 'Detect Portal', 'Detect Portal', 'short', null,
       'steps', null, 1, 0, '{3}', '{1}', 0),
      ('Ranger', 'Horizon Walker', 'Ethereal Step', 'Ethereal Step', 'short', null,
       'steps', null, 1, 0, '{7}', '{1}', 0),
      ('Ranger', 'Monster Slayer', 'Hunter''s Sense', 'Hunter''s Sense', 'long', null,
       'ability', 'wis', 1, 0, '{}', '{}', 0),
      ('Ranger', 'Monster Slayer', 'Magic-User''s Nemesis', 'Magic-User''s Nemesis', 'short', null,
       'steps', null, 1, 0, '{11}', '{1}', 0),
      ('Ranger', 'Fey Wanderer', 'Fey Reinforcements', 'Fey Reinforcements', 'long', null,
       'steps', null, 1, 0, '{11}', '{1}', 0),
      ('Ranger', 'Fey Wanderer', 'Misty Wanderer', 'Misty Wanderer', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Ranger', 'Swarmkeeper', 'Writhing Tide', 'Writhing Tide', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Ranger', 'Swarmkeeper', 'Swarming Dispersal', 'Swarming Dispersal', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Rogue', null, 'Stroke of Luck', 'Stroke of Luck', 'short', null,
       'steps', null, 1, 0, '{20}', '{1}', 0),
      ('Rogue', 'Arcane Trickster', 'Spell Thief', 'Spell Thief', 'long', null,
       'steps', null, 1, 0, '{17}', '{1}', 0),
      ('Rogue', 'Inquisitive', 'Unerring Eye', 'Unerring Eye', 'long', null,
       'ability', 'wis', 1, 0, '{}', '{}', 0),
      ('Rogue', 'Swashbuckler', 'Master Duelist', 'Master Duelist', 'short', null,
       'steps', null, 1, 0, '{17}', '{1}', 0),
      ('Rogue', 'Phantom', 'Wails from the Grave', 'Wails from the Grave', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Rogue', 'Phantom', 'Ghost Walk', 'Ghost Walk', 'long', null,
       'steps', null, 1, 0, '{13}', '{1}', 0),
      ('Rogue', 'Soulknife', 'Psionic Power', 'Psionic Energy Dice', 'long', null,
       'proficiency', null, 2, 0, '{}', '{}', 0),
      ('Rogue', 'Soulknife', 'Psionic Power', 'Psychic Whispers (free)', 'long', null,
       'steps', null, 1, 0, '{3}', '{1}', 1),
      ('Rogue', 'Soulknife', 'Psychic Veil', 'Psychic Veil', 'long', null,
       'steps', null, 1, 0, '{13}', '{1}', 0),
      ('Rogue', 'Soulknife', 'Rend Mind', 'Rend Mind', 'long', null,
       'steps', null, 1, 0, '{17}', '{1}', 0)
    ) as v(class, subclass, feature, counter, recharge, short_rest_from,
           formula, ability, multiplier, bonus, step_levels, step_totals, sort)
  loop
    v_seeking := format('%s / %s / %s', r.class, coalesce(r.subclass, 'base class'), r.feature);
    select f.id into strict v_feature
      from public.class_features f
      join public.classes k on k.id = f.class_id
      left join public.subclasses s on s.id = f.subclass_id
     where k.name = r.class and k.campaign_id is null
       and f.campaign_id is null
       and f.name = r.feature
       and s.name is not distinct from r.subclass;

    insert into public.feature_resources
      (feature_id, name, recharge, short_rest_from, formula, ability,
       multiplier, bonus, step_levels, step_totals, sort)
    values
      (v_feature, r.counter, r.recharge, r.short_rest_from, r.formula, r.ability,
       r.multiplier, r.bonus, r.step_levels, r.step_totals, r.sort);
  end loop;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
    from public.feature_resources fr
    join public.class_features f on f.id = fr.feature_id
    join public.classes k on k.id = f.class_id
   where k.campaign_id is null and k.name in ('Barbarian', 'Monk', 'Paladin', 'Ranger', 'Rogue');
  if v_count <> c_expected then
    raise exception 'Barbarian, Monk, Paladin, Ranger, Rogue: % counters (expected %). Rolled back.',
      v_count, c_expected;
  end if;
exception
  when no_data_found then
    raise exception 'Found no shared feature %. 084, 088-091, 097-098 and 107-114 seed them. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one shared feature %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('155');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the counters and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

with c as (
  select fr.*
    from public.feature_resources fr
    join public.class_features f on f.id = fr.feature_id
    join public.classes k on k.id = f.class_id
   where k.campaign_id is null and k.name in ('Barbarian', 'Monk', 'Paladin', 'Ranger', 'Rogue')
)
select
  (select count(*) = 40 from c)                               as counters_40,
  (select count(*) = 8 from c where recharge = 'short') as short_8,
  (select count(*) = 1 from public.schema_migrations
    where version = '155')                               as ledger_row;

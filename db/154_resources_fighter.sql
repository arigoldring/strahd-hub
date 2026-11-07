-- db/154_resources_fighter.sql
--
-- The Fighter's use counters, the first rows in 153's feature_resources.
-- RUN 153 FIRST. Every Fighter row whose text says it recharges on a rest,
-- base class and all six seeded archetypes:
--
--   Second Wind           1 per short rest
--   Action Surge          1 per short rest, 2 from 17th
--   Indomitable           1 per long rest, 2 from 13th, 3 from 17th
--   Superiority Dice      Battle Master: 4 per short rest, 5 from 7th, 6 from 15th
--   Arcane Shot           Arcane Archer: 2 per short rest
--   Unwavering Mark       Cavalier: STR modifier (min 1) bonus attacks per long rest
--   Warding Maneuver      Cavalier: CON modifier (min 1) per long rest
--   Fighting Spirit       Samurai: 3 per long rest
--   Strength before Death Samurai 18th: 1 per long rest
--   Psionic Energy Dice   Psi Warrior: twice proficiency bonus per long rest
--   Telekinetic Movement  Psi Warrior: 1 per short rest (on Psionic Power)
--   Psi-Powered Leap      Psi Warrior 7th: 1 per short rest (on Telekinetic Adept)
--   Bulwark of Force      Psi Warrior 15th: 1 per long rest
--   Telekinetic Master    Psi Warrior 18th: 1 per long rest
--   Giant's Might         Rune Knight: proficiency bonus per long rest
--   Runic Shield          Rune Knight 7th: proficiency bonus per long rest
--
-- NOT A COUNTER: Rune Carver. Each rune's active effect is its own once per
-- short rest (twice from 15th), so the honest model is one counter per rune
-- the character has picked, and a pick isn't a feature row. KNOWN_ISSUES
-- ("Use counters and rests"). Psionic Power's "regain one die as a bonus
-- action" and the regain-on-initiative features are partial recoveries, done
-- by hand (same entry). The Eldritch Knight's slots come with the slot work.
--
-- A counter's name is the feature's own unless the feature gives more than
-- one, or the thing spent has its own name (superiority dice, psionic energy
-- dice).
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
  c_class constant text := 'Fighter';
  r         record;
  v_seeking text;
  v_feature uuid;
  v_rows    int := 0;
  v_count   int;
begin
  for r in
    select * from (values
      -- (subclass or null, feature, counter, recharge, short_rest_from,
      --  formula, ability, multiplier, bonus, step levels, step totals, sort)
      (null::text, 'Second Wind', 'Second Wind', 'short', null::smallint,
       'steps', null::text, 1, 0, '{1}'::smallint[], '{1}'::smallint[], 0),
      (null, 'Action Surge', 'Action Surge', 'short', null,
       'steps', null, 1, 0, '{2,17}', '{1,2}', 0),
      (null, 'Indomitable', 'Indomitable', 'long', null,
       'steps', null, 1, 0, '{9,13,17}', '{1,2,3}', 0),
      ('Battle Master', 'Combat Superiority', 'Superiority Dice', 'short', null,
       'steps', null, 1, 0, '{3,7,15}', '{4,5,6}', 0),
      ('Arcane Archer', 'Arcane Shot', 'Arcane Shot', 'short', null,
       'steps', null, 1, 0, '{3}', '{2}', 0),
      ('Cavalier', 'Unwavering Mark', 'Unwavering Mark', 'long', null,
       'ability', 'str', 1, 0, '{}', '{}', 0),
      ('Cavalier', 'Warding Maneuver', 'Warding Maneuver', 'long', null,
       'ability', 'con', 1, 0, '{}', '{}', 0),
      ('Samurai', 'Fighting Spirit', 'Fighting Spirit', 'long', null,
       'steps', null, 1, 0, '{3}', '{3}', 0),
      ('Samurai', 'Strength before Death', 'Strength before Death', 'long', null,
       'steps', null, 1, 0, '{18}', '{1}', 0),
      ('Psi Warrior', 'Psionic Power', 'Psionic Energy Dice', 'long', null,
       'proficiency', null, 2, 0, '{}', '{}', 0),
      ('Psi Warrior', 'Psionic Power', 'Telekinetic Movement', 'short', null,
       'steps', null, 1, 0, '{3}', '{1}', 1),
      ('Psi Warrior', 'Telekinetic Adept', 'Psi-Powered Leap', 'short', null,
       'steps', null, 1, 0, '{7}', '{1}', 0),
      ('Psi Warrior', 'Bulwark of Force', 'Bulwark of Force', 'long', null,
       'steps', null, 1, 0, '{15}', '{1}', 0),
      ('Psi Warrior', 'Telekinetic Master', 'Telekinetic Master', 'long', null,
       'steps', null, 1, 0, '{18}', '{1}', 0),
      ('Rune Knight', 'Giant''s Might', 'Giant''s Might', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Rune Knight', 'Runic Shield', 'Runic Shield', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0)
    ) as v(subclass, feature, counter, recharge, short_rest_from,
           formula, ability, multiplier, bonus, step_levels, step_totals, sort)
  loop
    v_seeking := format('%s / %s / %s', c_class, coalesce(r.subclass, 'base class'), r.feature);
    select f.id into strict v_feature
      from public.class_features f
      join public.classes k on k.id = f.class_id
      left join public.subclasses s on s.id = f.subclass_id
     where k.name = c_class and k.campaign_id is null
       and f.campaign_id is null
       and f.name = r.feature
       and s.name is not distinct from r.subclass;

    insert into public.feature_resources
      (feature_id, name, recharge, short_rest_from, formula, ability,
       multiplier, bonus, step_levels, step_totals, sort)
    values
      (v_feature, r.counter, r.recharge, r.short_rest_from, r.formula, r.ability,
       r.multiplier, r.bonus, r.step_levels, r.step_totals, r.sort);
    v_rows := v_rows + 1;
  end loop;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
    from public.feature_resources fr
    join public.class_features f on f.id = fr.feature_id
    join public.classes k on k.id = f.class_id
   where k.name = c_class and k.campaign_id is null;
  if v_count <> v_rows or v_count <> 16 then
    raise exception '% has % counters (expected 16). Rolled back.', c_class, v_count;
  end if;
exception
  when no_data_found then
    raise exception 'Found no shared feature %. 080-082, 105 and 106 seed them. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one shared feature %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('154');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the counters and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

with fighter as (
  select fr.*
    from public.feature_resources fr
    join public.class_features f on f.id = fr.feature_id
    join public.classes k on k.id = f.class_id
   where k.name = 'Fighter' and k.campaign_id is null
)
select
  (select count(*) = 16 from fighter)                                as counters_16,
  (select count(*) = 6 from fighter where recharge = 'short')        as short_6,
  (select step_totals = '{1,2}' from fighter
    where name = 'Action Surge')                                     as action_surge,
  (select formula = 'proficiency' and multiplier = 2 from fighter
    where name = 'Psionic Energy Dice')                              as psionic_dice,
  (select count(*) = 1 from public.schema_migrations
    where version = '154')                                           as ledger_row;

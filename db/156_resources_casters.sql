-- db/156_resources_casters.sql
--
-- Use counters for the Bard, Cleric, Druid, Sorcerer, Warlock, Wizard and
-- Artificer: 80 rows in 153's feature_resources, 154's shape. RUN 153 FIRST.
-- Each row is a feature whose own text says it recharges on a rest, base
-- class and every seeded archetype. Spell slots and Pact Magic are not here:
-- they come from a slot table in rules.ts keyed on 158's caster_type.
-- Highlights:
--
--   Bardic Inspiration  CHA modifier (min 1) per long rest, and per short
--                       rest from 5th (Font of Inspiration), the one row
--                       using short_rest_from
--   Channel Divinity    (Cleric) 1 per short rest; 2 at 6th, 3 at 18th
--   Wild Shape          2 per short rest
--   Sorcery Points      sorcerer level per long rest, from 2nd
--   Mystic Arcanum      one counter per arcanum level (6th at 11th, 7th at
--                       13th, 8th at 15th, 9th at 17th), each once per long
--                       rest. One counter for all four would let a 9th-level
--                       arcanum be "spent" twice.
--   Signature Spells    two spells, each once per short rest, as one counter
--                       of 2. The sheet can't tell which spell was cast.
--   Portent Rolls       2 per long rest, 3 from 14th (Greater Portent)
--   Pools of dice       Balm of the Summer Court (druid level d6s), Healing
--                       Light (1 + warlock level d6s)
--   Spell-Storing Item  twice INT modifier. The book's minimum is 2; 153's
--                       floor is 1, which differs only for an 11th-level
--                       artificer with INT 11 or less.
--
-- Left out, and why (KNOWN_ISSUES, "Use counters and rests"):
--   * Partial recoveries: Arcane Recovery and Natural Recovery are counted
--     (once a day), but the slots they return are given back by hand.
--     Sorcerous Restoration's 4 points and War Magic's Power Surge likewise.
--   * Not a spend: Divine Intervention (7 days, not a rest), Blessing of
--     the Forge, Hex Warrior, Fiendish Resilience, Celestial Resilience, the
--     Order of Scribes' scroll, Hypnotic Gaze's per-creature limit, Master
--     Transmuter (it destroys the stone), Limited Wish (1d4 long rests).
--   * "Or again by spending a slot / sorcery points": the counter tracks
--     the free use; spending the slot is the player's.
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
  c_expected constant int := 80;
  r         record;
  v_seeking text;
  v_feature uuid;
  v_count   int;
begin
  for r in
    select * from (values
      -- (class, subclass or null, feature, counter, recharge, short_rest_from,
      --  formula, ability, multiplier, bonus, step levels, step totals, sort)
      ('Bard', null::text, 'Bardic Inspiration', 'Bardic Inspiration', 'long', 5::smallint,
       'ability', 'cha'::text, 1, 0, '{}'::smallint[], '{}'::smallint[], 0),
      ('Bard', 'College of Glamour', 'Enthralling Performance', 'Enthralling Performance', 'short', null,
       'steps', null, 1, 0, '{3}', '{1}', 0),
      ('Bard', 'College of Glamour', 'Mantle of Majesty', 'Mantle of Majesty', 'long', null,
       'steps', null, 1, 0, '{6}', '{1}', 0),
      ('Bard', 'College of Glamour', 'Unbreakable Majesty', 'Unbreakable Majesty', 'short', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Bard', 'College of Whispers', 'Words of Terror', 'Words of Terror', 'short', null,
       'steps', null, 1, 0, '{3}', '{1}', 0),
      ('Bard', 'College of Whispers', 'Mantle of Whispers', 'Mantle of Whispers', 'short', null,
       'steps', null, 1, 0, '{6}', '{1}', 0),
      ('Bard', 'College of Whispers', 'Shadow Lore', 'Shadow Lore', 'long', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Bard', 'College of Creation', 'Performance of Creation', 'Performance of Creation', 'long', null,
       'steps', null, 1, 0, '{3}', '{1}', 0),
      ('Bard', 'College of Creation', 'Animating Performance', 'Animating Performance', 'long', null,
       'steps', null, 1, 0, '{6}', '{1}', 0),
      ('Bard', 'College of Eloquence', 'Universal Speech', 'Universal Speech', 'long', null,
       'steps', null, 1, 0, '{6}', '{1}', 0),
      ('Bard', 'College of Eloquence', 'Infectious Inspiration', 'Infectious Inspiration', 'long', null,
       'ability', 'cha', 1, 0, '{}', '{}', 0),
      ('Cleric', null, 'Channel Divinity', 'Channel Divinity', 'short', null,
       'steps', null, 1, 0, '{2,6,18}', '{1,2,3}', 0),
      ('Cleric', 'Knowledge Domain', 'Visions of the Past', 'Visions of the Past', 'short', null,
       'steps', null, 1, 0, '{17}', '{1}', 0),
      ('Cleric', 'Light Domain', 'Warding Flare', 'Warding Flare', 'long', null,
       'ability', 'wis', 1, 0, '{}', '{}', 0),
      ('Cleric', 'Tempest Domain', 'Wrath of the Storm', 'Wrath of the Storm', 'long', null,
       'ability', 'wis', 1, 0, '{}', '{}', 0),
      ('Cleric', 'War Domain', 'War Priest', 'War Priest', 'long', null,
       'ability', 'wis', 1, 0, '{}', '{}', 0),
      ('Cleric', 'Grave Domain', 'Eyes of the Grave', 'Eyes of the Grave', 'long', null,
       'ability', 'wis', 1, 0, '{}', '{}', 0),
      ('Cleric', 'Grave Domain', 'Sentinel at Death''s Door', 'Sentinel at Death''s Door', 'long', null,
       'ability', 'wis', 1, 0, '{}', '{}', 0),
      ('Cleric', 'Order Domain', 'Embodiment of the Law', 'Embodiment of the Law', 'long', null,
       'ability', 'wis', 1, 0, '{}', '{}', 0),
      ('Cleric', 'Peace Domain', 'Emboldening Bond', 'Emboldening Bond', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Cleric', 'Twilight Domain', 'Eyes of Night', 'Eyes of Night', 'long', null,
       'steps', null, 1, 0, '{1}', '{1}', 0),
      ('Cleric', 'Twilight Domain', 'Steps of Night', 'Steps of Night', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Druid', null, 'Wild Shape', 'Wild Shape', 'short', null,
       'steps', null, 1, 0, '{2}', '{2}', 0),
      ('Druid', 'Circle of the Land', 'Natural Recovery', 'Natural Recovery', 'long', null,
       'steps', null, 1, 0, '{2}', '{1}', 0),
      ('Druid', 'Circle of Dreams', 'Balm of the Summer Court', 'Balm Dice', 'long', null,
       'level', null, 1, 0, '{}', '{}', 0),
      ('Druid', 'Circle of Dreams', 'Hidden Paths', 'Hidden Paths', 'long', null,
       'ability', 'wis', 1, 0, '{}', '{}', 0),
      ('Druid', 'Circle of Dreams', 'Walker in Dreams', 'Walker in Dreams', 'long', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Druid', 'Circle of the Shepherd', 'Spirit Totem', 'Spirit Totem', 'short', null,
       'steps', null, 1, 0, '{2}', '{1}', 0),
      ('Druid', 'Circle of the Shepherd', 'Faithful Summons', 'Faithful Summons', 'long', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Druid', 'Circle of Spores', 'Fungal Infestation', 'Fungal Infestation', 'long', null,
       'ability', 'wis', 1, 0, '{}', '{}', 0),
      ('Druid', 'Circle of Stars', 'Star Map', 'Free Guiding Bolt', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Druid', 'Circle of Stars', 'Cosmic Omen', 'Cosmic Omen', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Druid', 'Circle of Wildfire', 'Cauterizing Flames', 'Cauterizing Flames', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Druid', 'Circle of Wildfire', 'Blazing Revival', 'Blazing Revival', 'long', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Sorcerer', null, 'Font of Magic', 'Sorcery Points', 'long', null,
       'level', null, 1, 0, '{}', '{}', 0),
      ('Sorcerer', 'Wild Magic', 'Tides of Chaos', 'Tides of Chaos', 'long', null,
       'steps', null, 1, 0, '{1}', '{1}', 0),
      ('Sorcerer', 'Divine Soul', 'Favored by the Gods', 'Favored by the Gods', 'short', null,
       'steps', null, 1, 0, '{1}', '{1}', 0),
      ('Sorcerer', 'Divine Soul', 'Unearthly Recovery', 'Unearthly Recovery', 'long', null,
       'steps', null, 1, 0, '{18}', '{1}', 0),
      ('Sorcerer', 'Shadow Magic', 'Strength of the Grave', 'Strength of the Grave', 'long', null,
       'steps', null, 1, 0, '{1}', '{1}', 0),
      ('Sorcerer', 'Storm Sorcery', 'Wind Soul', 'Wind Soul', 'short', null,
       'steps', null, 1, 0, '{18}', '{1}', 0),
      ('Sorcerer', 'Aberrant Mind', 'Warping Implosion', 'Warping Implosion', 'long', null,
       'steps', null, 1, 0, '{18}', '{1}', 0),
      ('Sorcerer', 'Clockwork Soul', 'Restore Balance', 'Restore Balance', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Sorcerer', 'Clockwork Soul', 'Trance of Order', 'Trance of Order', 'long', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Sorcerer', 'Clockwork Soul', 'Clockwork Cavalcade', 'Clockwork Cavalcade', 'long', null,
       'steps', null, 1, 0, '{18}', '{1}', 0),
      ('Warlock', null, 'Mystic Arcanum', 'Arcanum (6th level)', 'long', null,
       'steps', null, 1, 0, '{11}', '{1}', 0),
      ('Warlock', null, 'Mystic Arcanum', 'Arcanum (7th level)', 'long', null,
       'steps', null, 1, 0, '{13}', '{1}', 1),
      ('Warlock', null, 'Mystic Arcanum', 'Arcanum (8th level)', 'long', null,
       'steps', null, 1, 0, '{15}', '{1}', 2),
      ('Warlock', null, 'Mystic Arcanum', 'Arcanum (9th level)', 'long', null,
       'steps', null, 1, 0, '{17}', '{1}', 3),
      ('Warlock', null, 'Eldritch Master', 'Eldritch Master', 'long', null,
       'steps', null, 1, 0, '{20}', '{1}', 0),
      ('Warlock', 'The Archfey', 'Fey Presence', 'Fey Presence', 'short', null,
       'steps', null, 1, 0, '{1}', '{1}', 0),
      ('Warlock', 'The Archfey', 'Misty Escape', 'Misty Escape', 'short', null,
       'steps', null, 1, 0, '{6}', '{1}', 0),
      ('Warlock', 'The Archfey', 'Dark Delirium', 'Dark Delirium', 'short', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Warlock', 'The Fiend', 'Dark One''s Own Luck', 'Dark One''s Own Luck', 'short', null,
       'steps', null, 1, 0, '{6}', '{1}', 0),
      ('Warlock', 'The Fiend', 'Hurl Through Hell', 'Hurl Through Hell', 'long', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Warlock', 'The Great Old One', 'Entropic Ward', 'Entropic Ward', 'short', null,
       'steps', null, 1, 0, '{6}', '{1}', 0),
      ('Warlock', 'The Celestial', 'Healing Light', 'Healing Light Dice', 'long', null,
       'level', null, 1, 1, '{}', '{}', 0),
      ('Warlock', 'The Celestial', 'Searing Vengeance', 'Searing Vengeance', 'long', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Warlock', 'The Hexblade', 'Hexblade''s Curse', 'Hexblade''s Curse', 'short', null,
       'steps', null, 1, 0, '{1}', '{1}', 0),
      ('Warlock', 'The Hexblade', 'Accursed Specter', 'Accursed Specter', 'long', null,
       'steps', null, 1, 0, '{6}', '{1}', 0),
      ('Warlock', 'The Fathomless', 'Tentacle of the Deeps', 'Tentacle of the Deeps', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Warlock', 'The Fathomless', 'Grasping Tentacles', 'Grasping Tentacles', 'long', null,
       'steps', null, 1, 0, '{10}', '{1}', 0),
      ('Warlock', 'The Fathomless', 'Fathomless Plunge', 'Fathomless Plunge', 'short', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Warlock', 'The Genie', 'Genie''s Vessel', 'Bottled Respite', 'long', null,
       'steps', null, 1, 0, '{1}', '{1}', 0),
      ('Warlock', 'The Genie', 'Elemental Gift', 'Elemental Gift', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Wizard', null, 'Arcane Recovery', 'Arcane Recovery', 'long', null,
       'steps', null, 1, 0, '{1}', '{1}', 0),
      ('Wizard', null, 'Signature Spells', 'Signature Spells', 'short', null,
       'steps', null, 1, 0, '{20}', '{2}', 0),
      ('Wizard', 'School of Abjuration', 'Arcane Ward', 'Arcane Ward', 'long', null,
       'steps', null, 1, 0, '{2}', '{1}', 0),
      ('Wizard', 'School of Conjuration', 'Benign Transposition', 'Benign Transposition', 'long', null,
       'steps', null, 1, 0, '{6}', '{1}', 0),
      ('Wizard', 'School of Divination', 'Portent', 'Portent Rolls', 'long', null,
       'steps', null, 1, 0, '{2,14}', '{2,3}', 0),
      ('Wizard', 'School of Divination', 'The Third Eye', 'The Third Eye', 'short', null,
       'steps', null, 1, 0, '{10}', '{1}', 0),
      ('Wizard', 'School of Evocation', 'Overchannel', 'Overchannel (free use)', 'long', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Wizard', 'School of Illusion', 'Illusory Self', 'Illusory Self', 'short', null,
       'steps', null, 1, 0, '{10}', '{1}', 0),
      ('Wizard', 'School of Transmutation', 'Shapechanger', 'Shapechanger', 'short', null,
       'steps', null, 1, 0, '{10}', '{1}', 0),
      ('Wizard', 'Bladesinging', 'Bladesong', 'Bladesong', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Wizard', 'Order of Scribes', 'Awakened Spellbook', 'Quick Ritual', 'long', null,
       'steps', null, 1, 0, '{2}', '{1}', 0),
      ('Wizard', 'Order of Scribes', 'Manifest Mind', 'Cast Through Manifest Mind', 'long', null,
       'proficiency', null, 1, 0, '{}', '{}', 0),
      ('Wizard', 'Order of Scribes', 'One with the Word', 'One with the Word', 'long', null,
       'steps', null, 1, 0, '{14}', '{1}', 0),
      ('Artificer', null, 'Flash of Genius', 'Flash of Genius', 'long', null,
       'ability', 'int', 1, 0, '{}', '{}', 0),
      ('Artificer', null, 'Spell-Storing Item', 'Spell-Storing Item', 'long', null,
       'ability', 'int', 2, 0, '{}', '{}', 0),
      ('Artificer', 'Battle Smith', 'Arcane Jolt', 'Arcane Jolt', 'long', null,
       'ability', 'int', 1, 0, '{}', '{}', 0)
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
   where k.campaign_id is null and k.name in ('Artificer', 'Bard', 'Cleric', 'Druid', 'Sorcerer', 'Warlock', 'Wizard');
  if v_count <> c_expected then
    raise exception 'Artificer, Bard, Cleric, Druid, Sorcerer, Warlock, Wizard: % counters (expected %). Rolled back.',
      v_count, c_expected;
  end if;
exception
  when no_data_found then
    raise exception 'Found no shared feature %. 085-087, 092-094, 099-104, 115-120 and 150 seed them. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one shared feature %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('156');

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
   where k.campaign_id is null and k.name in ('Artificer', 'Bard', 'Cleric', 'Druid', 'Sorcerer', 'Warlock', 'Wizard')
)
select
  (select count(*) = 80 from c)                               as counters_80,
  (select count(*) = 21 from c where recharge = 'short') as short_21,
  (select count(*) = 1 from public.schema_migrations
    where version = '156')                               as ledger_row;

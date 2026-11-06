-- db/132_magic_items_dmg_g_l.sql
--
-- The DMG's magic items, G-L. Third of eight seed files on 129's columns;
-- 130's header carries the reasoning for all eight. Only what differs:
--
-- Horn of Valhalla and the Instruments of the Bards are one row per variant,
-- because their variants differ in rarity. Each Ioun Stone is its own row for
-- the same reason, named "Ioun Stone (<kind>)" so they sort together.
-- Heward's Handy Haversack and Keoghtom's Ointment use the book's names.
--
-- RUN AS ONE BLOCK. CORRECT OUTPUT: "Success. No rows returned."

begin;

create temp table _seed (
  name                text primary key,
  rarity              text not null,
  requires_attunement boolean not null,
  attunement_note     text,
  tags                text[] not null,
  description         text not null
) on commit drop;

insert into _seed values
($$Gauntlets of Ogre Power$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Your Strength score becomes 19 while you wear them. No effect if it is already 19 or higher.$$),
($$Gem of Brightness$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$50 charges. Spend them to shed light, fire a blinding ray at one creature (DC 15 Constitution) or flare in a 30-foot cone (DC 15). Crumbles when empty.$$),
($$Gem of Seeing$$, 'rare', true, null, array['wondrous item','DMG'],
 $$3 charges. Spend one to gain truesight out to 120 feet for 10 minutes while peering through it. Regains 1d3 at dawn.$$),
($$Giant Slayer$$, 'rare', false, null, array['weapon','DMG'],
 $$Any axe or sword. +1 to attack and damage. Against giants it deals an extra 2d6, and a giant it hits makes a DC 15 Strength save or falls prone.$$),
($$Glamoured Studded Leather$$, 'rare', false, null, array['armor','DMG'],
 $$Studded leather. +1 AC, and as a bonus action you can make it look like any ordinary clothing or armour, though it keeps its weight and feel.$$),
($$Gloves of Missile Snaring$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$When a ranged weapon attack hits you, your reaction reduces the damage by 1d10 + your Dexterity modifier; at 0 you catch the missile if you have a hand free.$$),
($$Gloves of Swimming and Climbing$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Climbing and swimming cost no extra movement, and +5 to Strength (Athletics) checks to climb or swim.$$),
($$Goggles of Night$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Darkvision 60 feet, or an extra 60 feet if you already have it.$$),
($$Hammer of Thunderbolts$$, 'legendary', true, $$for the full effect$$, array['weapon','DMG'],
 $$+1 maul. Attuned, while also wearing a belt of giant strength and gauntlets of ogre power, your Strength rises by 4 (max 30), a giant you hit may die outright (DC 17 Con), and it can be thrown 20/60 to explode in thunder.$$),
($$Hat of Disguise$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Cast disguise self at will while wearing it. The effect ends if the hat is removed.$$),
($$Headband of Intellect$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Your Intelligence score becomes 19 while you wear it. No effect if it is already 19 or higher.$$),
($$Helm of Brilliance$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Studded with gems that cast spells (fireball, daylight, prismatic spray, wall of fire), shed light that harms undead, and give fire resistance; each gem is spent when used. Fire damage can make the remaining gems explode.$$),
($$Helm of Comprehending Languages$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Cast comprehend languages at will while wearing it.$$),
($$Helm of Telepathy$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Cast detect thoughts (DC 13) at will, and speak telepathically to a creature you are focused on. Once per dawn, cast suggestion (DC 13) on that creature.$$),
($$Helm of Teleportation$$, 'rare', true, null, array['wondrous item','DMG'],
 $$3 charges. Spend one to cast teleport. Regains 1d3 at dawn.$$),
($$Heward's Handy Haversack$$, 'rare', false, null, array['wondrous item','DMG'],
 $$A backpack with two side pouches (20 pounds or 2 cubic feet each) and a central pouch (80 pounds or 8 cubic feet). Always weighs 5 pounds, and the item you want is always on top: a bonus action to retrieve.$$),
($$Holy Avenger$$, 'legendary', true, $$by a paladin$$, array['weapon','DMG'],
 $$Any sword. +3 to attack and damage, an extra 2d10 radiant against fiends and undead, and while drawn it projects a 10-foot aura (30 at 17th level) giving you and allies advantage on saves against spells and magical effects.$$),
($$Horn of Blasting$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Blow it as an action for a 30-foot cone of 5d6 thunder and deafening (DC 15 Constitution for half). Glass and crystal take double damage. Each use has a 20% chance to explode, dealing 10d6 fire to you.$$),
($$Horn of Valhalla (Silver)$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Once per week, blow it to summon 2d4 berserker warrior spirits that fight for you for 1 hour.$$),
($$Horn of Valhalla (Brass)$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Summons 3d4 berserker spirits for 1 hour, once per week. Blowing it without proficiency with all simple weapons makes the spirits attack you.$$),
($$Horn of Valhalla (Bronze)$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Summons 4d4 berserker spirits for 1 hour, once per week. Requires proficiency with all medium armour, or the spirits attack you.$$),
($$Horn of Valhalla (Iron)$$, 'legendary', false, null, array['wondrous item','DMG'],
 $$Summons 5d4 berserker spirits for 1 hour, once per week. Requires proficiency with all martial weapons, or the spirits attack you.$$),
($$Horseshoes of a Zephyr$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Worn by a creature, they let it move normally while floating 4 inches above the ground: it can cross liquid, leaves no tracks, and ignores difficult terrain. It needs no rest from forced marching.$$),
($$Horseshoes of Speed$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Increases the walking speed of the creature wearing all four by 30 feet.$$),
($$Immovable Rod$$, 'uncommon', false, null, array['rod','DMG'],
 $$Press its button and it is fixed in place, holding up to 8,000 pounds; a creature can push it with a DC 30 Strength check. Press again to release.$$),
($$Instrument of the Bards (Anstruth Harp)$$, 'very rare', true, $$by a bard$$, array['wondrous item','DMG'],
 $$Lets an attuned bard cast its spells once per dawn each: fly, invisibility, levitate, protection from evil and good, plus cone of cold, control weather and ice storm. Its music imposes disadvantage on saves against your charm spells.$$),
($$Instrument of the Bards (Canaith Mandolin)$$, 'rare', true, $$by a bard$$, array['wondrous item','DMG'],
 $$Lets an attuned bard cast its spells once per dawn each: fly, invisibility, levitate, protection from evil and good, plus cure wounds (3rd level), dispel magic and protection from energy (lightning).$$),
($$Instrument of the Bards (Cli Lyre)$$, 'rare', true, $$by a bard$$, array['wondrous item','DMG'],
 $$Lets an attuned bard cast its spells once per dawn each: fly, invisibility, levitate, protection from evil and good, plus stone shape, wall of fire and wind wall.$$),
($$Instrument of the Bards (Doss Lute)$$, 'uncommon', true, $$by a bard$$, array['wondrous item','DMG'],
 $$Lets an attuned bard cast its spells once per dawn each: fly, invisibility, levitate, protection from evil and good, plus animal friendship, protection from energy (fire) and protection from poison.$$),
($$Instrument of the Bards (Fochlucan Bandore)$$, 'uncommon', true, $$by a bard$$, array['wondrous item','DMG'],
 $$Lets an attuned bard cast its spells once per dawn each: fly, invisibility, levitate, protection from evil and good, plus entangle, faerie fire, shillelagh and speak with animals.$$),
($$Instrument of the Bards (Mac-Fuirmidh Cittern)$$, 'uncommon', true, $$by a bard$$, array['wondrous item','DMG'],
 $$Lets an attuned bard cast its spells once per dawn each: fly, invisibility, levitate, protection from evil and good, plus barkskin, cure wounds and fog cloud.$$),
($$Instrument of the Bards (Ollamh Harp)$$, 'legendary', true, $$by a bard$$, array['wondrous item','DMG'],
 $$Lets an attuned bard cast its spells once per dawn each: fly, invisibility, levitate, protection from evil and good, plus confusion, control weather and fire storm.$$),
($$Ioun Stone (Absorption)$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. As a reaction, cancel a spell of 4th level or lower that targets only you; burns out after cancelling 20 levels of spells.$$),
($$Ioun Stone (Agility)$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. +2 Dexterity, to a maximum of 20.$$),
($$Ioun Stone (Awareness)$$, 'rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. You can't be surprised while it does.$$),
($$Ioun Stone (Fortitude)$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. +2 Constitution, to a maximum of 20.$$),
($$Ioun Stone (Greater Absorption)$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$Orbits your head. As a reaction, cancel a spell of 8th level or lower that targets only you; burns out after cancelling 50 levels of spells.$$),
($$Ioun Stone (Insight)$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. +2 Wisdom, to a maximum of 20.$$),
($$Ioun Stone (Intellect)$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. +2 Intelligence, to a maximum of 20.$$),
($$Ioun Stone (Leadership)$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. +2 Charisma, to a maximum of 20.$$),
($$Ioun Stone (Mastery)$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$Orbits your head. Your proficiency bonus increases by 1.$$),
($$Ioun Stone (Protection)$$, 'rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. +1 bonus to AC.$$),
($$Ioun Stone (Regeneration)$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$Orbits your head. You regain 15 hit points at the end of each hour, provided you have at least 1.$$),
($$Ioun Stone (Reserve)$$, 'rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. Stores up to 3 levels of spells cast into it, which you can then cast from it, as a ring of spell storing.$$),
($$Ioun Stone (Strength)$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. +2 Strength, to a maximum of 20.$$),
($$Ioun Stone (Sustenance)$$, 'rare', true, null, array['wondrous item','DMG'],
 $$Orbits your head. You need no food or drink.$$),
($$Iron Bands of Bilarro$$, 'rare', false, null, array['wondrous item','DMG'],
 $$An iron sphere. Thrown at a Huge or smaller creature within 60 feet (ranged attack), it springs open into bands that restrain it until a DC 20 Strength check breaks them. Once per dawn.$$),
($$Iron Flask$$, 'legendary', false, null, array['wondrous item','DMG'],
 $$As an action, target an extraplanar creature within 60 feet: it makes a DC 17 Wisdom save or is trapped inside. Release it and it serves you for an hour. Holds one creature at a time.$$),
($$Javelin of Lightning$$, 'uncommon', false, null, array['weapon','DMG'],
 $$Magic javelin. Once per dawn, when you throw it and speak its command word, it becomes a 5-foot-wide, 120-foot line of lightning: 4d6 lightning to creatures in it (DC 13 Dexterity for half), plus the javelin's own damage and 4d6 more to the target.$$),
($$Keoghtom's Ointment$$, 'uncommon', false, null, array['wondrous item','consumable','DMG'],
 $$A jar holding 1d4+1 doses. One dose, applied as an action, heals 2d8+2 hit points and cures poison and disease.$$),
($$Lantern of Revealing$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$A hooded lantern that burns 6 hours on a pint of oil. While lit, invisible creatures and objects within 30 feet become visible.$$),
($$Luck Blade$$, 'legendary', true, null, array['weapon','DMG'],
 $$Any sword. +1 to attack and damage and +1 to saves. Once per dawn, reroll an attack, check or save. May hold 1d4-1 charges of wish.$$);

insert into public.items
  (name, description, price_cp, tags, kind,
   rarity, requires_attunement, attunement_note)
select s.name, s.description, 0, s.tags, 'general',
       s.rarity, s.requires_attunement, s.attunement_note
  from _seed s
 where not exists (
   select 1 from public.items i
    where i.campaign_id is null and i.name = s.name
 );

do $do$
declare
  v_expected int := (select count(*) from _seed);
  v_found    int;
begin
  select count(*) into v_found
    from _seed s
    join public.items i
      on i.campaign_id is null
     and i.name = s.name
     and i.rarity = s.rarity
     and i.requires_attunement = s.requires_attunement;
  if v_found <> v_expected then
    raise exception 'magic item seed incomplete: % of % rows present', v_found, v_expected;
  end if;
end
$do$;

insert into public.schema_migrations (version) values ('132');

commit;

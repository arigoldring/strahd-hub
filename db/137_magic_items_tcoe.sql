-- db/137_magic_items_tcoe.sql
--
-- Tasha's Cauldron of Everything's magic items: the class foci, the
-- sorcerers' shards, the wizards' spellbooks and the tattoos. Last of eight
-- seed files on 129's columns; 130's header carries the reasoning for all
-- eight. Only what differs:
--
-- The book's artifacts (Baba Yaga's Mortar and Pestle, the Demonomicon of
-- Iggwilv, the Mighty Servant of Leuk-o, the Teeth of Dahlver-Nar) are left
-- out, as the DMG's are. Every +1/+2/+3 focus is one row per bonus. Barrier
-- Tattoo is one row per tier. Spellwrought Tattoo is 'varies', the third such
-- row after Spell Scroll and the Figurine: it is a scroll you wear, and its
-- rarity is its spell's level in the same way.
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
($$Absorbing Tattoo$$, 'very rare', true, null, array['wondrous item','tattoo','TCoE'],
 $$Tied to one damage type. Resistance to it, and once per dawn your reaction makes you immune to an instance of it and heals you for half the damage it would have dealt.$$),
($$Alchemical Compendium$$, 'rare', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and arcane focus. Once per long rest, change one of your prepared spells to another transmutation from the book. Holds 3 charges to turn a nonmagical object into another of similar size and value.$$),
($$All-Purpose Tool, +1$$, 'uncommon', true, $$by an artificer$$, array['wondrous item','TCoE'],
 $$Any artisan's tool you want, and a spellcasting focus giving +1 to spell attacks and save DC. Once per dawn, channel it to learn a cantrip from any class list for 8 hours.$$),
($$All-Purpose Tool, +2$$, 'rare', true, $$by an artificer$$, array['wondrous item','TCoE'],
 $$Any artisan's tool you want, and a spellcasting focus giving +2 to spell attacks and save DC. Once per dawn, channel it to learn a cantrip from any class list for 8 hours.$$),
($$All-Purpose Tool, +3$$, 'very rare', true, $$by an artificer$$, array['wondrous item','TCoE'],
 $$Any artisan's tool you want, and a spellcasting focus giving +3 to spell attacks and save DC. Once per dawn, channel it to learn a cantrip from any class list for 8 hours.$$),
($$Amulet of the Devout, +1$$, 'uncommon', true, $$by a cleric or paladin$$, array['wondrous item','TCoE'],
 $$A holy symbol giving +1 to spell attacks and save DC. Once per dawn, use Channel Divinity without expending a use.$$),
($$Amulet of the Devout, +2$$, 'rare', true, $$by a cleric or paladin$$, array['wondrous item','TCoE'],
 $$A holy symbol giving +2 to spell attacks and save DC. Once per dawn, use Channel Divinity without expending a use.$$),
($$Amulet of the Devout, +3$$, 'very rare', true, $$by a cleric or paladin$$, array['wondrous item','TCoE'],
 $$A holy symbol giving +3 to spell attacks and save DC. Once per dawn, use Channel Divinity without expending a use.$$),
($$Arcane Grimoire, +1$$, 'uncommon', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and focus giving +1 to spell attacks and save DC. When you use Arcane Recovery, recover one extra slot level.$$),
($$Arcane Grimoire, +2$$, 'rare', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and focus giving +2 to spell attacks and save DC. When you use Arcane Recovery, recover one extra slot level.$$),
($$Arcane Grimoire, +3$$, 'very rare', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and focus giving +3 to spell attacks and save DC. When you use Arcane Recovery, recover one extra slot level.$$),
($$Astral Shard$$, 'rare', true, $$by a sorcerer$$, array['wondrous item','TCoE'],
 $$A sorcerer focus. When you use Metamagic on a spell cast through it, you can teleport up to 30 feet to a space you can see.$$),
($$Astromancy Archive$$, 'uncommon', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and arcane focus. Once per long rest, swap a prepared spell for a divination from the book. 3 charges let your reaction tweak a creature's d20 roll after you see it.$$),
($$Atlas of Endless Horizons$$, 'uncommon', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and arcane focus. Once per long rest, swap a prepared spell for a conjuration from the book. 3 charges let your reaction teleport you 10 feet when hit, possibly turning the hit into a miss.$$),
($$Barrier Tattoo (Uncommon)$$, 'uncommon', true, null, array['wondrous item','tattoo','TCoE'],
 $$While you wear no armour, your AC is 12 + your Dexterity modifier.$$),
($$Barrier Tattoo (Rare)$$, 'rare', true, null, array['wondrous item','tattoo','TCoE'],
 $$While you wear no armour, your AC is 15 + your Dexterity modifier (maximum 2).$$),
($$Barrier Tattoo (Very Rare)$$, 'very rare', true, null, array['wondrous item','tattoo','TCoE'],
 $$While you wear no armour, your AC is 18.$$),
($$Bell Branch$$, 'rare', true, $$by a druid or warlock$$, array['wondrous item','TCoE'],
 $$A druidic focus that chimes when aberrations, celestials, elementals, fey, fiends or undead come within 60 feet. 3 charges: cast protection from evil and good, or summon a beast or fey spirit.$$),
($$Blood Fury Tattoo$$, 'legendary', true, null, array['wondrous item','tattoo','TCoE'],
 $$Your hits deal an extra 4d6 necrotic and heal you by the same amount, up to 10 times per long rest. When a creature within 10 feet damages you, your reaction makes an attack against it with advantage.$$),
($$Bloodwell Vial, +1$$, 'uncommon', true, $$by a sorcerer$$, array['wondrous item','TCoE'],
 $$Holds a drop of your blood. +1 to spell attacks and save DC, and once per dawn, when you roll hit dice to heal, regain 5 sorcery points.$$),
($$Bloodwell Vial, +2$$, 'rare', true, $$by a sorcerer$$, array['wondrous item','TCoE'],
 $$Holds a drop of your blood. +2 to spell attacks and save DC, and once per dawn, when you roll hit dice to heal, regain 5 sorcery points.$$),
($$Bloodwell Vial, +3$$, 'very rare', true, $$by a sorcerer$$, array['wondrous item','TCoE'],
 $$Holds a drop of your blood. +3 to spell attacks and save DC, and once per dawn, when you roll hit dice to heal, regain 5 sorcery points.$$),
($$Cauldron of Rebirth$$, 'very rare', true, $$by a druid or warlock$$, array['wondrous item','TCoE'],
 $$A Tiny pot that grows to a cauldron, and a druid or warlock focus. After a long rest it can brew a potion of greater healing, it serves as the component for scrying, and a corpse laid in it with salt can be returned with raise dead.$$),
($$Coiling Grasp Tattoo$$, 'uncommon', true, null, array['wondrous item','tattoo','TCoE'],
 $$As an action, the tattoo's ink lashes out at a creature within 15 feet: 3d6 force and grappled (DC 14 Strength).$$),
($$Crystalline Chronicle$$, 'very rare', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A crystal spellbook and arcane focus. Once per long rest, swap a prepared spell for an enchantment, divination or illusion from it, and spend its charges to cast a handful of mind-touching spells it holds.$$),
($$Devotee's Censer$$, 'rare', true, $$by a cleric or paladin$$, array['wondrous item','TCoE'],
 $$A flail that deals an extra 1d8 radiant. Once per dawn, release incense in a 10-foot radius for a minute: you and allies there regain 1d4 hit points at the start of each turn.$$),
($$Dragonhide Belt, +1$$, 'uncommon', true, $$by a monk$$, array['wondrous item','TCoE'],
 $$+1 to your ki save DC. Once per dawn, as an action, regain ki points equal to a roll of your Martial Arts die.$$),
($$Dragonhide Belt, +2$$, 'rare', true, $$by a monk$$, array['wondrous item','TCoE'],
 $$+2 to your ki save DC. Once per dawn, as an action, regain ki points equal to a roll of your Martial Arts die.$$),
($$Dragonhide Belt, +3$$, 'very rare', true, $$by a monk$$, array['wondrous item','TCoE'],
 $$+3 to your ki save DC. Once per dawn, as an action, regain ki points equal to a roll of your Martial Arts die.$$),
($$Duplicitous Manuscript$$, 'rare', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and focus that looks like any book you choose to anyone else. Once per long rest, swap a prepared spell for an illusion from it. 3 charges impose disadvantage on a save against your illusion.$$),
($$Eldritch Claw Tattoo$$, 'uncommon', true, null, array['wondrous item','tattoo','TCoE'],
 $$Your unarmed strikes count as magical and gain +1 to attack and damage. Once per dawn, for 1 minute, your melee attacks can reach 15 feet and deal an extra 1d6 force.$$),
($$Elemental Essence Shard$$, 'rare', true, $$by a sorcerer$$, array['wondrous item','TCoE'],
 $$A sorcerer focus attuned to air, earth, fire or water. When you use Metamagic on a spell cast through it, you also gain that element's effect: flight, resistance, extra fire damage or a push.$$),
($$Far Realm Shard$$, 'rare', true, $$by a sorcerer$$, array['wondrous item','TCoE'],
 $$A sorcerer focus. When you use Metamagic on a spell cast through it, one creature hurt by the spell takes 3d6 psychic and may be frightened (Charisma save against your DC).$$),
($$Feywild Shard$$, 'uncommon', true, $$by a sorcerer$$, array['wondrous item','TCoE'],
 $$A sorcerer focus. When you use Metamagic on a spell cast through it, you can roll on the Wild Magic Surge table. Wild magic sorcerers can roll twice on Tides of Chaos' surge and pick.$$),
($$Fulminating Treatise$$, 'rare', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A scorched spellbook and focus. Once per long rest, swap a prepared spell for an evocation from it. 3 charges add 2d6 force to a spell's damage and can knock targets prone.$$),
($$Ghost Step Tattoo$$, 'very rare', true, null, array['wondrous item','tattoo','TCoE'],
 $$3 charges. As a bonus action, become incorporeal until your next turn: resistance to bludgeoning, piercing and slashing, attacks of opportunity against you have disadvantage, and you can move through creatures and objects.$$),
($$Guardian Emblem$$, 'uncommon', true, $$by a cleric or paladin$$, array['wondrous item','TCoE'],
 $$Fixed to armour or a shield. 3 charges: when a creature within 30 feet suffers a critical hit, your reaction turns it into a normal hit. Regains 1d3 at dawn.$$),
($$Heart Weaver's Primer$$, 'very rare', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and focus. Once per long rest, swap a prepared spell for an enchantment from it. 3 charges impose disadvantage on a creature's save against your enchantment.$$),
($$Illuminator's Tattoo$$, 'common', true, null, array['wondrous item','tattoo','TCoE'],
 $$Your writing is magically flawless and you can make it glow. Once per dawn, write a message onto a surface that only a creature you choose can read.$$),
($$Libram of Souls and Flesh$$, 'uncommon', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and focus. Once per long rest, swap a prepared spell for a necromancy from it. 3 charges cast animate dead or wrap you in a disguise of decaying flesh.$$),
($$Lifewell Tattoo$$, 'very rare', true, null, array['wondrous item','tattoo','TCoE'],
 $$Resistance to necrotic damage. Once per dawn, when you would drop to 0 hit points, you drop to 1 instead.$$),
($$Lyre of Building$$, 'uncommon', true, $$by a bard$$, array['wondrous item','TCoE'],
 $$A bardic focus. Cast mending at will from it, shield a structure's stonework and timber from damage with its music, and cast a few building spells, such as wall of stone, once per dawn each.$$),
($$Masquerade Tattoo$$, 'common', true, null, array['wondrous item','tattoo','TCoE'],
 $$Change the tattoo's shape, colour and placement as a bonus action. Once per dawn, cast disguise self from it.$$),
($$Moon Sickle, +1$$, 'uncommon', true, $$by a druid or ranger$$, array['weapon','TCoE'],
 $$A sickle and spellcasting focus. +1 to attack, damage, spell attacks and save DC, and healing spells cast through it heal an extra 1d4.$$),
($$Moon Sickle, +2$$, 'rare', true, $$by a druid or ranger$$, array['weapon','TCoE'],
 $$A sickle and spellcasting focus. +2 to attack, damage, spell attacks and save DC, and healing spells cast through it heal an extra 1d4.$$),
($$Moon Sickle, +3$$, 'very rare', true, $$by a druid or ranger$$, array['weapon','TCoE'],
 $$A sickle and spellcasting focus. +3 to attack, damage, spell attacks and save DC, and healing spells cast through it heal an extra 1d4.$$),
($$Nature's Mantle$$, 'uncommon', true, $$by a druid or ranger$$, array['wondrous item','TCoE'],
 $$A spellcasting focus. While in lightly obscured terrain, you can hide as a bonus action even if observed.$$),
($$Outer Essence Shard$$, 'rare', true, $$by a sorcerer$$, array['wondrous item','TCoE'],
 $$A sorcerer focus, lawful, chaotic, good or evil. When you use Metamagic on a spell cast through it, you can heal or harm a creature hurt by the spell, according to its alignment.$$),
($$Planecaller's Codex$$, 'very rare', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and focus. Once per long rest, swap a prepared spell for a conjuration from it. 3 charges grant creatures you summon maximum hit points and advantage on their first attack.$$),
($$Prosthetic Limb$$, 'common', false, null, array['wondrous item','TCoE'],
 $$Replaces a lost hand, arm, foot, leg or similar part, working exactly like the original. You can attach or detach it as an action, and it can't be removed against your will.$$),
($$Protective Verses$$, 'rare', true, $$by a wizard$$, array['wondrous item','TCoE'],
 $$A spellbook and focus. Once per long rest, swap a prepared spell for an abjuration from it. 3 charges grant temporary hit points equal to your wizard level when you cast an abjuration.$$),
($$Reveler's Concertina$$, 'rare', true, $$by a bard$$, array['wondrous item','TCoE'],
 $$A bardic focus giving +2 to your bard spell save DC. Once per dawn, cast Otto's irresistible dance from it.$$),
($$Rhythm-Maker's Drum, +1$$, 'uncommon', true, $$by a bard$$, array['wondrous item','TCoE'],
 $$A bardic focus giving +1 to spell attacks and save DC. Once per dawn, regain one use of Bardic Inspiration as an action.$$),
($$Rhythm-Maker's Drum, +2$$, 'rare', true, $$by a bard$$, array['wondrous item','TCoE'],
 $$A bardic focus giving +2 to spell attacks and save DC. Once per dawn, regain one use of Bardic Inspiration as an action.$$),
($$Rhythm-Maker's Drum, +3$$, 'very rare', true, $$by a bard$$, array['wondrous item','TCoE'],
 $$A bardic focus giving +3 to spell attacks and save DC. Once per dawn, regain one use of Bardic Inspiration as an action.$$),
($$Shadowfell Brand Tattoo$$, 'rare', true, null, array['wondrous item','tattoo','TCoE'],
 $$Darkvision 60 feet (or 30 more), advantage on Stealth, and once per dawn your reaction halves damage from a hit by fading into shadow.$$),
($$Shadowfell Shard$$, 'rare', true, $$by a sorcerer$$, array['wondrous item','TCoE'],
 $$A sorcerer focus. When you use Metamagic on a spell cast through it, one creature hurt by the spell has disadvantage on one ability's checks and saves until your next turn.$$),
($$Spellwrought Tattoo$$, 'varies', false, null, array['wondrous item','tattoo','consumable','TCoE'],
 $$Holds one spell of up to 5th level, cast once from the tattoo without components, after which the tattoo fades. Rarity, DC and attack bonus scale with the spell's level, from common (cantrip or 1st) to rare (5th).$$),
($$Wraps of Unarmed Power, +1$$, 'uncommon', false, null, array['wondrous item','TCoE'],
 $$+1 to attack and damage rolls with unarmed strikes, which count as magical.$$),
($$Wraps of Unarmed Power, +2$$, 'rare', false, null, array['wondrous item','TCoE'],
 $$+2 to attack and damage rolls with unarmed strikes, which count as magical.$$),
($$Wraps of Unarmed Power, +3$$, 'very rare', false, null, array['wondrous item','TCoE'],
 $$+3 to attack and damage rolls with unarmed strikes, which count as magical.$$);

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

insert into public.schema_migrations (version) values ('137');

commit;

-- db/142_spells_phb_4_5.sql
--
-- Seeds the shared catalogue with the 2014 PHB's 4th- and 5th-level spells that 024 did not
-- (138's header has the map of 138-147).
--
-- Same rules and shape as 139, whose header explains them: own-words
-- summaries with every number kept, upcasting in higher_levels, the book's
-- own class lists (TCoE's additions are 147's), no Artificer, `comp` and the
-- duration deriving the component and concentration flags, a `not exists`
-- guard, and an end-state assertion on level, school, concentration and
-- ritual.
--
-- RUN AS ONE BLOCK. CORRECT OUTPUT: "Success. No rows returned." If the
-- Supabase editor offers to enable RLS, decline (CLAUDE.md).

begin;

create temp table _seed (
  name               text primary key,
  level              int  not null check (level between 0 and 9),
  school             text not null,
  casting_time       text not null,
  range              text not null,
  comp               text not null check (comp ~ '^V?S?M?$' and comp <> ''),
  material_component text,
  duration           text not null,
  ritual             boolean not null,
  classes            text[] not null,
  category           text not null,
  description        text not null,
  higher_levels      text,
  check ((position('M' in comp) > 0) = (material_component is not null))
) on commit drop;

insert into _seed values
-- 4th level ----------------------------------------------------------------
($$Aura of Life$$, 4, 'abjuration', '1 action', 'Self (30-foot radius)', 'V', null, 'Concentration, up to 10 minutes', false,
 array['Paladin'], 'defense',
 $$Each nonhostile creature in a 30-foot aura (you included) has resistance to necrotic damage and can't have its hit point maximum reduced. A nonhostile living creature that starts its turn in the aura at 0 hit points regains 1 hit point.$$, null),
($$Aura of Purity$$, 4, 'abjuration', '1 action', 'Self (30-foot radius)', 'V', null, 'Concentration, up to 10 minutes', false,
 array['Paladin'], 'defense',
 $$Each nonhostile creature in a 30-foot aura (you included) can't become diseased, has resistance to poison damage, and has advantage on saves against being blinded, charmed, deafened, frightened, paralyzed, poisoned or stunned.$$, null),
($$Banishment$$, 4, 'abjuration', '1 action', '60 feet', 'VSM', $$an item distasteful to the target$$, 'Concentration, up to 1 minute', false,
 array['Cleric','Paladin','Sorcerer','Warlock','Wizard'], 'control',
 $$A creature makes a Charisma save or is banished. A creature native to your plane goes to a harmless demiplane, incapacitated, and returns when the spell ends. One from another plane returns to its home plane, and stays there if the spell lasts the full minute.$$,
 $$One additional creature for each slot level above 4th.$$),
($$Compulsion$$, 4, 'enchantment', '1 action', '30 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Bard'], 'control',
 $$Creatures of your choice that can hear you make a Wisdom save (automatic success if they can't be charmed). Until the spell ends, you can use a bonus action to name a direction; each affected creature must use as much movement as it can to go that way on its next turn (it can act before moving). After moving it repeats the save, ending the effect on a success.$$, null),
($$Conjure Minor Elementals$$, 4, 'conjuration', '1 minute', '90 feet', 'VS', null, 'Concentration, up to 1 hour', false,
 array['Druid','Wizard'], 'summoning',
 $$Summon elementals that obey your verbal commands and act on their own initiative: one of challenge rating 2 or lower, two of CR 1, four of CR 1/2, or eight of CR 1/4. The DM has their statistics.$$,
 $$Twice as many with a 6th-level slot, three times as many with an 8th.$$),
($$Conjure Woodland Beings$$, 4, 'conjuration', '1 action', '60 feet', 'VSM', $$one holly berry per creature summoned$$, 'Concentration, up to 1 hour', false,
 array['Druid','Ranger'], 'summoning',
 $$Summon fey that obey your verbal commands and act on their own initiative: one of challenge rating 2 or lower, two of CR 1, four of CR 1/2, or eight of CR 1/4. The DM has their statistics.$$,
 $$Twice as many with a 6th-level slot, three times as many with an 8th.$$),
($$Control Water$$, 4, 'transmutation', '1 action', '300 feet', 'VSM', $$a drop of water and a pinch of dust$$, 'Concentration, up to 10 minutes', false,
 array['Cleric','Druid','Wizard'], 'control',
 $$Control water in an area up to a 100-foot cube, choosing an effect (and changing it with an action): Flood (raise the water 20 feet, or send a wave across a smaller body), Part Water (a trench through it), Redirect Flow, or Whirlpool (in water at least 50 feet square and 25 feet deep; creatures in it make a Strength save or take 2d8 bludgeoning damage and are pulled toward the centre).$$, null),
($$Death Ward$$, 4, 'abjuration', '1 action', 'Touch', 'VS', null, '8 hours', false,
 array['Cleric','Paladin'], 'defense',
 $$The first time the creature would drop to 0 hit points from damage, it drops to 1 instead; or, if an effect would kill it instantly without damage, that effect is negated. The spell then ends.$$, null),
($$Divination$$, 4, 'divination', '1 action', 'Self', 'VSM', $$incense and a sacrificial offering appropriate to your religion, together worth at least 25 gp, which the spell consumes$$, 'Instantaneous', true,
 array['Cleric'], 'detection',
 $$Ask your god or its servants one question about a goal, event or activity within the next 7 days. The DM gives a truthful reply, which may be a short phrase, a riddle or an omen. Each casting after the first before a long rest has a cumulative 25% chance of a random reading.$$, null),
($$Dominate Beast$$, 4, 'enchantment', '1 action', '60 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Druid','Sorcerer'], 'control',
 $$A beast makes a Wisdom save (advantage if you or your companions are fighting it) or is charmed. While it is, you can give it telepathic commands, or use your action to control it precisely, including its reaction. Each time it takes damage it repeats the save.$$,
 $$Up to 10 minutes with a 5th-level slot, 1 hour with a 6th, 8 hours with a 7th or higher.$$),
($$Evard's Black Tentacles$$, 4, 'conjuration', '1 action', '90 feet', 'VSM', $$a piece of tentacle from a giant octopus or a giant squid$$, 'Concentration, up to 1 minute', false,
 array['Wizard'], 'control',
 $$Writhing tentacles fill a 20-foot square, which becomes difficult terrain. A creature that enters it for the first time on a turn or starts its turn there makes a Dexterity save or takes 3d6 bludgeoning damage and is restrained. A restrained creature takes 3d6 bludgeoning damage at the start of each of its turns, and can use its action on a Strength or Dexterity check against your spell save DC to escape.$$, null),
($$Fabricate$$, 4, 'transmutation', '10 minutes', '120 feet', 'VS', null, 'Instantaneous', false,
 array['Wizard'], 'utility',
 $$Turn raw materials into products of the same material: wood into a bridge, flax into clothes, hemp into rope. Up to a Large object (a 10-foot cube, or eight connected 5-foot cubes); a mineral object up to Medium (one 5-foot cube). Quality matches the materials, and fine work like jewellery or weapons needs proficiency with the right artisan's tools.$$, null),
($$Fire Shield$$, 4, 'evocation', '1 action', 'Self', 'VSM', $$a bit of phosphorus or a firefly$$, '10 minutes', false,
 array['Wizard'], 'defense',
 $$Wispy flames wreathe you, shedding bright light for 10 feet and dim light for 10 more. A warm shield gives resistance to cold damage; a chill shield gives resistance to fire damage. A creature within 5 feet that hits you with a melee attack takes 2d8 fire damage (warm) or cold damage (chill).$$, null),
($$Freedom of Movement$$, 4, 'abjuration', '1 action', 'Touch', 'VSM', $$a leather strap, bound around the arm or a similar appendage$$, '1 hour', false,
 array['Bard','Cleric','Druid','Ranger'], 'movement',
 $$The willing creature ignores difficult terrain, and magic can neither reduce its speed nor paralyze or restrain it. It can spend 5 feet of movement to escape nonmagical restraints such as manacles or a grapple, and moving and attacking underwater carries no penalty.$$, null),
($$Giant Insect$$, 4, 'transmutation', '1 action', '30 feet', 'VS', null, 'Concentration, up to 10 minutes', false,
 array['Druid'], 'summoning',
 $$Turn up to ten centipedes, three spiders, five wasps or one scorpion into giant versions of themselves for the duration. They obey your verbal commands and act on their own initiative, reverting when they drop to 0 hit points or the spell ends.$$, null),
($$Grasping Vine$$, 4, 'conjuration', '1 bonus action', '30 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Druid','Ranger'], 'control',
 $$A vine sprouts from the ground in an unoccupied space. When you cast it, and as a bonus action on later turns, it lashes at a creature within 30 feet of it that you can see: Dexterity save or be pulled 20 feet toward the vine.$$, null),
($$Guardian of Faith$$, 4, 'conjuration', '1 action', '30 feet', 'V', null, '8 hours', false,
 array['Cleric'], 'defense',
 $$A Large spectral guardian hovers in an unoccupied space. A hostile creature that moves within 10 feet of it for the first time on a turn makes a Dexterity save, taking 20 radiant damage on a failure or half on a success. It vanishes once it has dealt 60 damage in total.$$, null),
($$Ice Storm$$, 4, 'evocation', '1 action', '300 feet', 'VSM', $$a pinch of dust and a few drops of water$$, 'Instantaneous', false,
 array['Druid','Sorcerer','Wizard'], 'damage',
 $$Hail pounds a 20-foot-radius, 40-foot-high cylinder. Each creature in it makes a Dexterity save, taking 2d8 bludgeoning and 4d6 cold damage on a failure or half on a success. The area is difficult terrain until the end of your next turn.$$,
 $$The bludgeoning damage increases by 1d8 for each slot level above 4th.$$),
($$Leomund's Secret Chest$$, 4, 'conjuration', '1 action', 'Touch', 'VSM', $$an exquisite chest, 3 feet by 2 feet by 2 feet, constructed from rare materials worth at least 5,000 gp, and a Tiny replica made from the same materials worth at least 50 gp$$, 'Instantaneous', false,
 array['Wizard'], 'utility',
 $$Hide a chest and its contents (up to 12 cubic feet) on the Ethereal Plane. Touching the replica as an action recalls it. After 60 days there is a cumulative 5% chance each day that the spell ends and the chest is lost.$$, null),
($$Locate Creature$$, 4, 'divination', '1 action', 'Self', 'VSM', $$a bit of fur from a bloodhound$$, 'Concentration, up to 1 hour', false,
 array['Bard','Cleric','Druid','Paladin','Ranger','Wizard'], 'detection',
 $$Describe or name a creature familiar to you. You sense its direction while it is within 1,000 feet, and can instead seek the nearest creature of a kind. Running water at least 10 feet wide blocks the spell, as does any thickness of lead. A creature in a different form (polymorphed, say) isn't found.$$, null),
($$Mordenkainen's Faithful Hound$$, 4, 'conjuration', '1 action', '30 feet', 'VSM', $$a tiny silver whistle, a piece of bone, and a thread$$, '8 hours', false,
 array['Wizard'], 'defense',
 $$An invisible phantom watchdog guards a spot. It sees invisible creatures and into the Ethereal Plane, and barks loudly when a creature that doesn't speak your password comes within 30 feet. At the start of each of your turns it bites one hostile creature within 5 feet of it, using your spell attack bonus, for 4d8 piercing damage. The spell ends if you go more than 100 feet away.$$, null),
($$Mordenkainen's Private Sanctum$$, 4, 'abjuration', '10 minutes', '120 feet', 'VSM', $$a thin sheet of lead, a piece of opaque glass, a wad of cotton or cloth, and powdered chrysolite$$, '24 hours', false,
 array['Wizard'], 'defense',
 $$Secure an area up to a 100-foot cube. Choose any of: sound can't pass the barrier; it is dark and foggy from outside; divination sensors can't appear inside; creatures inside can't be targeted by divination; nothing can teleport in or out; planar travel is blocked inside. Cast on the same spot every day for a year and it becomes permanent.$$,
 $$The cube can be 100 feet larger on each side for each slot level above 4th.$$),
($$Otiluke's Resilient Sphere$$, 4, 'evocation', '1 action', '30 feet', 'VSM', $$a hemispherical piece of clear crystal and a matching hemispherical piece of gum arabic$$, 'Concentration, up to 1 minute', false,
 array['Wizard'], 'control',
 $$A shimmering sphere encloses a Large or smaller creature or object (an unwilling creature makes a Dexterity save). Nothing can pass through it, physical or magical, though breathing works. The creature inside can roll it at half speed, and others can pick it up. Disintegrate destroys it.$$, null),
($$Phantasmal Killer$$, 4, 'illusion', '1 action', '120 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Wizard'], 'damage',
 $$Pull a creature's deepest fear into an illusion only it can see. It makes a Wisdom save or is frightened for the duration. At the end of each of its turns it repeats the save, taking 4d10 psychic damage on a failure; a success ends the spell.$$,
 $$+1d10 damage for each slot level above 4th.$$),
($$Staggering Smite$$, 4, 'evocation', '1 bonus action', 'Self', 'V', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'damage',
 $$The next time you hit with a melee weapon attack, the target takes an extra 4d6 psychic damage and must succeed on a Wisdom save or have disadvantage on attack rolls and ability checks, and be unable to take reactions, until the end of its next turn.$$, null),
($$Stone Shape$$, 4, 'transmutation', '1 action', 'Touch', 'VSM', $$soft clay, which must be worked into roughly the desired shape of the stone object$$, 'Instantaneous', false,
 array['Cleric','Druid','Wizard'], 'utility',
 $$Reshape a Medium or smaller stone object, or a section of stone no more than 5 feet in any dimension, into any form you like: a weapon, a coffer, a passage through a thin wall, sealing a door. Hinges and fine detail are crude at best.$$, null),
($$Stoneskin$$, 4, 'abjuration', '1 action', 'Touch', 'VSM', $$diamond dust worth 100 gp, which the spell consumes$$, 'Concentration, up to 1 hour', false,
 array['Druid','Ranger','Sorcerer','Wizard'], 'defense',
 $$A willing creature's flesh turns hard as stone, giving it resistance to nonmagical bludgeoning, piercing and slashing damage.$$, null),

-- 5th level ----------------------------------------------------------------
($$Antilife Shell$$, 5, 'abjuration', '1 action', 'Self (10-foot radius)', 'VS', null, 'Concentration, up to 1 hour', false,
 array['Druid'], 'defense',
 $$A barrier extends 10 feet from you and moves with you. Creatures other than undead and constructs can't pass or reach through it, though they can still cast spells and make ranged attacks through it. Moving so that a creature is forced through the barrier ends the spell.$$, null),
($$Awaken$$, 5, 'transmutation', '8 hours', 'Touch', 'VSM', $$an agate worth at least 1,000 gp, which the spell consumes$$, 'Instantaneous', false,
 array['Bard','Druid'], 'utility',
 $$A Huge or smaller beast or plant with Intelligence 3 or lower gains Intelligence 10 and one language you know. A plant can move its limbs and roots and gains senses like a human's. It is charmed by you for 30 days or until harmed, and afterwards chooses how it feels about you.$$, null),
($$Banishing Smite$$, 5, 'abjuration', '1 bonus action', 'Self', 'V', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'damage',
 $$The next time you hit with a weapon attack, the target takes an extra 5d10 force damage. If that leaves it at 50 hit points or fewer, it is banished: a creature native to this plane goes to a harmless demiplane, incapacitated; one from elsewhere goes home. It returns when the spell ends.$$, null),
($$Bigby's Hand$$, 5, 'evocation', '1 action', '120 feet', 'VSM', $$an eggshell and a snakeskin glove$$, 'Concentration, up to 1 minute', false,
 array['Wizard'], 'control',
 $$A Large hand of force appears (AC 20, hit points equal to your hit point maximum, Strength 26, Dexterity 10). When you cast it and as a bonus action later, move it up to 60 feet and choose: Clenched Fist (melee spell attack for 4d8 force); Forceful Hand (push a creature 5 feet plus 5 times your spellcasting modifier, on a contested Strength check); Grasping Hand (grapple a Huge or smaller creature, then crush it for 2d6 + your spellcasting modifier bludgeoning); or Interposing Hand (half cover against one creature).$$,
 $$Clenched fist +2d8 and grasping hand +2d6 for each slot level above 5th.$$),
($$Circle of Power$$, 5, 'abjuration', '1 action', 'Self (30-foot radius)', 'V', null, 'Concentration, up to 10 minutes', false,
 array['Paladin'], 'defense',
 $$Friendly creatures within 30 feet of you (you included) have advantage on saves against spells and other magical effects. When such a creature succeeds on a save against an effect that deals half damage on a success, it takes none.$$, null),
($$Cloudkill$$, 5, 'conjuration', '1 action', '120 feet', 'VS', null, 'Concentration, up to 10 minutes', false,
 array['Sorcerer','Wizard'], 'damage',
 $$A 20-foot-radius sphere of poisonous fog spreads around corners and heavily obscures the area. A creature entering it for the first time on a turn or starting its turn there makes a Constitution save, taking 5d8 poison damage on a failure or half on a success. The cloud drifts 10 feet away from you at the start of each of your turns. Strong wind disperses it.$$,
 $$+1d8 damage for each slot level above 5th.$$),
($$Commune$$, 5, 'divination', '1 minute', 'Self', 'VSM', $$incense and a vial of holy or unholy water$$, '1 minute', true,
 array['Cleric'], 'detection',
 $$Contact your deity or a proxy and ask up to three questions answerable with yes or no. You get correct answers, or "unclear" if the answer can't be known. Each casting after the first before a long rest has a cumulative 25% chance of no answer.$$, null),
($$Commune with Nature$$, 5, 'divination', '1 minute', 'Self', 'VS', null, 'Instantaneous', true,
 array['Druid','Ranger'], 'detection',
 $$Learn up to three facts about the land within 3 miles of you (300 feet underground or in an unnatural setting): terrain and bodies of water, prevalent plants, minerals, animals or peoples, powerful celestials, fey, fiends, elementals or undead, influence from other planes, or buildings.$$, null),
($$Conjure Volley$$, 5, 'conjuration', '1 action', '150 feet', 'VSM', $$one piece of ammunition or one thrown weapon$$, 'Instantaneous', false,
 array['Ranger'], 'damage',
 $$Fire ammunition or throw a weapon into the air, and it rains down as a hail of copies on a 40-foot-radius, 20-foot-high cylinder. Each creature in it makes a Dexterity save, taking 8d8 damage of the weapon's type on a failure or half on a success.$$, null),
($$Contact Other Plane$$, 5, 'divination', '1 minute', 'Self', 'V', null, '1 minute', true,
 array['Warlock','Wizard'], 'detection',
 $$Contact an extraplanar entity. Make a DC 15 Intelligence save: on a failure you take 6d6 psychic damage and are insane until you finish a long rest. On a success you can ask up to five questions; the entity answers each with a word such as "yes", "no", "maybe", "never", "irrelevant" or "unclear".$$, null),
($$Contagion$$, 5, 'necromancy', '1 action', 'Touch', 'VS', null, '7 days', false,
 array['Cleric','Druid'], 'damage',
 $$Make a melee spell attack; on a hit the target is poisoned. At the end of each of its turns it makes a Constitution save: after three failures it stops saving and suffers a disease you chose (Blinding Sickness, Filth Fever, Flesh Rot, Mindfire, Seizure or Slimy Doom) for the duration; after three successes it recovers.$$, null),
($$Creation$$, 5, 'illusion', '1 minute', '30 feet', 'VSM', $$a tiny piece of matter of the same type of the item you plan to create$$, 'Special', false,
 array['Sorcerer','Wizard'], 'utility',
 $$Create a nonliving object of vegetable matter or mineral, no larger than a 5-foot cube, of a form and material you've seen. How long it lasts depends on the material: vegetable matter 1 day, stone or crystal 12 hours, precious metals 1 hour, gems 10 minutes, adamantine or mithral 1 minute. Using it as a spell's material component makes that spell fail.$$,
 $$The cube grows by 5 feet for each slot level above 5th.$$),
($$Destructive Wave$$, 5, 'evocation', '1 action', 'Self (30-foot radius)', 'V', null, 'Instantaneous', false,
 array['Paladin'], 'damage',
 $$Strike the ground and divine energy ripples out. Each creature you choose within 30 feet makes a Constitution save. On a failure it takes 5d6 thunder damage and 5d6 radiant or necrotic damage (your choice) and is knocked prone; on a success it takes half and stays standing.$$, null),
($$Dispel Evil and Good$$, 5, 'abjuration', '1 action', 'Self', 'VSM', $$holy water or powdered silver and iron$$, 'Concentration, up to 1 minute', false,
 array['Cleric','Paladin'], 'defense',
 $$Celestials, elementals, fey, fiends and undead have disadvantage on attack rolls against you. You can end the spell early with one of two effects. Break Enchantment: touch a creature to end its being charmed, frightened or possessed by one of those types. Dismissal: make a melee spell attack against one of them; on a hit it makes a Charisma save or is sent back to its home plane.$$, null),
($$Dream$$, 5, 'illusion', '1 minute', 'Special', 'VSM', $$a handful of sand, a dab of ink, and a writing quill plucked from a sleeping bird$$, '8 hours', false,
 array['Bard','Warlock','Wizard'], 'social',
 $$You or a willing messenger enter the dreams of a creature you know on your plane and talk with it while it sleeps. A messenger can also make the dream a nightmare: the target makes a Wisdom save or gains no benefit from its rest and takes 3d6 psychic damage on waking. Having a body part of the target imposes disadvantage on the save.$$, null),
($$Flame Strike$$, 5, 'evocation', '1 action', '60 feet', 'VSM', $$pinch of sulfur$$, 'Instantaneous', false,
 array['Cleric'], 'damage',
 $$A column of divine fire fills a 10-foot-radius, 40-foot-high cylinder. Each creature in it makes a Dexterity save, taking 4d6 fire damage and 4d6 radiant damage on a failure or half on a success.$$,
 $$The fire or the radiant damage (your choice) increases by 1d6 for each slot level above 5th.$$),
($$Hallow$$, 5, 'evocation', '24 hours', 'Touch', 'VSM', $$herbs, oils, and incense worth at least 1,000 gp, which the spell consumes$$, 'Until dispelled', false,
 array['Cleric'], 'defense',
 $$Consecrate an area up to 60 feet in radius. Celestials, elementals, fey, fiends and undead can't enter it, and can't charm, frighten or possess creatures inside. Bind one extra effect to it, affecting everyone or only those you choose: courage, darkness, daylight, energy protection or vulnerability, everlasting rest for the dead, extradimensional interference, fear, silence or tongues.$$, null),
($$Hold Monster$$, 5, 'enchantment', '1 action', '90 feet', 'VSM', $$a small, straight piece of iron$$, 'Concentration, up to 1 minute', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'control',
 $$A creature you can see makes a Wisdom save or is paralyzed for the duration. Undead are unaffected. It repeats the save at the end of each of its turns.$$,
 $$One additional creature for each slot level above 5th; the targets must be within 30 feet of each other.$$),
($$Insect Plague$$, 5, 'conjuration', '1 action', '300 feet', 'VSM', $$a few grains of sugar, some kernels of grain, and a smear of fat$$, 'Concentration, up to 10 minutes', false,
 array['Cleric','Druid','Sorcerer'], 'damage',
 $$Biting locusts fill a 20-foot-radius sphere, which is lightly obscured and difficult terrain. A creature in it when it appears, entering it for the first time on a turn or ending its turn there makes a Constitution save, taking 4d10 piercing damage on a failure or half on a success.$$,
 $$+1d10 damage for each slot level above 5th.$$),
($$Legend Lore$$, 5, 'divination', '10 minutes', 'Self', 'VSM', $$incense worth at least 250 gp, which the spell consumes, and four ivory strips worth at least 50 gp each$$, 'Instantaneous', false,
 array['Bard','Cleric','Wizard'], 'detection',
 $$Name or describe a person, place or object of legendary importance and learn the significant lore about it: current tales, forgotten stories, even secret lore. The more you already know, the more precise the information.$$, null),
($$Mass Cure Wounds$$, 5, 'evocation', '1 action', '60 feet', 'VS', null, 'Instantaneous', false,
 array['Bard','Cleric','Druid'], 'healing',
 $$Up to six creatures in a 30-foot-radius sphere each regain 3d8 + your spellcasting ability modifier hit points. No effect on undead or constructs.$$,
 $$+1d8 healing for each slot level above 5th.$$),
($$Mislead$$, 5, 'illusion', '1 action', 'Self', 'S', null, 'Concentration, up to 1 hour', false,
 array['Bard','Wizard'], 'utility',
 $$You turn invisible as an illusory double appears where you stand. Invisibility ends if you attack or cast a spell. As an action you can move the double up to twice your speed and make it gesture, speak and behave as you choose, and you can see and hear through its senses.$$, null),
($$Modify Memory$$, 5, 'enchantment', '1 action', '30 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Bard','Wizard'], 'social',
 $$A creature makes a Wisdom save (advantage if you are fighting it) or is charmed and incapacitated. While it is, you can spend up to 10 minutes describing how to change its memory of an event from the past 24 hours that lasted no more than 10 minutes. The change takes hold if you finish before the spell ends. Remove curse or greater restoration restores the memory.$$,
 $$Reach older memories: up to 7 days ago with a 6th-level slot, 30 days with a 7th, 1 year with an 8th, any time with a 9th.$$),
($$Passwall$$, 5, 'transmutation', '1 action', '30 feet', 'VSM', $$a pinch of sesame seeds$$, '1 hour', false,
 array['Wizard'], 'movement',
 $$A passage up to 5 feet wide, 8 feet tall and 20 feet deep opens in a wooden, plaster or stone surface. When the spell ends, anyone still inside is safely ejected to the nearest unoccupied space.$$, null),
($$Planar Binding$$, 5, 'abjuration', '1 hour', '60 feet', 'VSM', $$a jewel worth at least 1,000 gp, which the spell consumes$$, '24 hours', false,
 array['Bard','Cleric','Druid','Wizard'], 'summoning',
 $$Bind a celestial, elemental, fey or fiend that stays in range for the whole casting (usually after summoning it into a reversed magic circle). It makes a Charisma save, and on a failure it must serve you for the duration, following your commands to the best of its ability.$$,
 $$Lasts 10 days with a 6th-level slot, 30 days with a 7th, 180 days with an 8th, and a year and a day with a 9th.$$),
($$Raise Dead$$, 5, 'necromancy', '1 hour', 'Touch', 'VSM', $$a diamond worth at least 500 gp, which the spell consumes$$, 'Instantaneous', false,
 array['Bard','Cleric','Paladin'], 'healing',
 $$Return a creature dead no longer than 10 days to life with 1 hit point, if its soul is willing. It neutralises nonmagical diseases and poisons but doesn't restore missing body parts or work on undead. The creature takes a -4 penalty to attack rolls, saves and ability checks, reduced by 1 each long rest.$$, null),
($$Rary's Telepathic Bond$$, 5, 'divination', '1 action', '30 feet', 'VSM', $$pieces of eggshell from two different kinds of creatures$$, '1 hour', true,
 array['Wizard'], 'social',
 $$Link up to eight willing creatures telepathically. Until the spell ends they can communicate at any distance, though not across planes, even without a shared language.$$, null),
($$Reincarnate$$, 5, 'transmutation', '1 hour', 'Touch', 'VSM', $$rare oils and unguents worth at least 1,000 gp, which the spell consumes$$, 'Instantaneous', false,
 array['Druid'], 'healing',
 $$A humanoid dead no longer than 10 days returns in a newly grown adult body, its race rolled on a d100 table. It keeps its mind, class features and memories, but its physical racial traits change. Its soul must be willing.$$, null),
($$Seeming$$, 5, 'illusion', '1 action', '30 feet', 'VS', null, '8 hours', false,
 array['Bard','Sorcerer','Wizard'], 'utility',
 $$Give any number of creatures you can see an illusory new appearance (an unwilling one makes a Charisma save). It can change their look, clothes and gear and make them up to a foot shorter or taller, but not change their body type. A creature can see through it with an Intelligence (Investigation) check against your spell save DC.$$, null),
($$Swift Quiver$$, 5, 'transmutation', '1 bonus action', 'Touch', 'VSM', $$a quiver containing at least one piece of ammunition$$, 'Concentration, up to 1 minute', false,
 array['Ranger'], 'buff',
 $$Your quiver produces an endless supply of nonmagical ammunition. On each of your turns until the spell ends, you can use a bonus action to make two attacks with a weapon that uses ammunition from it.$$, null),
($$Tree Stride$$, 5, 'conjuration', '1 action', 'Self', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Druid','Ranger'], 'movement',
 $$Step into a living tree and out of another of the same kind within 500 feet, using 5 feet of movement. You can do this once per round for the duration, ending each turn outside a tree.$$, null),
($$Wall of Force$$, 5, 'evocation', '1 action', '120 feet', 'VSM', $$a pinch of powder made by crushing a clear gemstone$$, 'Concentration, up to 10 minutes', false,
 array['Wizard'], 'control',
 $$An invisible wall of force appears: up to ten 10-foot panels, or a hemispherical dome or sphere up to 10 feet in radius. Nothing physical passes through it, it is immune to all damage and can't be dispelled by dispel magic, and it extends into the Ethereal Plane. Disintegrate destroys it instantly.$$, null),
($$Wall of Stone$$, 5, 'evocation', '1 action', '120 feet', 'VSM', $$a small block of granite$$, 'Concentration, up to 10 minutes', false,
 array['Druid','Sorcerer','Wizard'], 'control',
 $$A nonmagical wall of solid stone rises: ten 10-by-10-foot panels 6 inches thick, or ten 10-by-20-foot panels 3 inches thick. Each panel has AC 15 and 30 hit points per inch of thickness. A creature that would be enclosed makes a Dexterity save to escape. If you concentrate for the full duration, the wall becomes permanent.$$, null);

insert into public.spells
  (name, level, school, casting_time, range,
   verbal, somatic, material, material_component,
   duration, concentration, ritual, classes,
   description, higher_levels, tags)
select s.name, s.level, s.school, s.casting_time, s.range,
       position('V' in s.comp) > 0, position('S' in s.comp) > 0,
       position('M' in s.comp) > 0, s.material_component,
       s.duration, s.duration like 'Concentration, up to %', s.ritual, s.classes,
       s.description, s.higher_levels,
       array[
         case s.level when 0 then 'cantrip' when 1 then '1st-level'
                      when 2 then '2nd-level' when 3 then '3rd-level'
                      else s.level || 'th-level' end,
         s.category, s.school, 'PHB']
  from _seed s
 where not exists (
   select 1 from public.spells p
    where p.campaign_id is null and p.name = s.name
 );

do $do$
declare
  v_expected int := (select count(*) from _seed);
  v_found    int;
begin
  select count(*) into v_found
    from _seed s
    join public.spells p
      on p.campaign_id is null
     and p.name = s.name
     and p.level = s.level
     and p.school = s.school
     and p.concentration = (s.duration like 'Concentration, up to %')
     and p.ritual = s.ritual;
  if v_found <> v_expected then
    raise exception 'spell seed incomplete: % of % rows present', v_found, v_expected;
  end if;
end
$do$;

insert into public.schema_migrations (version) values ('142');

commit;

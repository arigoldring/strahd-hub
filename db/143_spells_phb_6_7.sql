-- db/143_spells_phb_6_7.sql
--
-- Seeds the shared catalogue with the 2014 PHB's 6th- and 7th-level spells
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
-- 6th level ----------------------------------------------------------------
($$Arcane Gate$$, 6, 'conjuration', '1 action', '500 feet', 'VS', null, 'Concentration, up to 10 minutes', false,
 array['Sorcerer','Warlock','Wizard'], 'movement',
 $$Open two linked portals 10 feet in diameter, one within 10 feet of you and one elsewhere in range, each hovering within 10 feet of the ground. Anything entering one exits the other; only one side of each is a doorway. As a bonus action you can turn either portal.$$, null),
($$Blade Barrier$$, 6, 'evocation', '1 action', '90 feet', 'VS', null, 'Concentration, up to 10 minutes', false,
 array['Cleric'], 'damage',
 $$A wall of whirling blades rises: up to 100 feet long, 20 feet high and 5 feet thick, or a ring up to 60 feet across. It gives three-quarters cover and is difficult terrain. A creature that enters it for the first time on a turn or starts its turn there makes a Dexterity save, taking 6d10 slashing damage on a failure or half on a success.$$, null),
($$Chain Lightning$$, 6, 'evocation', '1 action', '150 feet', 'VSM', $$a bit of fur; a piece of amber, glass, or a crystal rod; and three silver pins$$, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'damage',
 $$A bolt strikes one target, then leaps to up to three others within 30 feet of it. Each target makes a Dexterity save, taking 10d8 lightning damage on a failure or half on a success.$$,
 $$One additional bolt leaps from the first target for each slot level above 6th.$$),
($$Circle of Death$$, 6, 'necromancy', '1 action', '150 feet', 'VSM', $$the powder of a crushed black pearl worth at least 500 gp$$, 'Instantaneous', false,
 array['Sorcerer','Warlock','Wizard'], 'damage',
 $$Negative energy ripples out in a 60-foot-radius sphere. Each creature in it makes a Constitution save, taking 8d6 necrotic damage on a failure or half on a success.$$,
 $$+2d6 damage for each slot level above 6th.$$),
($$Conjure Fey$$, 6, 'conjuration', '1 minute', '90 feet', 'VS', null, 'Concentration, up to 1 hour', false,
 array['Druid','Warlock'], 'summoning',
 $$Summon a fey creature of challenge rating 6 or lower, or a fey spirit in the form of a beast of that CR. It obeys your verbal commands. If your concentration breaks it doesn't vanish: it turns hostile for the rest of the hour.$$,
 $$The challenge rating increases by 1 for each slot level above 6th.$$),
($$Contingency$$, 6, 'evocation', '10 minutes', 'Self', 'VSM', $$a statuette of yourself carved from ivory and decorated with gems worth at least 1,500 gp$$, '10 days', false,
 array['Wizard'], 'utility',
 $$Cast a spell of 5th level or lower that can target you, along with this one, and set a trigger. The stored spell takes effect on you the moment the trigger happens, and contingency ends. Only one contingency at a time; it ends if the statuette leaves your person.$$, null),
($$Create Undead$$, 6, 'necromancy', '1 minute', '10 feet', 'VSM', $$one clay pot filled with grave dirt, one clay pot filled with brackish water, and one 150 gp black onyx stone for each corpse$$, 'Instantaneous', false,
 array['Cleric','Warlock','Wizard'], 'summoning',
 $$Cast only at night. Up to three corpses of Medium or Small humanoids rise as ghouls under your control. As a bonus action you can command them telepathically within 120 feet. Control lasts 24 hours; recast to keep up to the same number.$$,
 $$7th level: four ghouls. 8th: five ghouls, or two ghasts or wights. 9th: six ghouls, three ghasts or wights, or two mummies.$$),
($$Disintegrate$$, 6, 'transmutation', '1 action', '60 feet', 'VSM', $$a lodestone and a pinch of dust$$, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'damage',
 $$A thin green ray strikes a creature, an object or a creation of magical force. A creature makes a Dexterity save or takes 10d6 + 40 force damage; if this reduces it to 0 hit points it is turned to grey dust. A Large or smaller nonmagical object or force effect is disintegrated outright; for anything bigger, a 10-foot cube of it is.$$,
 $$+3d6 damage for each slot level above 6th.$$),
($$Drawmij's Instant Summons$$, 6, 'conjuration', '1 minute', 'Touch', 'VSM', $$a sapphire worth 1,000 gp$$, 'Until dispelled', true,
 array['Wizard'], 'utility',
 $$Mark an object weighing 10 pounds or less, no longer than 6 feet, with a sapphire. Crush the sapphire as an action later and the object appears in your hand, wherever it is on your plane. If another creature holds it, you instead learn who and roughly where.$$, null),
($$Eyebite$$, 6, 'necromancy', '1 action', 'Self', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'control',
 $$Your eyes become inky voids. On each of your turns, use your action to target one creature within 60 feet that can see you; it makes a Wisdom save or suffers one effect: Asleep (unconscious, wakes if damaged or shaken), Panicked (frightened, and must move away from you each turn), or Sickened (disadvantage on attacks and ability checks; repeats the save each turn).$$, null),
($$Find the Path$$, 6, 'divination', '1 minute', 'Self', 'VSM', $$a set of divinatory tools, such as bones, ivory sticks, cards, teeth, or carved runes, worth 100 gp and an object from the location you wish to find$$, 'Concentration, up to 1 day', false,
 array['Bard','Cleric','Druid'], 'detection',
 $$Name a specific fixed location you are familiar with on your plane. For the duration you know the shortest, most direct physical route to it, including which way to go at every fork.$$, null),
($$Flesh to Stone$$, 6, 'transmutation', '1 action', '60 feet', 'VSM', $$a pinch of lime, water, and earth$$, 'Concentration, up to 1 minute', false,
 array['Warlock','Wizard'], 'control',
 $$A creature makes a Constitution save or is restrained as its flesh hardens. At the end of each of its turns it repeats the save: three successes end the spell, three failures turn it to stone (petrified). If you concentrate for the full minute, the petrification lasts until removed.$$, null),
($$Forbiddance$$, 6, 'abjuration', '10 minutes', 'Touch', 'VSM', $$a sprinkling of holy water, rare incense, and powdered ruby worth at least 1,000 gp$$, '1 day', true,
 array['Cleric'], 'defense',
 $$Ward up to 40,000 square feet of floor space, up to 30 feet high. Nobody can teleport in or use planar travel to enter. You can also choose celestials, elementals, fey, fiends or undead: those take 5d10 radiant or necrotic damage when they enter for the first time on a turn or start their turn there. A password exempts creatures. Cast daily for 30 days on the same spot and it lasts until dispelled.$$, null),
($$Globe of Invulnerability$$, 6, 'abjuration', '1 action', 'Self (10-foot radius)', 'VSM', $$a glass or crystal bead that shatters when the spell ends$$, 'Concentration, up to 1 minute', false,
 array['Sorcerer','Wizard'], 'defense',
 $$An immobile shimmering barrier 10 feet in radius surrounds you. Spells of 5th level or lower cast from outside can't affect anything inside, even if cast with a higher slot. Spells can still be cast out from inside.$$,
 $$It blocks spells of one more level for each slot level above 6th.$$),
($$Guards and Wards$$, 6, 'abjuration', '10 minutes', 'Touch', 'VSM', $$burning incense, a small measure of brimstone and oil, a knotted string, a small amount of umber hulk blood, and a small silver rod worth at least 10 gp$$, '24 hours', false,
 array['Bard','Wizard'], 'defense',
 $$Protect up to 2,500 square feet: fog fills corridors, doors are arcane-locked, webs fill stairs, and one passage per area becomes a confusing illusion. Add one of: dancing lights, a magic mouth, a stinking cloud, a constant gust of wind, or a suggestion on a 5-foot square. Cast daily for a year and it becomes permanent.$$, null),
($$Harm$$, 6, 'necromancy', '1 action', '60 feet', 'VS', null, 'Instantaneous', false,
 array['Cleric'], 'damage',
 $$A virulent disease strikes a creature. It makes a Constitution save, taking 14d6 necrotic damage on a failure or half on a success; this damage can't drop it below 1 hit point. On a failure its hit point maximum is also reduced by the damage for 1 hour.$$, null),
($$Heal$$, 6, 'evocation', '1 action', '60 feet', 'VS', null, 'Instantaneous', false,
 array['Cleric','Druid'], 'healing',
 $$A creature regains 70 hit points, and is cured of blindness, deafness and any diseases. No effect on undead or constructs.$$,
 $$+10 healing for each slot level above 6th.$$),
($$Heroes' Feast$$, 6, 'conjuration', '10 minutes', '30 feet', 'VSM', $$a gem-encrusted bowl worth at least 1,000 gp, which the spell consumes$$, 'Instantaneous', false,
 array['Cleric','Druid'], 'buff',
 $$A feast for up to twelve creatures appears, taking an hour to eat. Each diner is cured of disease and poison, becomes immune to poison and to being frightened, and has advantage on Wisdom saves, while its hit point maximum and current hit points rise by 2d10. These benefits last 24 hours.$$, null),
($$Magic Jar$$, 6, 'necromancy', '1 minute', 'Self', 'VSM', $$a gem, crystal, reliquary, or some other ornamental container worth at least 500 gp$$, 'Until dispelled', false,
 array['Wizard'], 'control',
 $$Your soul moves into a container while your body falls catatonic. From there you can try to possess a humanoid within 100 feet: it makes a Charisma save, and on a failure your soul takes its body and its soul is trapped in the container. You keep your mind and spellcasting but use its physical statistics. Destroying the container ends things badly for whoever is inside it.$$, null),
($$Mass Suggestion$$, 6, 'enchantment', '1 action', '60 feet', 'VM', $$a snake's tongue and either a bit of honeycomb or a drop of sweet oil$$, '24 hours', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'social',
 $$Suggest a reasonable-sounding course of activity to up to twelve creatures that can hear and understand you. Each makes a Wisdom save or pursues it as best it can. Something obviously harmful fails. The spell ends for a creature when it completes the task or you or your companions damage it.$$,
 $$10 days with a 7th-level slot, 30 days with an 8th, a year and a day with a 9th.$$),
($$Move Earth$$, 6, 'transmutation', '1 action', '120 feet', 'VSM', $$an iron blade and a small bag containing a mixture of soils, clay, loam, and sand$$, 'Concentration, up to 2 hours', false,
 array['Druid','Sorcerer','Wizard'], 'utility',
 $$Reshape dirt, sand or clay in a 40-foot square: raise or lower its elevation, dig or fill a trench, build or flatten a wall. Each change takes 10 minutes, and you can pick a new area every 10 minutes. It can't move stone or stone structures directly, and it works too slowly to trap creatures.$$, null),
($$Otiluke's Freezing Sphere$$, 6, 'evocation', '1 action', '300 feet', 'VSM', $$a small crystal sphere$$, 'Instantaneous', false,
 array['Wizard'], 'damage',
 $$A globe of cold bursts in a 60-foot-radius sphere. Each creature in it makes a Constitution save, taking 10d6 cold damage on a failure or half on a success. Open water it hits freezes 6 inches deep for 1 minute. You can instead keep the globe as a sling-stone that you or someone else can throw within 1 minute.$$,
 $$+1d6 damage for each slot level above 6th.$$),
($$Otto's Irresistible Dance$$, 6, 'enchantment', '1 action', '30 feet', 'V', null, 'Concentration, up to 1 minute', false,
 array['Bard','Wizard'], 'control',
 $$A creature that can't be charmed is unaffected; any other begins a comic dance, with no save at first. It must use all its movement to dance in place, has disadvantage on Dexterity saves and attack rolls, and others have advantage on attacks against it. As an action it can make a Wisdom save to end the spell.$$, null),
($$Planar Ally$$, 6, 'conjuration', '10 minutes', '60 feet', 'VS', null, 'Instantaneous', false,
 array['Cleric'], 'summoning',
 $$Ask an otherworldly entity for aid, and it sends a loyal celestial, elemental or fiend. The creature is under no compulsion: you negotiate a service and a payment, from a donation to its cause for a short task to a rare magic item for a dangerous one.$$, null),
($$Programmed Illusion$$, 6, 'illusion', '1 action', '120 feet', 'VSM', $$a bit of fleece and jade dust worth at least 25 gp$$, 'Until dispelled', false,
 array['Bard','Wizard'], 'utility',
 $$Create an illusion of an object, creature or phenomenon, up to a 30-foot cube, that stays dormant until a trigger you set occurs. Then it plays out a scripted performance of up to 5 minutes with sound, and goes dormant for 10 minutes before it can trigger again. Physical interaction reveals it, as does an Intelligence (Investigation) check against your spell save DC.$$, null),
($$Sunbeam$$, 6, 'evocation', '1 action', 'Self (60-foot line)', 'VSM', $$a magnifying glass$$, 'Concentration, up to 1 minute', false,
 array['Druid','Sorcerer','Wizard'], 'damage',
 $$A beam of brilliant light flashes in a 5-foot-wide, 60-foot line. Each creature in it makes a Constitution save, taking 6d8 radiant damage and being blinded until your next turn on a failure, or half damage on a success. Undead and oozes have disadvantage. You can make a new line as an action on later turns, and you shed bright sunlight in a 30-foot radius.$$, null),
($$Transport via Plants$$, 6, 'conjuration', '1 action', '10 feet', 'VS', null, '1 round', false,
 array['Druid'], 'movement',
 $$Link a Large or larger inanimate plant within range to another plant at any distance on the same plane, which you must have seen or touched. Until the end of your next turn, any creature can step into the first plant and out of the second using 5 feet of movement.$$, null),
($$True Seeing$$, 6, 'divination', '1 action', 'Touch', 'VSM', $$an ointment for the eyes that costs 25 gp; is made from mushroom powder, saffron, and fat; and is consumed by the spell$$, '1 hour', false,
 array['Bard','Cleric','Sorcerer','Warlock','Wizard'], 'detection',
 $$A willing creature gains truesight out to 120 feet: it sees through darkness, illusions and invisibility, notices secret doors hidden by magic, sees shapechangers' true forms, and can see into the Ethereal Plane.$$, null),
($$Wall of Ice$$, 6, 'evocation', '1 action', '120 feet', 'VSM', $$a small piece of quartz$$, 'Concentration, up to 10 minutes', false,
 array['Wizard'], 'control',
 $$A wall of ice 1 foot thick rises: ten 10-foot panels, or a dome or sphere up to 10 feet in radius. A creature in its space when it appears makes a Dexterity save, taking 10d6 cold damage on a failure or half on a success. Each 10-foot section has AC 12 and 30 hit points and is vulnerable to fire. A broken section leaves frigid air: a creature moving through it for the first time on a turn makes a Constitution save, taking 5d6 cold damage on a failure or half on a success.$$,
 $$+2d6 damage when it appears and +1d6 from the frigid air for each slot level above 6th.$$),
($$Wall of Thorns$$, 6, 'conjuration', '1 action', '120 feet', 'VSM', $$a handful of thorns$$, 'Concentration, up to 10 minutes', false,
 array['Druid'], 'control',
 $$A wall of tangled thorny brush appears, up to 60 feet long, 10 feet high and 5 feet thick, or a circle 20 feet across. Creatures in its area when it appears make a Dexterity save, taking 7d8 piercing damage on a failure or half on a success. Moving through it costs 4 feet per foot, and a creature entering it for the first time on a turn or ending its turn there makes a Dexterity save against 7d8 slashing damage, half on a success.$$,
 $$Both damage rolls increase by 1d8 for each slot level above 6th.$$),
($$Wind Walk$$, 6, 'transmutation', '1 minute', '30 feet', 'VSM', $$fire and holy water$$, '8 hours', false,
 array['Druid'], 'movement',
 $$You and up to ten willing creatures become clouds of vapour. Each gains a 300-foot flying speed and resistance to nonmagical damage, and can't attack, cast spells or manipulate objects, but can only Dash, Disengage or return to normal form. Changing back takes 1 minute, during which the creature is incapacitated and descends 60 feet a round.$$, null),
($$Word of Recall$$, 6, 'conjuration', '1 action', '5 feet', 'V', null, 'Instantaneous', false,
 array['Cleric'], 'movement',
 $$You and up to five willing creatures within 5 feet of you teleport to a sanctuary you designated earlier, a place dedicated to or strongly linked with your deity. Cast the spell at the sanctuary first to set it.$$, null),

-- 7th level ----------------------------------------------------------------
($$Conjure Celestial$$, 7, 'conjuration', '1 minute', '90 feet', 'VS', null, 'Concentration, up to 1 hour', false,
 array['Cleric'], 'summoning',
 $$Summon a celestial of challenge rating 4 or lower that obeys your verbal commands and acts on its own initiative. It vanishes at 0 hit points or when the spell ends.$$,
 $$With a 9th-level slot, a celestial of CR 5 or lower.$$),
($$Delayed Blast Fireball$$, 7, 'evocation', '1 action', '150 feet', 'VSM', $$a tiny ball of bat guano and sulfur$$, 'Concentration, up to 1 minute', false,
 array['Sorcerer','Wizard'], 'damage',
 $$A glowing bead hangs at a point you choose. When the spell ends, by your choice, broken concentration or the minute running out, it explodes in a 20-foot-radius sphere: each creature makes a Dexterity save, taking fire damage on a failure or half on a success. The base damage is 12d6 and grows by 1d6 at the end of each of your turns before it goes off. A creature touching the bead can make a Dexterity save to throw it up to 40 feet.$$,
 $$The base damage increases by 1d6 for each slot level above 7th.$$),
($$Divine Word$$, 7, 'evocation', '1 bonus action', '30 feet', 'V', null, 'Instantaneous', false,
 array['Cleric'], 'control',
 $$Each creature you choose that can hear you makes a Charisma save. On a failure the effect depends on its current hit points: 50 or fewer, deafened for 1 minute; 40 or fewer, also blinded for 10 minutes; 30 or fewer, also stunned for 1 hour; 20 or fewer, killed. A celestial, elemental, fey or fiend that fails is also sent to its home plane and can't return for 24 hours.$$, null),
($$Etherealness$$, 7, 'transmutation', '1 action', 'Self', 'VS', null, 'Up to 8 hours', false,
 array['Bard','Cleric','Sorcerer','Warlock','Wizard'], 'movement',
 $$You step into the border regions of the Ethereal Plane, where you can move in any direction (up and down at half speed) and see and hear the plane you left, in shades of grey, out to 60 feet. You can affect only other ethereal creatures. When the spell ends you return to the plane you left, shunted aside if your space is occupied.$$,
 $$Up to three willing creatures (including you) for each slot level above 7th.$$),
($$Finger of Death$$, 7, 'necromancy', '1 action', '60 feet', 'VS', null, 'Instantaneous', false,
 array['Sorcerer','Warlock','Wizard'], 'damage',
 $$Negative energy courses through a creature. It makes a Constitution save, taking 7d8 + 30 necrotic damage on a failure or half on a success. A humanoid killed by this rises at the start of your next turn as a zombie permanently under your command.$$, null),
($$Fire Storm$$, 7, 'evocation', '1 action', '150 feet', 'VS', null, 'Instantaneous', false,
 array['Cleric','Druid','Sorcerer'], 'damage',
 $$Sheets of flame fill up to ten 10-foot cubes, each touching at least one other. Each creature in the area makes a Dexterity save, taking 7d10 fire damage on a failure or half on a success. Flammable objects not worn or carried catch fire, and you can choose to spare the plants in the area.$$, null),
($$Forcecage$$, 7, 'evocation', '1 action', '100 feet', 'VSM', $$ruby dust worth 1,500 gp, which the spell consumes$$, '1 hour', false,
 array['Bard','Warlock','Wizard'], 'control',
 $$An invisible, immobile prison of force forms: a cage up to 20 feet on a side with bars half an inch apart, or a solid box up to 10 feet on a side. A creature only partly inside is pushed out. A creature inside can't leave by nonmagical means; to teleport or travel planes out it must first succeed on a Charisma save. It can't be dispelled by dispel magic.$$, null),
($$Mirage Arcane$$, 7, 'illusion', '10 minutes', 'Sight', 'VS', null, '10 days', false,
 array['Bard','Druid','Wizard'], 'utility',
 $$Make up to a square mile of terrain look, sound, smell and even feel like another kind of terrain. The illusion is tangible: illusory brush can be cut, illusory bridges can be crossed. Truesight sees the true terrain, but the other parts of the illusion still behave as described.$$, null),
($$Mordenkainen's Magnificent Mansion$$, 7, 'conjuration', '1 minute', '300 feet', 'VSM', $$a miniature portal carved from ivory, a small piece of polished marble, and a tiny silver spoon, each item worth at least 5 gp$$, '24 hours', false,
 array['Bard','Wizard'], 'utility',
 $$Conjure a shimmering door to an extradimensional dwelling of up to fifty 10-foot cubes, furnished as you choose, with a hundred near-transparent servants and a nine-course banquet for a hundred. Only those you designate can enter, and the door can be made invisible. Anything taken out of it vanishes; those inside are expelled when the spell ends.$$, null),
($$Mordenkainen's Sword$$, 7, 'evocation', '1 action', '60 feet', 'VSM', $$a miniature platinum sword with a grip and pommel of copper and zinc, worth 250 gp$$, 'Concentration, up to 1 minute', false,
 array['Bard','Wizard'], 'damage',
 $$A sword-shaped plane of force hovers within range. When it appears, make a melee spell attack against a creature within 5 feet of it, dealing 3d10 force damage on a hit. As a bonus action on later turns, move it up to 20 feet and repeat the attack.$$, null),
($$Plane Shift$$, 7, 'conjuration', '1 action', 'Touch', 'VSM', $$a forked, metal rod worth at least 250 gp, attuned to a particular plane of existence$$, 'Instantaneous', false,
 array['Cleric','Druid','Sorcerer','Warlock','Wizard'], 'movement',
 $$You and up to eight willing creatures linking hands travel to another plane, arriving at or near a destination you name (a teleportation circle's sigil sequence gets you there exactly). Or make a melee spell attack against an unwilling creature: on a hit it makes a Charisma save or is sent to a random place on a plane you name.$$, null),
($$Prismatic Spray$$, 7, 'evocation', '1 action', 'Self (60-foot cone)', 'VS', null, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'damage',
 $$Eight rays flash from your hand in a 60-foot cone. Each creature makes a Dexterity save and rolls a d8 for the ray that hits it. 1 to 5: 10d6 fire, acid, lightning, poison or cold damage respectively, half on a success. 6 (indigo): restrained on a failure, then saves each turn, petrified after three failures. 7 (violet): blinded on a failure, then a Wisdom save next turn or be sent to another plane. 8: struck by two rays (roll twice, rerolling 8s).$$, null),
($$Project Image$$, 7, 'illusion', '1 action', '500 miles', 'VSM', $$a small replica of you made from materials worth at least 5 gp$$, 'Concentration, up to 1 day', false,
 array['Bard','Wizard'], 'utility',
 $$An illusory copy of you appears at a place you've seen within range. As an action you can move it up to twice your speed and make it gesture, speak and behave as you choose, and you can see and hear through it (you're blinded and deafened to your own surroundings while you do). Physical interaction reveals it, as does an Intelligence (Investigation) check against your spell save DC.$$, null),
($$Regenerate$$, 7, 'transmutation', '1 minute', 'Touch', 'VSM', $$a prayer wheel and holy water$$, '1 hour', false,
 array['Bard','Cleric','Druid'], 'healing',
 $$The creature you touch regains 4d8 + 15 hit points at once, then 1 hit point at the start of each of its turns (10 per minute) for the duration. Severed body parts regrow after 2 minutes, or reattach at once if held to the stump.$$, null),
($$Resurrection$$, 7, 'necromancy', '1 hour', 'Touch', 'VSM', $$a diamond worth at least 1,000 gp, which the spell consumes$$, 'Instantaneous', false,
 array['Bard','Cleric'], 'healing',
 $$Return a creature dead no longer than a century, not of old age and not undead, to life with all its hit points, with poisons and diseases neutralised and missing body parts restored. Afterwards it takes -4 to attack rolls, saves and ability checks, reduced by 1 each long rest. Casting it on someone dead a year or more taxes you: you can't cast spells again, and have disadvantage on attacks, checks and saves, until a long rest.$$, null),
($$Reverse Gravity$$, 7, 'transmutation', '1 action', '100 feet', 'VSM', $$a lodestone and iron filings$$, 'Concentration, up to 1 minute', false,
 array['Druid','Sorcerer','Wizard'], 'control',
 $$Gravity reverses in a 50-foot-radius, 100-foot-high cylinder. Unanchored creatures and objects fall upward to the top, taking falling damage if they hit something; a creature can make a Dexterity save to grab a fixed object within reach. They hang at the top until the spell ends, then fall back down.$$, null),
($$Sequester$$, 7, 'transmutation', '1 action', 'Touch', 'VSM', $$a powder composed of diamond, emerald, ruby, and sapphire dust worth at least 5,000 gp, which the spell consumes$$, 'Until dispelled', false,
 array['Wizard'], 'defense',
 $$Hide a willing creature or an object from detection. It becomes invisible and can't be targeted by divination or perceived through scrying sensors. A creature falls into suspended animation, not aging. You can set a condition that ends the spell, such as a span of time or an event.$$, null),
($$Simulacrum$$, 7, 'illusion', '12 hours', 'Touch', 'VSM', $$snow or ice in quantities sufficient to made a life-size copy of the duplicated creature; some hair, fingernail clippings, or other piece of that creature's body placed inside the snow or ice; and powdered ruby worth 1,500 gp, sprinkled over the duplicate and consumed by the spell$$, 'Until dispelled', false,
 array['Wizard'], 'summoning',
 $$Shape an illusory duplicate of a beast or humanoid within range for the whole casting. It has half the original's hit point maximum, its other statistics and abilities, and obeys you. It can't regain expended spell slots or improve, and at 0 hit points it melts into snow. Repairing it in an alchemical lab costs 100 gp per hit point. Casting the spell again destroys any earlier duplicate you made.$$, null),
($$Symbol$$, 7, 'abjuration', '1 minute', 'Touch', 'VSM', $$mercury, phosphorus, and powdered diamond and opal with a total value of at least 1,000 gp, which the spell consumes$$, 'Until dispelled or triggered', false,
 array['Bard','Cleric','Wizard'], 'control',
 $$Inscribe a harmful glyph with a trigger you set (finding it needs Intelligence (Investigation) against your spell save DC). When triggered it fills a 60-foot-radius sphere with dim light for 10 minutes, and each creature in it, or entering it later, is affected by the effect you chose: Death (Constitution save, 10d10 necrotic damage, half on a success), Discord, Fear, Hopelessness, Insanity, Pain, Sleep or Stunning, each allowing a save.$$, null),
($$Teleport$$, 7, 'conjuration', '1 action', '10 feet', 'V', null, 'Instantaneous', false,
 array['Bard','Sorcerer','Wizard'], 'movement',
 $$Instantly transport yourself and up to eight willing creatures, or one object, to a destination on the same plane. How well you know the destination (permanent circle, associated object, very familiar, seen casually, viewed once, description only, false destination) decides whether you arrive on target, off target, at a similar area, or suffer a mishap that deals 3d10 force damage and tries again.$$, null);

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

insert into public.schema_migrations (version) values ('143');

commit;

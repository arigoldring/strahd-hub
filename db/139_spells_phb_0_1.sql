-- db/139_spells_phb_0_1.sql
--
-- Seeds the shared catalogue with the 2014 PHB's cantrips and 1st-level
-- spells that 023/024 did not. The first of eight seed files (138's header
-- has the map). Split by level only so each file stays reviewable; nothing
-- depends on the split.
--
-- DESCRIPTIONS ARE SHORT SUMMARIES IN OUR OWN WORDS, never the book's text
-- (CLAUDE.md, the class feature rule; 130 for items). Every number a player
-- needs at the table is kept: damage, save, area, duration effects. Upcast
-- text goes in higher_levels; a cantrip's scaling stays in its description,
-- where the book puts it.
--
-- CLASSES are the book's own list. TCoE's optional additions are 147's job.
-- No 'Artificer': that class is not in the catalogue (KNOWN_ISSUES).
--
-- SHAPE (130's, plus two derivations). Rows are written once into a temp
-- table and every statement reads from there. `comp` is any of V, S, M and
-- becomes the three booleans; a CHECK makes "M without a component" and "a
-- component without M" unwritable. `concentration` is derived from the
-- duration's "Concentration, up to ..." spelling, so the flag and the text
-- cannot disagree. `tags` is [level tag, category, school, book], 024's order
-- with the book tag the magic items carry. The insert is guarded by
-- `not exists` on a shared row of the same name; since 138 a duplicate
-- shared name is also unwritable. The assertion is on the end state: every
-- seeded name present, shared, with the level, school, concentration and
-- ritual written here.
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
-- Cantrips -----------------------------------------------------------------
($$Acid Splash$$, 0, 'conjuration', '1 action', '60 feet', 'VS', null, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'damage',
 $$Hurl a bubble of acid at one creature, or two creatures within 5 feet of each other. Each must succeed on a Dexterity save or take 1d6 acid damage. Damage rises to 2d6 at 5th level, 3d6 at 11th and 4d6 at 17th.$$, null),
($$Blade Ward$$, 0, 'abjuration', '1 action', 'Self', 'VS', null, '1 round', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'defense',
 $$Until the end of your next turn you have resistance to bludgeoning, piercing and slashing damage from weapon attacks.$$, null),
($$Chill Touch$$, 0, 'necromancy', '1 action', '120 feet', 'VS', null, '1 round', false,
 array['Sorcerer','Warlock','Wizard'], 'damage',
 $$A ghostly hand grips a creature. Make a ranged spell attack: on a hit it takes 1d8 necrotic damage and can't regain hit points until the start of your next turn. An undead target also has disadvantage on attack rolls against you until the end of your next turn. Damage rises to 2d8 at 5th level, 3d8 at 11th and 4d8 at 17th.$$, null),
($$Dancing Lights$$, 0, 'evocation', '1 action', '120 feet', 'VSM', $$a bit of phosphorus or wychwood, or a glowworm$$, 'Concentration, up to 1 minute', false,
 array['Bard','Sorcerer','Wizard'], 'utility',
 $$Create up to four torch-sized lights (each sheds dim light in a 10-foot radius), or combine them into one glowing, vaguely humanoid Medium shape. As a bonus action you can move each light up to 60 feet. Each must stay within 20 feet of another and within range, or it winks out.$$, null),
($$Druidcraft$$, 0, 'transmutation', '1 action', '30 feet', 'VS', null, 'Instantaneous', false,
 array['Druid'], 'utility',
 $$A small nature trick: predict the local weather for the next 24 hours; make a flower bloom, a seed pod open or a leaf bud; produce a harmless sensory effect (falling leaves, a breeze, a faint smell) in a 5-foot cube; or light or snuff out a candle, torch or small campfire.$$, null),
($$Friends$$, 0, 'enchantment', '1 action', 'Self', 'SM', $$a small amount of makeup applied to the face$$, 'Concentration, up to 1 minute', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'social',
 $$You have advantage on Charisma checks against one creature that isn't hostile to you. When the spell ends, the creature realises you used magic on it and may become hostile.$$, null),
($$Light$$, 0, 'evocation', '1 action', 'Touch', 'VM', $$a firefly or phosphorescent moss$$, '1 hour', false,
 array['Bard','Cleric','Sorcerer','Wizard'], 'utility',
 $$An object no larger than 10 feet in any dimension sheds bright light in a 20-foot radius and dim light for another 20 feet, in a colour you choose. Covering it blocks the light. An object held or worn by a hostile creature allows a Dexterity save to avoid the spell. Casting it again ends the previous casting.$$, null),
($$Mage Hand$$, 0, 'conjuration', '1 action', '30 feet', 'VS', null, '1 minute', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'utility',
 $$A spectral floating hand appears. As an action you can use it to handle an object, open an unlocked door or container, stow or retrieve an item, or pour out a vial, moving it up to 30 feet each time. It can't attack, activate magic items or carry more than 10 pounds, and it vanishes if it goes more than 30 feet from you.$$, null),
($$Mending$$, 0, 'transmutation', '1 minute', 'Touch', 'VSM', $$two lodestones$$, 'Instantaneous', false,
 array['Bard','Cleric','Druid','Sorcerer','Wizard'], 'utility',
 $$Repair a single break or tear in an object, no larger than 1 foot in any dimension, leaving no trace of the damage. It can fix a magic item physically but can't restore its magic.$$, null),
($$Message$$, 0, 'transmutation', '1 action', '120 feet', 'VSM', $$a short piece of copper wire$$, '1 round', false,
 array['Bard','Sorcerer','Wizard'], 'social',
 $$Point at a creature and whisper a message that only it hears; it can whisper a reply only you hear. The magic bends around obstacles but is blocked by 1 foot of stone, 1 inch of common metal, a thin sheet of lead or 3 feet of wood.$$, null),
($$Minor Illusion$$, 0, 'illusion', '1 action', '30 feet', 'SM', $$a bit of fleece$$, '1 minute', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'utility',
 $$Create either a sound or a still image of an object (no larger than a 5-foot cube) for the duration. The image has no sound, light or smell, and physical contact reveals it. A creature that uses its action to study it sees through it with a successful Intelligence (Investigation) check against your spell save DC.$$, null),
($$Poison Spray$$, 0, 'conjuration', '1 action', '10 feet', 'VS', null, 'Instantaneous', false,
 array['Druid','Sorcerer','Warlock','Wizard'], 'damage',
 $$Project a puff of noxious gas at one creature. It must succeed on a Constitution save or take 1d12 poison damage. Damage rises to 2d12 at 5th level, 3d12 at 11th and 4d12 at 17th.$$, null),
($$Prestidigitation$$, 0, 'transmutation', '1 action', '10 feet', 'VS', null, 'Up to 1 hour', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'utility',
 $$A minor magical trick: a harmless sensory effect, lighting or snuffing a small flame, cleaning or soiling a small object, chilling, warming or flavouring a pound of material, a small mark or symbol that lasts an hour, or a trinket or illusory image that fits in your hand until the end of your next turn. Up to three non-instantaneous effects can be active at once.$$, null),
($$Produce Flame$$, 0, 'conjuration', '1 action', 'Self', 'VS', null, '10 minutes', false,
 array['Druid'], 'damage',
 $$A flame in your palm sheds bright light for 10 feet and dim light for 10 more; it doesn't burn you or your gear. You can hurl it (as part of casting, or as an action later) at a creature within 30 feet with a ranged spell attack for 1d8 fire damage, which ends the spell. Damage rises to 2d8 at 5th level, 3d8 at 11th and 4d8 at 17th.$$, null),
($$Ray of Frost$$, 0, 'evocation', '1 action', '60 feet', 'VS', null, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'damage',
 $$Make a ranged spell attack. On a hit the target takes 1d8 cold damage and its speed drops by 10 feet until the start of your next turn. Damage rises to 2d8 at 5th level, 3d8 at 11th and 4d8 at 17th.$$, null),
($$Resistance$$, 0, 'abjuration', '1 action', 'Touch', 'VSM', $$a miniature cloak$$, 'Concentration, up to 1 minute', false,
 array['Cleric','Druid'], 'buff',
 $$Once before the spell ends, a willing creature you touch can roll a d4 and add it to one saving throw of its choice, before or after rolling. The spell then ends.$$, null),
($$Shillelagh$$, 0, 'transmutation', '1 bonus action', 'Touch', 'VSM', $$mistletoe, a shamrock leaf, and a club or quarterstaff$$, '1 minute', false,
 array['Druid'], 'buff',
 $$The club or quarterstaff you hold becomes magical. You use your spellcasting ability instead of Strength for its attack and damage rolls, and its damage die becomes a d8. The spell ends if you let go of it or cast it again.$$, null),
($$Shocking Grasp$$, 0, 'evocation', '1 action', 'Touch', 'VS', null, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'damage',
 $$Make a melee spell attack, with advantage if the target wears metal armour. On a hit it takes 1d8 lightning damage and can't take reactions until the start of its next turn. Damage rises to 2d8 at 5th level, 3d8 at 11th and 4d8 at 17th.$$, null),
($$Spare the Dying$$, 0, 'necromancy', '1 action', 'Touch', 'VS', null, 'Instantaneous', false,
 array['Cleric'], 'healing',
 $$A living creature you touch at 0 hit points becomes stable. No effect on undead or constructs.$$, null),
($$Thaumaturgy$$, 0, 'transmutation', '1 action', '30 feet', 'V', null, 'Up to 1 minute', false,
 array['Cleric'], 'utility',
 $$A minor wonder: your voice booms three times louder, flames flicker or change colour, harmless tremors shake the ground, a sound issues from a point you choose, an unlocked door or window flies open or slams shut, or your eyes change appearance. Up to three one-minute effects can be active at once.$$, null),
($$True Strike$$, 0, 'divination', '1 action', '30 feet', 'S', null, 'Concentration, up to 1 round', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'buff',
 $$You gain insight into one creature's defences. On your next turn you have advantage on your first attack roll against it, provided the spell hasn't ended.$$, null),
($$Vicious Mockery$$, 0, 'enchantment', '1 action', '60 feet', 'V', null, 'Instantaneous', false,
 array['Bard'], 'damage',
 $$Insult a creature that can hear you (it needn't understand you). It must succeed on a Wisdom save or take 1d4 psychic damage and have disadvantage on its next attack roll before the end of its next turn. Damage rises to 2d4 at 5th level, 3d4 at 11th and 4d4 at 17th.$$, null),

-- 1st level ----------------------------------------------------------------
($$Alarm$$, 1, 'abjuration', '1 minute', '30 feet', 'VSM', $$a tiny bell and a piece of fine silver wire$$, '8 hours', true,
 array['Ranger','Wizard'], 'detection',
 $$Ward a door, window or area no larger than a 20-foot cube. Whenever a Tiny or larger creature touches or enters it, an alarm goes off; you can exempt creatures when casting. Choose a mental alarm (a ping that wakes you, if you're within 1 mile) or an audible one (a handbell heard within 60 feet for 10 seconds).$$, null),
($$Animal Friendship$$, 1, 'enchantment', '1 action', '30 feet', 'VSM', $$a morsel of food$$, '24 hours', false,
 array['Bard','Druid','Ranger'], 'social',
 $$A beast you can see with Intelligence 3 or lower must succeed on a Wisdom save or be charmed by you for the duration. The spell ends if you or a companion harms it.$$,
 $$One additional beast for each slot level above 1st.$$),
($$Armor of Agathys$$, 1, 'abjuration', '1 action', 'Self', 'VSM', $$a cup of water$$, '1 hour', false,
 array['Warlock'], 'defense',
 $$You gain 5 temporary hit points. While you have any of them, a creature that hits you with a melee attack takes 5 cold damage.$$,
 $$Both the temporary hit points and the cold damage increase by 5 for each slot level above 1st.$$),
($$Arms of Hadar$$, 1, 'conjuration', '1 action', 'Self (10-foot radius)', 'VS', null, 'Instantaneous', false,
 array['Warlock'], 'damage',
 $$Dark tendrils lash out at every creature within 10 feet of you. Each makes a Strength save: on a failure it takes 2d6 necrotic damage and can't take reactions until its next turn; on a success it takes half damage and nothing else.$$,
 $$+1d6 damage for each slot level above 1st.$$),
($$Bane$$, 1, 'enchantment', '1 action', '30 feet', 'VSM', $$a drop of blood$$, 'Concentration, up to 1 minute', false,
 array['Bard','Cleric'], 'control',
 $$Up to three creatures you can see make a Charisma save. Each that fails subtracts a d4 from every attack roll and saving throw it makes for the duration.$$,
 $$One additional creature for each slot level above 1st.$$),
($$Charm Person$$, 1, 'enchantment', '1 action', '30 feet', 'VS', null, '1 hour', false,
 array['Bard','Druid','Sorcerer','Warlock','Wizard'], 'social',
 $$A humanoid you can see makes a Wisdom save, with advantage if you or your companions are fighting it. On a failure it is charmed and regards you as a friendly acquaintance until the spell ends or you or your companions harm it. Afterwards it knows it was charmed.$$,
 $$One additional creature for each slot level above 1st; the targets must be within 30 feet of each other.$$),
($$Chromatic Orb$$, 1, 'evocation', '1 action', '90 feet', 'VSM', $$a diamond worth at least 50 gp$$, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'damage',
 $$Hurl a 4-inch sphere of energy, choosing acid, cold, fire, lightning, poison or thunder. Make a ranged spell attack; on a hit the target takes 3d8 damage of that type.$$,
 $$+1d8 damage for each slot level above 1st.$$),
($$Color Spray$$, 1, 'illusion', '1 action', 'Self (15-foot cone)', 'VSM', $$a pinch of powder or sand that is colored red, yellow, and blue$$, '1 round', false,
 array['Sorcerer','Wizard'], 'control',
 $$Roll 6d10: that many hit points of creatures in the cone are affected, lowest current hit points first (ignoring unconscious creatures and those that can't see). Each affected creature is blinded until the end of your next turn, provided its hit points don't exceed what remains of the total.$$,
 $$Roll an additional 2d10 for each slot level above 1st.$$),
($$Compelled Duel$$, 1, 'enchantment', '1 bonus action', '30 feet', 'V', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'control',
 $$A creature you can see makes a Wisdom save. On a failure it has disadvantage on attack rolls against anyone but you, and must make a Wisdom save to move more than 30 feet away from you. The spell ends if you attack another creature, cast a spell on a hostile creature other than the target, an ally harms the target, or you end your turn more than 30 feet from it.$$, null),
($$Comprehend Languages$$, 1, 'divination', '1 action', 'Self', 'VSM', $$a pinch of soot and salt$$, '1 hour', true,
 array['Bard','Sorcerer','Warlock','Wizard'], 'utility',
 $$You understand the literal meaning of any spoken language you hear, and of written language you touch (about a minute per page). It doesn't decode secret messages or reveal glyphs that aren't part of a language.$$, null),
($$Create or Destroy Water$$, 1, 'transmutation', '1 action', '30 feet', 'VSM', $$a drop of water if creating water or a few grains of sand if destroying it$$, 'Instantaneous', false,
 array['Cleric','Druid'], 'utility',
 $$Create up to 10 gallons of clean water in an open container, or as rain in a 30-foot cube that puts out exposed flames. Or destroy up to 10 gallons of water in an open container, or the fog in a 30-foot cube.$$,
 $$Create or destroy 10 more gallons, or the cube grows by 5 feet, for each slot level above 1st.$$),
($$Detect Evil and Good$$, 1, 'divination', '1 action', 'Self', 'VS', null, 'Concentration, up to 10 minutes', false,
 array['Cleric','Paladin'], 'detection',
 $$You know if an aberration, celestial, elemental, fey, fiend or undead is within 30 feet, and where, along with any place or object that has been magically consecrated or desecrated. Blocked by 1 foot of stone, 1 inch of common metal, a thin sheet of lead or 3 feet of wood.$$, null),
($$Detect Poison and Disease$$, 1, 'divination', '1 action', 'Self', 'VSM', $$a yew leaf$$, 'Concentration, up to 10 minutes', true,
 array['Cleric','Druid','Paladin','Ranger'], 'detection',
 $$You sense the presence and location of poisons, poisonous creatures and diseases within 30 feet, and identify the kind of each. Blocked by 1 foot of stone, 1 inch of common metal, a thin sheet of lead or 3 feet of wood.$$, null),
($$Dissonant Whispers$$, 1, 'enchantment', '1 action', '60 feet', 'V', null, 'Instantaneous', false,
 array['Bard'], 'damage',
 $$A creature you choose makes a Wisdom save. On a failure it takes 3d6 psychic damage and must immediately use its reaction, if available, to move as far as it can away from you (avoiding obviously dangerous ground). On a success it takes half damage and doesn't move. A deafened creature succeeds automatically.$$,
 $$+1d6 damage for each slot level above 1st.$$),
($$Divine Favor$$, 1, 'evocation', '1 bonus action', 'Self', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'buff',
 $$Your weapon attacks deal an extra 1d4 radiant damage on a hit.$$, null),
($$Ensnaring Strike$$, 1, 'conjuration', '1 bonus action', 'Self', 'V', null, 'Concentration, up to 1 minute', false,
 array['Ranger'], 'control',
 $$The next time you hit with a weapon attack, thorny vines grip the target: it must succeed on a Strength save (Large or larger with advantage) or be restrained. While restrained it takes 1d6 piercing damage at the start of each of its turns. It or a creature within reach can use an action on a Strength check against your spell save DC to free it.$$,
 $$+1d6 damage for each slot level above 1st.$$),
($$Entangle$$, 1, 'conjuration', '1 action', '90 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Druid'], 'control',
 $$Grasping plants fill a 20-foot square, making it difficult terrain. Each creature in the area when you cast it must succeed on a Strength save or be restrained. A restrained creature can use its action on a Strength check against your spell save DC to break free.$$, null),
($$Expeditious Retreat$$, 1, 'transmutation', '1 bonus action', 'Self', 'VS', null, 'Concentration, up to 10 minutes', false,
 array['Sorcerer','Warlock','Wizard'], 'movement',
 $$You can take the Dash action as a bonus action when you cast this, and as a bonus action on each of your turns until the spell ends.$$, null),
($$Faerie Fire$$, 1, 'evocation', '1 action', '60 feet', 'V', null, 'Concentration, up to 1 minute', false,
 array['Bard','Druid'], 'control',
 $$Each object and creature in a 20-foot cube is outlined in blue, green or violet light (a creature avoids it with a Dexterity save). Outlined targets shed dim light in a 10-foot radius, attack rolls against them have advantage if the attacker can see them, and they can't benefit from being invisible.$$, null),
($$False Life$$, 1, 'necromancy', '1 action', 'Self', 'VSM', $$a small amount of alcohol or distilled spirits$$, '1 hour', false,
 array['Sorcerer','Wizard'], 'defense',
 $$You gain 1d4 + 4 temporary hit points.$$,
 $$+5 temporary hit points for each slot level above 1st.$$),
($$Find Familiar$$, 1, 'conjuration', '1 hour', '10 feet', 'VSM', $$10 gp worth of charcoal, incense, and herbs that must be consumed by fire in a brass brazier$$, 'Instantaneous', true,
 array['Wizard'], 'summoning',
 $$Summon a spirit as a familiar in the form of a bat, cat, crab, frog, hawk, lizard, octopus, owl, poisonous snake, fish, rat, raven, sea horse, spider or weasel; it is a celestial, fey or fiend. It obeys you, can't attack, and acts on its own initiative. While it is within 100 feet you can talk telepathically, use your action to see and hear through it, and have it deliver your touch spells. At 0 hit points it vanishes; cast the spell again to bring it back. You can have only one familiar.$$, null),
($$Goodberry$$, 1, 'transmutation', '1 action', 'Touch', 'VSM', $$a sprig of mistletoe$$, 'Instantaneous', false,
 array['Druid','Ranger'], 'healing',
 $$Up to ten magic berries appear in your hand. Eating one (an action) restores 1 hit point and provides a day's nourishment. The berries lose their potency after 24 hours.$$, null),
($$Guiding Bolt$$, 1, 'evocation', '1 action', '120 feet', 'VS', null, '1 round', false,
 array['Cleric'], 'damage',
 $$Make a ranged spell attack. On a hit the target takes 4d6 radiant damage, and the next attack roll made against it before the end of your next turn has advantage.$$,
 $$+1d6 damage for each slot level above 1st.$$),
($$Hail of Thorns$$, 1, 'conjuration', '1 bonus action', 'Self', 'V', null, 'Concentration, up to 1 minute', false,
 array['Ranger'], 'damage',
 $$The next time you hit with a ranged weapon attack, thorns burst from the shot: the target and each creature within 5 feet of it make a Dexterity save, taking 1d10 piercing damage on a failure or half on a success. The spell then ends.$$,
 $$+1d10 damage for each slot level above 1st (maximum 6d10).$$),
($$Hellish Rebuke$$, 1, 'evocation', '1 reaction, which you take in response to being damaged by a creature within 60 feet of you that you can see', '60 feet', 'VS', null, 'Instantaneous', false,
 array['Warlock'], 'damage',
 $$The creature that damaged you is wreathed in flames and makes a Dexterity save, taking 2d10 fire damage on a failure or half on a success.$$,
 $$+1d10 damage for each slot level above 1st.$$),
($$Heroism$$, 1, 'enchantment', '1 action', 'Touch', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Bard','Paladin'], 'buff',
 $$A willing creature you touch is immune to being frightened and gains temporary hit points equal to your spellcasting ability modifier at the start of each of its turns. Any left over are lost when the spell ends.$$,
 $$One additional creature for each slot level above 1st.$$),
($$Hunter's Mark$$, 1, 'divination', '1 bonus action', '90 feet', 'V', null, 'Concentration, up to 1 hour', false,
 array['Ranger'], 'damage',
 $$Mark a creature you can see. Your weapon attacks against it deal an extra 1d6 damage, and you have advantage on Wisdom (Perception) and (Survival) checks to find it. If it drops to 0 hit points before the spell ends, you can use a bonus action on a later turn to mark a new creature.$$,
 $$Concentration up to 8 hours with a 3rd- or 4th-level slot, and up to 24 hours with a 5th-level slot or higher.$$),
($$Illusory Script$$, 1, 'illusion', '1 minute', 'Touch', 'SM', $$a lead-based ink worth at least 10 gp, which the spell consumes$$, '10 days', true,
 array['Bard','Warlock','Wizard'], 'utility',
 $$Write on parchment or paper so that the creatures you designate read the true message, while everyone else sees an unintelligible magical script or a different message you choose. Truesight reveals the hidden message. The spell can be dispelled, and it ends if the writing is destroyed.$$, null),
($$Inflict Wounds$$, 1, 'necromancy', '1 action', 'Touch', 'VS', null, 'Instantaneous', false,
 array['Cleric'], 'damage',
 $$Make a melee spell attack against a creature you can reach. On a hit it takes 3d10 necrotic damage.$$,
 $$+1d10 damage for each slot level above 1st.$$),
($$Purify Food and Drink$$, 1, 'transmutation', '1 action', '10 feet', 'VS', null, 'Instantaneous', true,
 array['Cleric','Druid','Paladin'], 'utility',
 $$All nonmagical food and drink within a 5-foot-radius sphere is purified and rendered free of poison and disease.$$, null),
($$Ray of Sickness$$, 1, 'necromancy', '1 action', '60 feet', 'VS', null, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'damage',
 $$Make a ranged spell attack. On a hit the target takes 2d8 poison damage and must make a Constitution save or be poisoned until the end of your next turn.$$,
 $$+1d8 damage for each slot level above 1st.$$),
($$Sanctuary$$, 1, 'abjuration', '1 bonus action', '30 feet', 'VSM', $$a small silver mirror$$, '1 minute', false,
 array['Cleric'], 'defense',
 $$Ward a creature. Anyone targeting it with an attack or harmful spell must first make a Wisdom save; on a failure they must choose a new target or lose the attack or spell. Area effects aren't stopped. The spell ends if the warded creature attacks, casts a spell that affects an enemy, or deals damage.$$, null),
($$Searing Smite$$, 1, 'evocation', '1 bonus action', 'Self', 'V', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'damage',
 $$The next time you hit with a melee weapon attack, the target takes an extra 1d6 fire damage and catches fire. At the start of each of its turns it makes a Constitution save, taking 1d6 fire damage on a failure; a success, or dousing the flames with an action, ends the spell.$$,
 $$The initial extra damage increases by 1d6 for each slot level above 1st.$$),
($$Shield of Faith$$, 1, 'abjuration', '1 bonus action', '60 feet', 'VSM', $$a small parchment with a bit of holy text written on it$$, 'Concentration, up to 10 minutes', false,
 array['Cleric','Paladin'], 'defense',
 $$A shimmering field surrounds a creature of your choice, granting it +2 to AC for the duration.$$, null),
($$Silent Image$$, 1, 'illusion', '1 action', '60 feet', 'VSM', $$a bit of fleece$$, 'Concentration, up to 10 minutes', false,
 array['Bard','Sorcerer','Wizard'], 'utility',
 $$Create the image of an object, creature or other visible thing no larger than a 15-foot cube. It has no sound, smell or temperature. You can use your action to move it within range and animate it. Physical contact reveals it; a creature that studies it with an action sees through it on an Intelligence (Investigation) check against your spell save DC.$$, null),
($$Speak with Animals$$, 1, 'divination', '1 action', 'Self', 'VS', null, '10 minutes', true,
 array['Bard','Druid','Ranger'], 'social',
 $$You can comprehend and verbally communicate with beasts. Their knowledge is limited by their intelligence, but they can tell you about nearby locations and monsters, and you might persuade one to do a small favour.$$, null),
($$Tasha's Hideous Laughter$$, 1, 'enchantment', '1 action', '30 feet', 'VSM', $$tiny tarts and a feather that is waved in the air$$, 'Concentration, up to 1 minute', false,
 array['Bard','Wizard'], 'control',
 $$A creature makes a Wisdom save or falls prone, incapacitated and unable to stand, laughing uncontrollably. Creatures with Intelligence 4 or lower are unaffected. It repeats the save at the end of each of its turns and whenever it takes damage (with advantage if the save is triggered by damage), ending the spell on a success.$$, null),
($$Tenser's Floating Disk$$, 1, 'conjuration', '1 action', '30 feet', 'VSM', $$a drop of mercury$$, '1 hour', true,
 array['Wizard'], 'utility',
 $$A flat 3-foot-diameter disk of force floats 3 feet off the ground and holds up to 500 pounds. It stays within 20 feet of you, following as you move. It can climb or descend no more than 10 feet at a time; if you move more than 100 feet away, it ends.$$, null),
($$Thunderous Smite$$, 1, 'evocation', '1 bonus action', 'Self', 'V', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'damage',
 $$The next time you hit with a melee weapon attack, your weapon rings with thunder audible within 300 feet. The target takes an extra 2d6 thunder damage and must succeed on a Strength save or be pushed 10 feet away from you and knocked prone.$$, null),
($$Unseen Servant$$, 1, 'conjuration', '1 action', '60 feet', 'VSM', $$a piece of string and a bit of wood$$, '1 hour', true,
 array['Bard','Warlock','Wizard'], 'utility',
 $$An invisible, mindless force (AC 10, 1 hit point, Strength 2, can't attack) performs simple tasks: fetching, cleaning, mending, folding, lighting fires, serving food, pouring wine. Once on each of your turns as a bonus action you can command it to move up to 15 feet and act. It ends if it goes more than 60 feet from you.$$, null),
($$Witch Bolt$$, 1, 'evocation', '1 action', '30 feet', 'VSM', $$a twig from a tree that has been struck by lightning$$, 'Concentration, up to 1 minute', false,
 array['Sorcerer','Warlock','Wizard'], 'damage',
 $$Make a ranged spell attack; on a hit the target takes 1d12 lightning damage. On each of your later turns you can use your action to deal 1d12 lightning damage to it automatically. The spell ends if you use your action for anything else, or the target ends up out of range or behind total cover.$$,
 $$The initial damage increases by 1d12 for each slot level above 1st.$$),
($$Wrathful Smite$$, 1, 'evocation', '1 bonus action', 'Self', 'V', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'control',
 $$The next time you hit with a melee weapon attack, the target takes an extra 1d6 psychic damage and must succeed on a Wisdom save or be frightened of you. It can use an action on a Wisdom check against your spell save DC to end the effect.$$, null);

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

insert into public.schema_migrations (version) values ('139');

commit;

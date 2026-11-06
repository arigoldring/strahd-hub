-- db/141_spells_phb_3.sql
--
-- Seeds the shared catalogue with the 2014 PHB's 3rd-level spells that 024 did not
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
($$Aura of Vitality$$, 3, 'evocation', '1 action', 'Self (30-foot radius)', 'V', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'healing',
 $$Healing energy radiates from you in a 30-foot aura. Until the spell ends, you can use a bonus action to make one creature in the aura (you included) regain 2d6 hit points.$$, null),
($$Beacon of Hope$$, 3, 'abjuration', '1 action', '30 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Cleric'], 'buff',
 $$Any number of creatures within range have advantage on Wisdom saving throws and death saving throws, and regain the maximum possible hit points from any healing.$$, null),
($$Blinding Smite$$, 3, 'evocation', '1 bonus action', 'Self', 'V', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'damage',
 $$The next time you hit with a melee weapon attack, the target takes an extra 3d8 radiant damage and must succeed on a Constitution save or be blinded until the spell ends. A blinded target repeats the save at the end of each of its turns.$$, null),
($$Clairvoyance$$, 3, 'divination', '10 minutes', '1 mile', 'VSM', $$a focus worth at least 100 gp, either a jeweled horn for hearing or a glass eye for seeing$$, 'Concentration, up to 10 minutes', false,
 array['Bard','Cleric','Sorcerer','Wizard'], 'detection',
 $$Create an invisible sensor at a location you know (a place you've visited or seen) or an obvious one (behind a door, around a corner). Choose seeing or hearing; you perceive through the sensor as if you were there, and can switch senses with an action. A creature that can see invisible things sees it as an orb the size of your fist.$$, null),
($$Conjure Barrage$$, 3, 'conjuration', '1 action', 'Self (60-foot cone)', 'VSM', $$one piece of ammunition or a thrown weapon$$, 'Instantaneous', false,
 array['Ranger'], 'damage',
 $$Throw a weapon or fire ammunition into the air and it multiplies. Each creature in a 60-foot cone makes a Dexterity save, taking 3d8 damage of the weapon's type on a failure or half on a success.$$, null),
($$Create Food and Water$$, 3, 'conjuration', '1 action', '30 feet', 'VS', null, 'Instantaneous', false,
 array['Cleric','Paladin'], 'utility',
 $$Create 45 pounds of bland but nourishing food and 30 gallons of fresh water, enough for fifteen humanoids or five steeds for 24 hours. The food spoils if uneaten after 24 hours.$$, null),
($$Crusader's Mantle$$, 3, 'evocation', '1 action', 'Self', 'V', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'buff',
 $$A holy aura extends 30 feet from you. While in it, each nonhostile creature (you included) deals an extra 1d4 radiant damage when it hits with a weapon attack.$$, null),
($$Elemental Weapon$$, 3, 'transmutation', '1 action', 'Touch', 'VS', null, 'Concentration, up to 1 hour', false,
 array['Paladin'], 'buff',
 $$A nonmagical weapon becomes magical. Choose acid, cold, fire, lightning or thunder: it gains +1 to attack rolls and deals an extra 1d4 damage of that type.$$,
 $$+2 and 2d4 with a 5th- or 6th-level slot; +3 and 3d4 with a 7th-level slot or higher.$$),
($$Feign Death$$, 3, 'necromancy', '1 action', 'Touch', 'VSM', $$a pinch of graveyard dirt$$, '1 hour', true,
 array['Bard','Cleric','Druid','Wizard'], 'utility',
 $$A willing creature appears dead to all outward inspection and to spells that determine status. It is blinded and incapacitated with speed 0, has resistance to all damage except psychic, and any disease or poison affecting it is paused for the duration. You can end the spell with an action.$$, null),
($$Gaseous Form$$, 3, 'transmutation', '1 action', 'Touch', 'VSM', $$a bit of gauze and a wisp of smoke$$, 'Concentration, up to 1 hour', false,
 array['Sorcerer','Warlock','Wizard'], 'movement',
 $$A willing creature and its gear become a misty cloud. It gains a 10-foot flying speed and can hover, has resistance to nonmagical damage, advantage on Strength, Dexterity and Constitution saves, and can pass through small holes and cracks. It can't talk, manipulate objects, attack or cast spells.$$, null),
($$Glyph of Warding$$, 3, 'abjuration', '1 hour', 'Touch', 'VSM', $$incense and powdered diamond worth at least 200 gp, which the spell consumes$$, 'Until dispelled or triggered', false,
 array['Bard','Cleric','Wizard'], 'damage',
 $$Inscribe a nearly invisible glyph on a surface or a closable object, with a trigger you set (finding it needs Intelligence (Investigation) against your spell save DC). The glyph breaks if its object is moved more than 10 feet. Explosive Runes: each creature in a 20-foot-radius sphere makes a Dexterity save, taking 5d8 acid, cold, fire, lightning or thunder damage on a failure or half on a success. Spell Glyph: store a prepared spell of 3rd level or lower, cast when triggered.$$,
 $$Explosive runes deal +1d8 for each slot level above 3rd; a spell glyph can store a spell up to the slot's level.$$),
($$Hunger of Hadar$$, 3, 'conjuration', '1 action', '150 feet', 'VSM', $$a pickled octopus tentacle$$, 'Concentration, up to 1 minute', false,
 array['Warlock'], 'damage',
 $$Open a 20-foot-radius sphere of blackness and bitter cold. It is magical darkness and difficult terrain. A creature starting its turn inside takes 2d6 cold damage; one ending its turn inside makes a Dexterity save or takes 2d6 acid damage.$$, null),
($$Hypnotic Pattern$$, 3, 'illusion', '1 action', '120 feet', 'SM', $$a glowing stick of incense or a crystal vial filled with phosphorescent material$$, 'Concentration, up to 1 minute', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'control',
 $$A twisting pattern of colours fills a 30-foot cube. Each creature in it that sees the pattern makes a Wisdom save or is charmed, incapacitated and has speed 0 for the duration. The effect ends for a creature that takes damage or that someone shakes awake with an action.$$, null),
($$Leomund's Tiny Hut$$, 3, 'evocation', '1 minute', 'Self (10-foot-radius hemisphere)', 'VSM', $$a small crystal bead$$, '8 hours', true,
 array['Bard','Wizard'], 'defense',
 $$An immobile dome of force forms around you. Up to nine Medium or smaller creatures fit inside. Creatures and objects inside when you cast it pass freely; nothing else can enter, and spells and magical effects can't extend through it. It is opaque from outside and comfortably lit and dry inside. The spell ends if you leave.$$, null),
($$Lightning Arrow$$, 3, 'transmutation', '1 bonus action', 'Self', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Ranger'], 'damage',
 $$Your next ranged weapon attack becomes a bolt of lightning: the target takes 4d8 lightning damage on a hit or half on a miss, instead of the weapon's damage. Then each creature within 10 feet of the target makes a Dexterity save, taking 2d8 lightning damage on a failure or half on a success.$$,
 $$Both damage rolls increase by 1d8 for each slot level above 3rd.$$),
($$Magic Circle$$, 3, 'abjuration', '1 minute', '10 feet', 'VSM', $$holy water or powdered silver and iron worth at least 100 gp, which the spell consumes$$, '1 hour', false,
 array['Cleric','Paladin','Warlock','Wizard'], 'defense',
 $$A 10-foot-radius, 20-foot-tall cylinder warding against celestials, elementals, fey, fiends or undead (choose types). Such a creature can't willingly enter by nonmagical means (it needs a Charisma save to teleport in), has disadvantage on attacks against targets inside, and can't charm, frighten or possess them. You can reverse the circle to keep a creature in instead.$$,
 $$The duration increases by 1 hour for each slot level above 3rd.$$),
($$Major Image$$, 3, 'illusion', '1 action', '120 feet', 'VSM', $$a bit of fleece$$, 'Concentration, up to 10 minutes', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'utility',
 $$Create the image of an object, creature or other phenomenon no larger than a 20-foot cube. It looks real and comes with sounds, smells and temperature, though not strong enough to deal damage. You can move and animate it with an action. Physical contact reveals it; a creature can study it with an Intelligence (Investigation) check against your spell save DC.$$,
 $$With a 6th-level slot or higher, it lasts until dispelled, without concentration.$$),
($$Mass Healing Word$$, 3, 'evocation', '1 bonus action', '60 feet', 'V', null, 'Instantaneous', false,
 array['Cleric'], 'healing',
 $$Up to six creatures you can see each regain 1d4 + your spellcasting ability modifier hit points. No effect on undead or constructs.$$,
 $$+1d4 healing for each slot level above 3rd.$$),
($$Meld into Stone$$, 3, 'transmutation', '1 action', 'Touch', 'VS', null, '8 hours', true,
 array['Cleric','Druid'], 'utility',
 $$Step into a stone object or surface large enough to hold you. Nothing outside can see you, and you hear sounds dimly. You can't move, but you can cast spells on yourself. Partial destruction of the stone expels you and deals 6d6 bludgeoning damage; total destruction or transmutation expels you and deals 50 bludgeoning damage.$$, null),
($$Nondetection$$, 3, 'abjuration', '1 action', 'Touch', 'VSM', $$a pinch of diamond dust worth 25 gp sprinkled over the target, which the spell consumes$$, '8 hours', false,
 array['Bard','Ranger','Wizard'], 'defense',
 $$Hide a willing creature, a place or an object no larger than 10 feet in any dimension from divination magic. It can't be targeted by divination or perceived through magical scrying sensors.$$, null),
($$Phantom Steed$$, 3, 'illusion', '1 minute', '30 feet', 'VS', null, '1 hour', true,
 array['Wizard'], 'movement',
 $$A Large quasi-real, horselike creature appears with saddle and bit. You or a creature you choose can ride it. It has a speed of 100 feet and can travel 10 miles in an hour (13 at a fast pace). The spell ends, and the steed fades, if it takes any damage.$$, null),
($$Plant Growth$$, 3, 'transmutation', '1 action or 8 hours', '150 feet', 'VS', null, 'Instantaneous', false,
 array['Bard','Druid','Ranger'], 'control',
 $$Cast as an action: plants in a 100-foot radius become thick and overgrown, and a creature moving through spends 4 feet of movement for every 1 foot (you can exclude areas). Cast over 8 hours: plants within half a mile become enriched and yield twice the normal food for a year.$$, null),
($$Protection from Energy$$, 3, 'abjuration', '1 action', 'Touch', 'VS', null, 'Concentration, up to 1 hour', false,
 array['Cleric','Druid','Ranger','Sorcerer','Wizard'], 'defense',
 $$A willing creature has resistance to one damage type you choose: acid, cold, fire, lightning or thunder.$$, null),
($$Remove Curse$$, 3, 'abjuration', '1 action', 'Touch', 'VS', null, 'Instantaneous', false,
 array['Cleric','Paladin','Warlock','Wizard'], 'healing',
 $$All curses affecting one creature or object end. On a cursed magic item, the curse remains, but the spell breaks its owner's attunement so the item can be removed or discarded.$$, null),
($$Sending$$, 3, 'evocation', '1 action', 'Unlimited', 'VSM', $$a short piece of fine copper wire$$, '1 round', false,
 array['Bard','Cleric','Wizard'], 'social',
 $$Send a message of up to 25 words to a creature you are familiar with. It hears the message in its mind, recognises you if it knows you, and can reply at once with 25 words of its own. Distance doesn't matter; a message to another plane has a 5% chance of not arriving.$$, null),
($$Slow$$, 3, 'transmutation', '1 action', '120 feet', 'VSM', $$a drop of molasses$$, 'Concentration, up to 1 minute', false,
 array['Sorcerer','Wizard'], 'control',
 $$Up to six creatures in a 40-foot cube make a Wisdom save. Each that fails has its speed halved, takes -2 to AC and Dexterity saves, can't take reactions, can take either an action or a bonus action on its turn (not both), and makes only one attack. A spell it casts with a casting time of 1 action has a 50% chance to wait until its next turn. It repeats the save at the end of each of its turns.$$, null),
($$Speak with Dead$$, 3, 'necromancy', '1 action', '10 feet', 'VSM', $$burning incense$$, '10 minutes', false,
 array['Bard','Cleric'], 'detection',
 $$A corpse that has a mouth and isn't undead can answer up to five questions you ask before the spell ends. It knows only what it knew in life, isn't compelled to be truthful, and answers briefly. The spell fails on a corpse that has been its target in the last 10 days.$$, null),
($$Speak with Plants$$, 3, 'transmutation', '1 action', 'Self (30-foot radius)', 'VS', null, '10 minutes', false,
 array['Bard','Druid','Ranger'], 'social',
 $$Plants within 30 feet gain limited sentience, so you can communicate with them and give them simple commands. They can tell you about events in the area in the past day. You can also turn difficult terrain caused by plants into ordinary terrain, or the reverse.$$, null),
($$Spirit Guardians$$, 3, 'conjuration', '1 action', 'Self (15-foot radius)', 'VSM', $$a holy symbol$$, 'Concentration, up to 10 minutes', false,
 array['Cleric'], 'damage',
 $$Spirits circle you to a distance of 15 feet; you choose creatures they ignore. An affected creature's speed is halved in the area, and when it enters for the first time on a turn or starts its turn there it makes a Wisdom save, taking 3d8 radiant damage (necrotic if you are evil) on a failure or half on a success.$$,
 $$+1d8 damage for each slot level above 3rd.$$),
($$Tongues$$, 3, 'divination', '1 action', 'Touch', 'VM', $$a small clay model of a ziggurat$$, '1 hour', false,
 array['Bard','Cleric','Sorcerer','Warlock','Wizard'], 'social',
 $$The creature you touch understands any spoken language it hears, and when it speaks, any creature that knows at least one language understands it.$$, null),
($$Vampiric Touch$$, 3, 'necromancy', '1 action', 'Self', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Warlock','Wizard'], 'damage',
 $$Make a melee spell attack. On a hit the target takes 3d6 necrotic damage and you regain hit points equal to half of it. You can repeat the attack as an action on each of your turns until the spell ends.$$,
 $$+1d6 damage for each slot level above 3rd.$$),
($$Water Breathing$$, 3, 'transmutation', '1 action', '30 feet', 'VSM', $$a short reed or piece of straw$$, '24 hours', true,
 array['Druid','Ranger','Sorcerer','Wizard'], 'utility',
 $$Up to ten willing creatures can breathe underwater for the duration, keeping their normal mode of breathing too.$$, null),
($$Water Walk$$, 3, 'transmutation', '1 action', '30 feet', 'VSM', $$a piece of cork$$, '1 hour', true,
 array['Cleric','Druid','Ranger','Sorcerer'], 'movement',
 $$Up to ten willing creatures can move across any liquid surface (water, acid, mud, snow, quicksand, lava) as if it were harmless solid ground, though dangerous liquids still deal damage. A submerged target rises 60 feet per round toward the surface.$$, null),
($$Wind Wall$$, 3, 'evocation', '1 action', '120 feet', 'VSM', $$a tiny fan and a feather of exotic origin$$, 'Concentration, up to 1 minute', false,
 array['Druid','Ranger'], 'defense',
 $$A wall of strong wind up to 50 feet long, 15 feet high and 1 foot thick rises. Each creature in it when it appears makes a Strength save, taking 3d8 bludgeoning damage on a failure or half on a success. It keeps fog, smoke and gases at bay; small flying creatures and objects can't pass; arrows, bolts and other ordinary missiles aimed through it automatically miss (giants' boulders and siege engine projectiles are unaffected).$$, null);

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

insert into public.schema_migrations (version) values ('141');

commit;

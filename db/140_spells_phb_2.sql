-- db/140_spells_phb_2.sql
--
-- Seeds the shared catalogue with the 2014 PHB's 2nd-level spells that 024
-- did not (138's header has the map of 138-147).
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
($$Alter Self$$, 2, 'transmutation', '1 action', 'Self', 'VS', null, 'Concentration, up to 1 hour', false,
 array['Sorcerer','Wizard'], 'utility',
 $$Choose one form, and use an action to switch while the spell lasts. Aquatic Adaptation: gills and webbing, so you breathe underwater and gain a swimming speed equal to your walking speed. Change Appearance: alter your looks, height and build (staying the same basic shape and size). Natural Weapons: claws, fangs, horns or hooves that deal 1d6 damage of a fitting type, with which you are proficient; they are magical and have +1 to attack and damage rolls.$$, null),
($$Animal Messenger$$, 2, 'enchantment', '1 action', '30 feet', 'VSM', $$a morsel of food$$, '24 hours', true,
 array['Bard','Druid','Ranger'], 'utility',
 $$A Tiny beast carries a message of up to 25 words to a place you have visited and a recipient you describe. It travels about 50 miles in 24 hours if it flies, 25 otherwise. On arrival it delivers the message in your voice, then waits there until the spell ends.$$,
 $$The duration increases by 48 hours for each slot level above 2nd.$$),
($$Arcane Lock$$, 2, 'abjuration', '1 action', 'Touch', 'VSM', $$gold dust worth at least 25 gp, which the spell consumes$$, 'Until dispelled', false,
 array['Wizard'], 'utility',
 $$A closed door, window, gate, chest or other entryway becomes magically locked. You and creatures you designate open it normally, and you can set a password that suppresses the spell for 1 minute. Otherwise the DC to break or pick it rises by 10. Knock suppresses it for 10 minutes.$$, null),
($$Augury$$, 2, 'divination', '1 minute', 'Self', 'VSM', $$specially marked sticks, bones, or similar tokens worth at least 25 gp$$, 'Instantaneous', true,
 array['Cleric'], 'detection',
 $$Ask about a specific course of action you plan within the next 30 minutes. The DM answers with an omen: weal (good), woe (bad), weal and woe, or nothing. Each casting after the first before a long rest has a cumulative 25% chance of a random reading.$$, null),
($$Beast Sense$$, 2, 'divination', '1 action', 'Touch', 'S', null, 'Concentration, up to 1 hour', true,
 array['Druid','Ranger'], 'detection',
 $$Touch a willing beast. For the duration you can use your action to see through its eyes and hear what it hears, gaining any special senses it has, until you use your action to return to your own senses. While doing so you are blind and deaf to your own surroundings.$$, null),
($$Branding Smite$$, 2, 'evocation', '1 bonus action', 'Self', 'V', null, 'Concentration, up to 1 minute', false,
 array['Paladin'], 'damage',
 $$The next time you hit with a weapon attack, the target takes an extra 2d6 radiant damage. An invisible target becomes visible, and until the spell ends it sheds dim light in a 5-foot radius and can't become invisible.$$,
 $$The extra damage increases by 1d6 for each slot level above 2nd.$$),
($$Calm Emotions$$, 2, 'enchantment', '1 action', '60 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Bard','Cleric'], 'social',
 $$Each humanoid in a 20-foot-radius sphere makes a Charisma save (a creature may choose to fail). Choose one effect for those that fail: suppress any effect making them charmed or frightened, or make them indifferent toward creatures they are hostile to (this ends if they are attacked or harmed, or see a friend harmed).$$, null),
($$Cloud of Daggers$$, 2, 'conjuration', '1 action', '60 feet', 'VSM', $$a sliver of glass$$, 'Concentration, up to 1 minute', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'damage',
 $$Spinning daggers fill a 5-foot cube. A creature takes 4d4 slashing damage when it enters the cube for the first time on a turn or starts its turn there.$$,
 $$+2d4 damage for each slot level above 2nd.$$),
($$Continual Flame$$, 2, 'evocation', '1 action', 'Touch', 'VSM', $$ruby dust worth 50 gp, which the spell consumes$$, 'Until dispelled', false,
 array['Cleric','Wizard'], 'utility',
 $$A flame as bright as a torch springs from an object you touch. It gives no heat, uses no oxygen, and can be covered or hidden but not smothered or quenched.$$, null),
($$Cordon of Arrows$$, 2, 'transmutation', '1 action', '5 feet', 'VSM', $$four or more arrows or bolts$$, '8 hours', false,
 array['Ranger'], 'damage',
 $$Plant four pieces of nonmagical ammunition in the ground. When a creature other than those you designate first comes within 30 feet of them on a turn, or ends its turn there, one piece flies at it: Dexterity save or 1d6 piercing damage. The spell ends when the ammunition is spent.$$,
 $$Two more pieces of ammunition for each slot level above 2nd.$$),
($$Crown of Madness$$, 2, 'enchantment', '1 action', '120 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'control',
 $$A humanoid makes a Wisdom save or is charmed. On each of its turns, before moving, it must make a melee attack against a creature other than itself that you mentally choose (it acts normally if there's no one in reach). You must use your action each turn to maintain control or the spell ends. It repeats the save at the end of each of its turns.$$, null),
($$Detect Thoughts$$, 2, 'divination', '1 action', 'Self', 'VSM', $$a copper piece$$, 'Concentration, up to 1 minute', false,
 array['Bard','Sorcerer','Wizard'], 'detection',
 $$Use your action to read the surface thoughts of a creature within 30 feet (Intelligence 4 or higher, and with a language). You can then probe deeper: it makes a Wisdom save, and on a failure you learn its reasoning, emotions and something on its mind; it knows you're probing either way. You can also sense thinking creatures you can't see within 30 feet. Blocked by 2 feet of rock, 2 inches of non-lead metal or a thin sheet of lead.$$, null),
($$Enlarge/Reduce$$, 2, 'transmutation', '1 action', '30 feet', 'VSM', $$a pinch of powdered iron$$, 'Concentration, up to 1 minute', false,
 array['Sorcerer','Wizard'], 'buff',
 $$A creature or unattended object grows or shrinks (an unwilling creature makes a Constitution save). Enlarged: size doubles, one size category larger, advantage on Strength checks and saves, and its weapons deal an extra 1d4 damage. Reduced: size halves, one category smaller, disadvantage on Strength checks and saves, and its weapons deal 1d4 less damage (minimum 1).$$, null),
($$Enthrall$$, 2, 'enchantment', '1 action', '60 feet', 'VS', null, '1 minute', false,
 array['Bard','Warlock'], 'social',
 $$Weave a distracting string of words. Creatures you choose that can hear you make a Wisdom save (automatic success if they can't be charmed; advantage if you or your companions are fighting them). On a failure they have disadvantage on Wisdom (Perception) checks made to perceive anyone but you, until the spell ends or they can no longer hear you.$$, null),
($$Find Steed$$, 2, 'conjuration', '10 minutes', '30 feet', 'VS', null, 'Instantaneous', false,
 array['Paladin'], 'summoning',
 $$Summon a spirit that takes the form of an unusually intelligent steed: a warhorse, pony, camel, elk or mastiff (or another the DM allows). It is a celestial, fey or fiend with Intelligence 6, understands one of your languages, and fights as your mount. While mounted, a spell you cast that targets only you can also target it. Within 1 mile you can communicate telepathically. At 0 hit points it vanishes; recast to summon it again. Only one at a time.$$, null),
($$Find Traps$$, 2, 'divination', '1 action', '120 feet', 'VS', null, 'Instantaneous', false,
 array['Cleric','Druid','Ranger'], 'detection',
 $$You sense any trap within range and in line of sight (anything designed to harm or hinder by surprise, including glyphs and pits, but not natural hazards). You learn that a trap is present and its general nature, not its exact location.$$, null),
($$Flame Blade$$, 2, 'evocation', '1 bonus action', 'Self', 'VSM', $$leaf of sumac$$, 'Concentration, up to 10 minutes', false,
 array['Druid'], 'damage',
 $$A fiery blade like a scimitar forms in your hand and sheds bright light for 10 feet and dim light for 10 more. Make a melee spell attack with it for 3d6 fire damage. You can dismiss it and call it back as a bonus action.$$,
 $$+1d6 damage for every two slot levels above 2nd.$$),
($$Flaming Sphere$$, 2, 'conjuration', '1 action', '60 feet', 'VSM', $$a bit of tallow, a pinch of brimstone, and a dusting of powdered iron$$, 'Concentration, up to 1 minute', false,
 array['Druid','Wizard'], 'damage',
 $$A 5-foot sphere of fire appears, shedding bright light for 20 feet and dim light for 20 more. A creature that ends its turn within 5 feet of it makes a Dexterity save, taking 2d6 fire damage on a failure or half on a success. As a bonus action you can roll it up to 30 feet; ramming a creature forces the same save and stops the sphere.$$,
 $$+1d6 damage for each slot level above 2nd.$$),
($$Gentle Repose$$, 2, 'necromancy', '1 action', 'Touch', 'VSM', $$a pinch of salt and one copper piece placed on each of the corpse's eyes, which must remain there for the duration$$, '10 days', true,
 array['Cleric','Wizard'], 'utility',
 $$A corpse is protected from decay and can't become undead. The time it spends under this spell doesn't count toward the time limit of spells such as raise dead.$$, null),
($$Lesser Restoration$$, 2, 'abjuration', '1 action', 'Touch', 'VS', null, 'Instantaneous', false,
 array['Bard','Cleric','Druid','Paladin','Ranger'], 'healing',
 $$End one disease or one condition afflicting the creature you touch: blinded, deafened, paralyzed or poisoned.$$, null),
($$Locate Animals or Plants$$, 2, 'divination', '1 action', 'Self', 'VSM', $$a bit of fur from a bloodhound$$, 'Instantaneous', true,
 array['Bard','Druid','Ranger'], 'detection',
 $$Name a specific kind of beast or plant. You learn the direction and distance to the closest one within 5 miles, if any.$$, null),
($$Locate Object$$, 2, 'divination', '1 action', 'Self', 'VSM', $$a forked twig$$, 'Concentration, up to 10 minutes', false,
 array['Bard','Cleric','Druid','Paladin','Ranger','Wizard'], 'detection',
 $$Describe or name an object familiar to you. You sense the direction to it while it is within 1,000 feet, and you can look for the nearest object of a kind instead. A specific object must be one you've seen up close (within 30 feet) at least once. Any thickness of lead blocks the spell.$$, null),
($$Magic Mouth$$, 2, 'illusion', '1 minute', '30 feet', 'VSM', $$a small bit of honeycomb and jade dust worth at least 10 gp, which the spell consumes$$, 'Until dispelled', true,
 array['Bard','Wizard'], 'utility',
 $$Implant a message of up to 25 words in an object, spoken over up to 10 minutes, with a trigger condition you set (something visible or audible within 30 feet). When it's met, a mouth appears and speaks the message in your voice. It can trigger once or every time.$$, null),
($$Melf's Acid Arrow$$, 2, 'evocation', '1 action', '90 feet', 'VSM', $$powdered rhubarb leaf and an adder's stomach$$, 'Instantaneous', false,
 array['Wizard'], 'damage',
 $$Make a ranged spell attack. On a hit the target takes 4d4 acid damage immediately and 2d4 more at the end of its next turn. On a miss it takes half the initial damage and nothing later.$$,
 $$Both the initial and the later damage increase by 1d4 for each slot level above 2nd.$$),
($$Moonbeam$$, 2, 'evocation', '1 action', '120 feet', 'VSM', $$several seeds of any moonseed plant and a piece of opalescent feldspar$$, 'Concentration, up to 1 minute', false,
 array['Druid'], 'damage',
 $$A 5-foot-radius, 40-foot-high cylinder of pale light appears. A creature that enters it for the first time on a turn or starts its turn there makes a Constitution save, taking 2d10 radiant damage on a failure or half on a success. A shapechanger has disadvantage and reverts to its true form on a failure. As an action you can move the beam up to 60 feet.$$,
 $$+1d10 damage for each slot level above 2nd.$$),
($$Nystul's Magic Aura$$, 2, 'illusion', '1 action', 'Touch', 'VSM', $$a small square of silk$$, '24 hours', false,
 array['Wizard'], 'utility',
 $$Disguise how a creature or object reads to divination. False Aura: make an object appear nonmagical, or magical with an aura of the school you choose. Mask: make a creature register as a different creature type and alignment to spells that detect them. Cast on the same target every day for 30 days and it lasts until dispelled.$$, null),
($$Phantasmal Force$$, 2, 'illusion', '1 action', '60 feet', 'VSM', $$a bit of fleece$$, 'Concentration, up to 1 minute', false,
 array['Bard','Sorcerer','Wizard'], 'control',
 $$A creature makes an Intelligence save or perceives a phantasm (an object, creature or phenomenon no larger than a 10-foot cube) that only it can see, and rationalises any illogic. A harmful phantasm deals 1d6 psychic damage on each of your turns if the target is in or within 5 feet of it. The target can use its action on an Intelligence (Investigation) check against your spell save DC to see through it.$$, null),
($$Prayer of Healing$$, 2, 'evocation', '10 minutes', '30 feet', 'V', null, 'Instantaneous', false,
 array['Cleric'], 'healing',
 $$Up to six creatures you can see each regain 2d8 + your spellcasting ability modifier hit points. No effect on undead or constructs.$$,
 $$+1d8 healing for each slot level above 2nd.$$),
($$Protection from Poison$$, 2, 'abjuration', '1 action', 'Touch', 'VS', null, '1 hour', false,
 array['Cleric','Druid','Paladin','Ranger'], 'defense',
 $$Neutralise one poison affecting the creature you touch (one at random if there are several). For the duration it has advantage on saving throws against being poisoned and resistance to poison damage.$$, null),
($$Rope Trick$$, 2, 'transmutation', '1 action', 'Touch', 'VSM', $$powdered corn extract and a twisted loop of parchment$$, '1 hour', false,
 array['Wizard'], 'utility',
 $$A rope up to 60 feet long rises until it hangs straight up, and an invisible entrance opens at its top to an extradimensional space that holds up to eight Medium or smaller creatures. The rope can be pulled inside. Attacks and spells can't cross the entrance. When the spell ends, everything inside falls out.$$, null),
($$See Invisibility$$, 2, 'divination', '1 action', 'Self', 'VSM', $$a pinch of talc and a small sprinkling of powdered silver$$, '1 hour', false,
 array['Bard','Sorcerer','Wizard'], 'detection',
 $$You see invisible creatures and objects as if they were visible, and you can see into the Ethereal Plane, where creatures and objects appear ghostly and translucent.$$, null),
($$Shatter$$, 2, 'evocation', '1 action', '60 feet', 'VSM', $$a chip of mica$$, 'Instantaneous', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'damage',
 $$A painfully loud ringing bursts from a point you choose. Each creature in a 10-foot-radius sphere makes a Constitution save, taking 3d8 thunder damage on a failure or half on a success. Creatures made of inorganic material such as stone, crystal or metal have disadvantage. Nonmagical objects in the area that aren't worn or carried also take the damage.$$,
 $$+1d8 damage for each slot level above 2nd.$$),
($$Silence$$, 2, 'illusion', '1 action', '120 feet', 'VS', null, 'Concentration, up to 10 minutes', true,
 array['Bard','Cleric','Ranger'], 'control',
 $$No sound can be created within or pass through a 20-foot-radius sphere. Any creature or object entirely inside is immune to thunder damage, and creatures entirely inside are deafened. Casting a spell with a verbal component is impossible there.$$, null),
($$Spider Climb$$, 2, 'transmutation', '1 action', 'Touch', 'VSM', $$a drop of bitumen and a spider$$, 'Concentration, up to 1 hour', false,
 array['Sorcerer','Warlock','Wizard'], 'movement',
 $$A willing creature can move up, down and across vertical surfaces and upside down along ceilings with its hands free, and gains a climbing speed equal to its walking speed.$$, null),
($$Spike Growth$$, 2, 'transmutation', '1 action', '150 feet', 'VSM', $$seven sharp thorns or seven small twigs, each sharpened to a point$$, 'Concentration, up to 10 minutes', false,
 array['Druid','Ranger'], 'control',
 $$The ground in a 20-foot radius sprouts hard spikes. It becomes difficult terrain, and a creature moving into or within it takes 2d4 piercing damage for every 5 feet it travels. The area is camouflaged: a creature that didn't see it cast needs a Wisdom (Perception) check against your spell save DC to notice it before entering.$$, null),
($$Warding Bond$$, 2, 'abjuration', '1 action', 'Touch', 'VSM', $$a pair of platinum rings worth at least 50 gp each, which you and the target must wear for the duration$$, '1 hour', false,
 array['Cleric'], 'defense',
 $$A willing creature gains +1 to AC and saving throws and resistance to all damage. Each time it takes damage, you take the same amount. The spell ends if you drop to 0 hit points or the two of you are more than 60 feet apart.$$, null),
($$Zone of Truth$$, 2, 'enchantment', '1 action', '60 feet', 'VS', null, '10 minutes', false,
 array['Bard','Cleric','Paladin'], 'social',
 $$A 15-foot-radius sphere guards against deception. A creature entering it for the first time on a turn or starting its turn there makes a Charisma save; on a failure it can't speak a deliberate lie while in the area. You know whether each creature succeeds. An affected creature is aware of the spell and can still evade questions.$$, null);

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

insert into public.schema_migrations (version) values ('140');

commit;

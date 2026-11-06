-- db/144_spells_phb_8_9.sql
--
-- Seeds the shared catalogue with the 2014 PHB's 8th- and 9th-level spells (Feeblemind, the one 8th already present, 138 moved there)
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
-- 8th level ----------------------------------------------------------------
($$Animal Shapes$$, 8, 'transmutation', '1 action', '30 feet', 'VS', null, 'Concentration, up to 24 hours', false,
 array['Druid'], 'utility',
 $$Turn any number of willing creatures you can see into beasts of your choice, Large or smaller with challenge rating 4 or lower (each can be different). They use the beast's statistics but keep their alignment and personality, and take the new form's hit points, reverting at 0 with any extra damage carried over. On later turns you can use an action to give them new forms.$$, null),
($$Antimagic Field$$, 8, 'abjuration', '1 action', 'Self (10-foot-radius sphere)', 'VSM', $$a pinch of powdered iron or iron filings$$, 'Concentration, up to 1 hour', false,
 array['Cleric','Wizard'], 'defense',
 $$A 10-foot-radius sphere of antimagic surrounds you and moves with you. Inside it spells can't be cast, magical effects (including magic items' properties) are suppressed, summoned creatures wink out, and teleportation in or out fails. Gods' magic and artifacts aren't affected. Time inside still counts toward suppressed effects' durations.$$, null),
($$Antipathy/Sympathy$$, 8, 'enchantment', '1 hour', '60 feet', 'VSM', $$either a lump of alum soaked in vinegar for the antipathy effect or a drop of honey for the sympathy effect$$, '10 days', false,
 array['Druid','Wizard'], 'control',
 $$Enchant a creature, an object, or an area up to a 200-foot cube to repel or attract a kind of intelligent creature you name (such as red dragons or goblins). Antipathy: a creature of that kind within 60 feet makes a Wisdom save or is frightened and must move away. Sympathy: it makes a Wisdom save or feels compelled to approach and stay near. Affected creatures repeat the save when they move away or take damage.$$, null),
($$Clone$$, 8, 'necromancy', '1 hour', 'Touch', 'VSM', $$a diamond worth at least 1,000 gp and at least 1 cubic inch of flesh of the creature that is to be cloned, which the spell consumes, and a vessel worth at least 2,000 gp that has a sealable lid and is large enough to hold a Medium creature$$, 'Instantaneous', false,
 array['Wizard'], 'utility',
 $$Grow an inert duplicate of a living creature in a sealed vessel; it matures in 120 days, and you can choose a younger age. If the original dies after the clone has matured, its soul moves into the clone (if willing), which has the original's memories, personality and abilities but none of its equipment.$$, null),
($$Control Weather$$, 8, 'transmutation', '10 minutes', 'Self (5-mile radius)', 'VSM', $$burning incense and bits of earth and wood mixed in water$$, 'Concentration, up to 8 hours', false,
 array['Cleric','Druid','Wizard'], 'control',
 $$Outdoors only. Take control of the weather within 5 miles for the duration, shifting precipitation, temperature and wind each by one stage at a time on the DM's tables. Each change takes 1d4 x 10 minutes to arrive. When the spell ends, the weather gradually returns to normal.$$, null),
($$Demiplane$$, 8, 'conjuration', '1 action', '60 feet', 'S', null, '1 hour', false,
 array['Warlock','Wizard'], 'utility',
 $$A shadowy Medium door appears on a flat solid surface, leading to an empty 30-foot-cube demiplane of wood or stone. The door vanishes when the spell ends, trapping anyone still inside. Each casting can make a new demiplane or reconnect to one you made before, or to another caster's if you know its nature and contents.$$, null),
($$Dominate Monster$$, 8, 'enchantment', '1 action', '60 feet', 'VS', null, 'Concentration, up to 1 hour', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'control',
 $$A creature makes a Wisdom save (advantage if you or your companions are fighting it) or is charmed. While it is, you can give it telepathic commands, or use your action to control it precisely, including its reaction. Each time it takes damage it repeats the save.$$,
 $$With a 9th-level slot, concentration up to 8 hours.$$),
($$Earthquake$$, 8, 'evocation', '1 action', '500 feet', 'VSM', $$a pinch of dirt, a piece of rock, and a lump of clay$$, 'Concentration, up to 1 minute', false,
 array['Cleric','Druid','Sorcerer'], 'damage',
 $$The ground heaves in a 100-foot radius, becoming difficult terrain. Concentrating creatures in it must make Constitution saves or lose concentration. When you cast it and at the end of each of your turns, creatures on the ground make a Dexterity save or fall prone. Fissures open (1d6 of them), swallowing creatures that fail a Dexterity save, and structures take 50 bludgeoning damage each turn, collapsing on nearby creatures (Dexterity save, 5d6 bludgeoning damage and pinned on a failure).$$, null),
($$Glibness$$, 8, 'transmutation', '1 action', 'Self', 'V', null, '1 hour', false,
 array['Bard','Warlock'], 'social',
 $$Whenever you make a Charisma check, you can replace the number you roll with a 15. And no matter what you say, magic that would determine whether you are telling the truth indicates that you are.$$, null),
($$Holy Aura$$, 8, 'abjuration', '1 action', 'Self', 'VSM', $$a tiny reliquary worth at least 1,000 gp containing a sacred relic$$, 'Concentration, up to 1 minute', false,
 array['Cleric'], 'defense',
 $$Divine light radiates from you; creatures you choose within 30 feet shed dim light in a 5-foot radius. They have advantage on all saves, and other creatures have disadvantage on attack rolls against them. A fiend or undead that hits one with a melee attack makes a Constitution save or is blinded until the spell ends.$$, null),
($$Incendiary Cloud$$, 8, 'conjuration', '1 action', '150 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Sorcerer','Wizard'], 'damage',
 $$A 20-foot-radius sphere of smoke and embers heavily obscures its area. A creature in it when it appears, entering it for the first time on a turn or ending its turn there makes a Dexterity save, taking 10d8 fire damage on a failure or half on a success. The cloud drifts 10 feet away from you at the start of each of your turns.$$, null),
($$Maze$$, 8, 'conjuration', '1 action', '60 feet', 'VS', null, 'Concentration, up to 10 minutes', false,
 array['Wizard'], 'control',
 $$Banish a creature, with no save, into a labyrinthine demiplane. It can use its action to make a DC 20 Intelligence check to escape, returning to the space it left (or the nearest free one). Minotaurs and goristro demons succeed automatically.$$, null),
($$Mind Blank$$, 8, 'abjuration', '1 action', 'Touch', 'VS', null, '24 hours', false,
 array['Bard','Wizard'], 'defense',
 $$A willing creature is immune to psychic damage, to any effect that would sense its emotions or read its thoughts, to divination spells, and to the charmed condition. The spell even foils wish and similar magic used to affect its mind or learn about it.$$, null),
($$Power Word Stun$$, 8, 'enchantment', '1 action', '60 feet', 'V', null, 'Instantaneous', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'control',
 $$Speak a word of power at a creature you can see. If it has 150 hit points or fewer, it is stunned, with no initial save; otherwise nothing happens. A stunned target makes a Constitution save at the end of each of its turns, ending the effect on a success.$$, null),
($$Sunburst$$, 8, 'evocation', '1 action', '150 feet', 'VSM', $$fire and a piece of sunstone$$, 'Instantaneous', false,
 array['Druid','Sorcerer','Wizard'], 'damage',
 $$Sunlight blazes in a 60-foot radius. Each creature in it makes a Constitution save, taking 12d6 radiant damage and being blinded for 1 minute on a failure, or half damage and no blindness on a success. Undead and oozes have disadvantage. A blinded creature repeats the save at the end of each of its turns. The light dispels any darkness from spells in the area.$$, null),
($$Telepathy$$, 8, 'evocation', '1 action', 'Unlimited', 'VSM', $$a pair of linked silver rings$$, '24 hours', false,
 array['Wizard'], 'social',
 $$Create a telepathic link with a willing creature you are familiar with, anywhere on the same plane. Until the spell ends you can instantly share words, images, sounds and other sensory messages, even without a shared language.$$, null),
($$Tsunami$$, 8, 'conjuration', '1 minute', 'Sight', 'VS', null, 'Concentration, up to 6 rounds', false,
 array['Druid'], 'damage',
 $$A wall of water up to 300 feet long, 300 feet high and 50 feet thick appears. Each creature in it makes a Strength save, taking 6d10 bludgeoning damage on a failure or half on a success. At the start of each of your turns the wall moves 50 feet away from you, losing 50 feet of height and 1d10 of damage each round, carrying creatures with it.$$, null),

-- 9th level ----------------------------------------------------------------
($$Astral Projection$$, 9, 'necromancy', '1 hour', '10 feet', 'VSM', $$for each creature you affect with this spell, one jacinth worth at least 1,000 gp and one ornately carved bar of silver worth at least 100 gp, all of which the spell consumes$$, 'Special', false,
 array['Cleric','Warlock','Wizard'], 'movement',
 $$You and up to eight willing creatures project your astral bodies into the Astral Plane, leaving your physical bodies in suspended animation. Each astral body is joined to its own by a silvery cord; if the cord is cut, the body and the projection both die. A projection that drops to 0 hit points returns to its body, which wakes.$$, null),
($$Foresight$$, 9, 'divination', '1 minute', 'Touch', 'VSM', $$a hummingbird feather$$, '8 hours', false,
 array['Bard','Druid','Warlock','Wizard'], 'buff',
 $$A willing creature gains a limited ability to see the immediate future. It can't be surprised, has advantage on attack rolls, ability checks and saving throws, and other creatures have disadvantage on attack rolls against it.$$, null),
($$Gate$$, 9, 'conjuration', '1 action', '60 feet', 'VSM', $$a diamond worth at least 5,000 gp$$, 'Concentration, up to 1 minute', false,
 array['Cleric','Sorcerer','Wizard'], 'summoning',
 $$Open a circular portal 5 to 20 feet across to a precise spot on another plane. Deities and planar rulers can block gates into their realms. When you cast it you can also name a specific creature (not a god): it is pulled through to you, but isn't under your control.$$, null),
($$Imprisonment$$, 9, 'abjuration', '1 minute', '30 feet', 'VSM', $$a vellum depiction or a carved statuette in the likeness of the target, and a special component that varies according to the version of the spell you choose, worth at least 500 gp per Hit Die of the target$$, 'Until dispelled', false,
 array['Warlock','Wizard'], 'control',
 $$A creature makes a Wisdom save or is bound, kept out of reach of divination and teleportation. Choose the prison: Burial (a sphere of force deep underground), Chaining (heavy chains, restrained), Hedged Prison (a tiny demiplane), Minimus Containment (shrunk to an inch inside a gem or similar) or Slumber (endless sleep). You set a condition that ends it; dispel magic only works when cast with a 9th-level slot.$$, null),
($$Mass Heal$$, 9, 'evocation', '1 action', '60 feet', 'VS', null, 'Instantaneous', false,
 array['Cleric'], 'healing',
 $$Restore up to 700 hit points, divided as you choose among any number of creatures you can see. Each is also cured of all diseases and of being blinded or deafened. No effect on undead or constructs.$$, null),
($$Meteor Swarm$$, 9, 'evocation', '1 action', '1 mile', 'VS', null, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'damage',
 $$Four blazing orbs strike four points you can see, each exploding in a 40-foot-radius sphere. Each creature in an area makes a Dexterity save, taking 20d6 fire damage and 20d6 bludgeoning damage on a failure or half on a success. A creature in more than one sphere is affected only once. Flammable objects catch fire.$$, null),
($$Power Word Heal$$, 9, 'evocation', '1 action', 'Touch', 'VS', null, 'Instantaneous', false,
 array['Bard'], 'healing',
 $$A creature you touch regains all its hit points, and is no longer charmed, frightened, paralyzed or stunned. If it was prone it can use its reaction to stand. No effect on undead or constructs.$$, null),
($$Power Word Kill$$, 9, 'enchantment', '1 action', '60 feet', 'V', null, 'Instantaneous', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'damage',
 $$Speak a word of power at a creature you can see. If it has 100 hit points or fewer, it dies, with no save. Otherwise nothing happens.$$, null),
($$Prismatic Wall$$, 9, 'abjuration', '1 action', '60 feet', 'VS', null, '10 minutes', false,
 array['Wizard'], 'defense',
 $$A shimmering wall up to 90 feet long and 30 feet high, or a globe up to 30 feet across, made of seven coloured layers. Creatures you choose pass safely. Anyone else within 20 feet who sees it makes a Constitution save or is blinded for 1 minute. Passing through means a Dexterity save against each layer in turn: red 10d6 fire, orange 10d6 acid, yellow 10d6 lightning, green 10d6 poison, blue 10d6 cold (half on a success), indigo restrained and then petrified, violet blinded and then sent to another plane. Each layer is destroyed by a specific means (such as cold for red, or dispel magic for violet).$$, null),
($$Shapechange$$, 9, 'transmutation', '1 action', 'Self', 'VSM', $$a jade circlet worth at least 1,500 gp, which you must place on your head before you cast the spell$$, 'Concentration, up to 1 hour', false,
 array['Druid','Wizard'], 'utility',
 $$Become a creature whose challenge rating is no higher than your level (not a construct or undead, and one you've seen). You take its physical statistics and hit points, keeping your alignment and Intelligence, Wisdom and Charisma, and can still cast spells if the form can speak and gesture. As an action you can switch to a new form. At 0 hit points you revert, with extra damage carried over.$$, null),
($$Storm of Vengeance$$, 9, 'conjuration', '1 action', 'Sight', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Druid'], 'damage',
 $$A churning storm cloud spreads 360 feet around a point you can see. Round 1: each creature under it makes a Constitution save or takes 2d6 thunder damage and is deafened for 5 minutes. Round 2: acid rain, 1d6 acid damage. Round 3: six lightning bolts strike creatures or objects you choose (Dexterity save, 10d6 lightning, half on a success). Round 4: hail, 2d6 bludgeoning damage. Rounds 5-10: gusts and freezing rain, 1d6 cold damage per round, difficult terrain, ranged weapon attacks impossible, and heavy obscurement.$$, null),
($$Time Stop$$, 9, 'transmutation', '1 action', 'Self', 'V', null, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'utility',
 $$Time stops for everyone but you. You take 1d4 + 1 turns in a row, using actions and moving as normal. The spell ends early if anything you do during it affects another creature or an object someone else is wearing or carrying, or if you move more than 1,000 feet from where you cast it.$$, null),
($$True Polymorph$$, 9, 'transmutation', '1 action', '30 feet', 'VSM', $$a drop of mercury, a dollop of gum arabic, and a wisp of smoke$$, 'Concentration, up to 1 hour', false,
 array['Bard','Warlock','Wizard'], 'control',
 $$Transform a creature into another creature (challenge rating up to its own CR or level), a creature into a nonmagical object, or an object into a creature. An unwilling creature makes a Wisdom save. A new creature form uses its statistics and new hit points, reverting at 0. Concentrate for the full hour and the change lasts until dispelled.$$, null),
($$True Resurrection$$, 9, 'necromancy', '1 hour', 'Touch', 'VSM', $$a sprinkle of holy water and diamonds worth at least 25,000 gp, which the spell consumes$$, 'Instantaneous', false,
 array['Cleric','Druid'], 'healing',
 $$Return a creature dead no longer than 200 years, from any cause except old age, to life with all its hit points. It closes wounds, neutralises poison, cures disease, lifts curses, restores missing parts, and works on undead. If the body is gone, you can name the creature and it reappears in a new body you choose.$$, null),
($$Weird$$, 9, 'illusion', '1 action', '120 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Wizard'], 'damage',
 $$Creatures you choose in a 30-foot-radius sphere each see their deepest fears made real and make a Wisdom save or are frightened. At the end of each of its turns, a frightened creature repeats the save, taking 4d10 psychic damage on a failure; a success ends the spell for it.$$, null),
($$Wish$$, 9, 'conjuration', '1 action', 'Self', 'V', null, 'Instantaneous', false,
 array['Sorcerer','Wizard'], 'utility',
 $$The mightiest spell a mortal can cast. Safely, it duplicates any other spell of 8th level or lower without needing its components. It can also do other things (create a valuable object, grant resistance, heal up to twenty creatures, undo a recent event), or anything else you ask, at the DM's discretion. Anything beyond duplicating a spell leaves you weakened (necrotic damage when you cast spells, Strength 3 for 2d4 days) and carries a 33% chance you can never cast wish again.$$, null);

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

insert into public.schema_migrations (version) values ('144');

commit;

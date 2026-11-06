-- db/131_magic_items_dmg_c_f.sql
--
-- The DMG's magic items, C-F. Second of eight seed files on 129's columns;
-- 130's header carries the reasoning for all eight (one row per rarity,
-- kind 'general', price 0, summaries in our own words, temp-table shape with
-- an end-state assertion). Only what differs is noted here:
--
-- Crystal Ball is four rows, because its three variants are legendary and the
-- plain ball very rare. Figurine of Wondrous Power is 'varies' (silver raven
-- uncommon, obsidian steed very rare, the rest rare). Daern's Instant
-- Fortress is under D, the book's name.
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
($$Candle of Invocation$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Aligned to one alignment. While lit (4 hours of burn), creatures of that alignment have advantage on attacks, saves and checks, and matching clerics and druids cast 1st-level spells without slots. Can instead cast gate once, consuming it.$$),
($$Cap of Water Breathing$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Underwater, speak its command word as an action to wrap your head in a bubble of air, letting you breathe normally until you speak it again or remove the cap.$$),
($$Cape of the Mountebank$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Smells faintly of brimstone. Once per dawn, as an action, cast dimension door, vanishing and reappearing in puffs of smoke.$$),
($$Carpet of Flying$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Flies at your command. Its size sets its capacity and speed, from 3x5 feet (one rider, 80 feet) to 6x9 feet (several riders, 30 feet); speed halves if overloaded.$$),
($$Censer of Controlling Air Elementals$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Lit and commanded as an action, it summons an air elemental, as conjure elemental. Once per dawn.$$),
($$Chime of Opening$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Struck and pointed at a lock, lid or door within 120 feet, it opens one lock or latch, ending a knock-style hold too. Ten uses, then it cracks.$$),
($$Circlet of Blasting$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Once per dawn, cast scorching ray with it, with a +5 attack bonus.$$),
($$Cloak of Arachnida$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Resistance to poison, a climbing speed equal to your walking speed including on ceilings, immunity to webs, and once per dawn cast web (DC 13) at double size.$$),
($$Cloak of Displacement$$, 'rare', true, null, array['wondrous item','DMG'],
 $$You appear to stand slightly off from your real spot: attacks against you have disadvantage. The effect stops until your next turn whenever you take damage, and while you are incapacitated or can't move.$$),
($$Cloak of Elvenkind$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$With the hood up, Wisdom (Perception) checks to see you have disadvantage and your Dexterity (Stealth) checks to hide have advantage.$$),
($$Cloak of Invisibility$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$Pull up the hood as an action to become invisible until you lower it. Works for up to 2 hours, recovering 1 hour of use for every 12 hours it isn't used.$$),
($$Cloak of Protection$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$+1 bonus to AC and to saving throws.$$),
($$Cloak of the Bat$$, 'rare', true, null, array['wondrous item','DMG'],
 $$Advantage on Stealth checks. In dim light or darkness, hold its edges to fly at 40 feet, and once per dawn polymorph into a bat while keeping your mental scores.$$),
($$Cloak of the Manta Ray$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$With the hood up you can breathe underwater and have a swimming speed of 60 feet.$$),
($$Crystal Ball$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Cast scrying (DC 17) through it while touching it.$$),
($$Crystal Ball of Mind Reading$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$A crystal ball that also lets you cast detect thoughts (DC 17) on creatures you see through its scrying sensor.$$),
($$Crystal Ball of Telepathy$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$A crystal ball that also lets you speak telepathically with creatures you see through its sensor, and once per dawn cast suggestion (DC 17) through it.$$),
($$Crystal Ball of True Seeing$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$A crystal ball whose scrying sensor also grants you truesight out to 120 feet around it.$$),
($$Cube of Force$$, 'rare', true, null, array['wondrous item','DMG'],
 $$36 charges. Pressing a face spends charges to raise a cube of force around you that blocks gases, nonliving matter, living matter or everything, as chosen. Some spells and attacks drain extra charges. Regains 1d20 at dawn.$$),
($$Cubic Gate$$, 'legendary', false, null, array['wondrous item','DMG'],
 $$Each of its six faces is keyed to a plane, one of them the Material. 3 charges: spend one to cast gate to a face's plane, or plane shift a creature there (DC 15 Charisma). Regains 1d3 at dawn.$$),
($$Daern's Instant Fortress$$, 'rare', false, null, array['wondrous item','DMG'],
 $$A one-inch metal cube that, on its command word, grows into a 20-foot square, 30-foot tall tower with arrow slits, a door that answers only you, and an adamantine body that resists harm. Shrinks back on command if empty.$$),
($$Dagger of Venom$$, 'rare', false, null, array['weapon','DMG'],
 $$+1 dagger. Once per dawn, coat the blade in poison for 1 minute: the next creature hit makes a DC 15 Constitution save or takes 2d10 poison and is poisoned for 1 minute.$$),
($$Dancing Sword$$, 'very rare', true, null, array['weapon','DMG'],
 $$Any sword. As a bonus action, toss it into the air and it floats, attacking a creature within 5 feet of it on your bonus action using your attack and damage modifiers. After four attacks it returns to your hand.$$),
($$Decanter of Endless Water$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Speak a command word to pour 1 gallon (stream), 5 gallons (fountain) or a 30-foot geyser of 30 gallons that can knock a creature prone (DC 13 Strength).$$),
($$Deck of Illusions$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$34 cards. Throw one as an action to create an illusion of a creature, by the card's table, that lasts until dispelled or touched; it can move up to 30 feet and acts as you direct.$$),
($$Deck of Many Things$$, 'legendary', false, null, array['wondrous item','DMG'],
 $$Draw cards after announcing how many; each triggers a powerful effect from the deck's table, from wishes and fortunes to ruin, imprisonment or death. The DM runs it.$$),
($$Defender$$, 'legendary', true, null, array['weapon','DMG'],
 $$Any sword. +3 to attack and damage. On each of your turns, you can move some or all of the bonus to your AC instead, until your next turn.$$),
($$Demon Armor$$, 'very rare', true, null, array['armor','DMG'],
 $$Plate armour. +1 to AC, understand and speak Abyssal, and its clawed gauntlets make unarmed strikes magic +1 weapons dealing 1d8 slashing. Cursed: you can't remove it, and have disadvantage on attacks against demons and on saves against their spells.$$),
($$Dimensional Shackles$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Clapped on an incapacitated Small-to-Large creature, they stop it teleporting or travelling between planes. The wearer can try a DC 30 Strength check every 30 days to break free.$$),
($$Dragon Scale Mail$$, 'very rare', true, null, array['armor','DMG'],
 $$Made from one dragon colour. +1 AC, advantage on saves against dragons' frightful presence and breath weapons, resistance to that dragon's damage type, and once per dawn sense the nearest dragon of that kind within 30 miles.$$),
($$Dragon Slayer$$, 'rare', false, null, array['weapon','DMG'],
 $$Any sword. +1 to attack and damage, and an extra 3d6 damage of the weapon's type against dragons.$$),
($$Driftglobe$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$A small glass sphere. Cast light from it at will, or daylight once per dawn. On command it rises and floats up to 5 feet off the ground, following you within 60 feet.$$),
($$Dust of Disappearance$$, 'uncommon', false, null, array['wondrous item','consumable','DMG'],
 $$One use. Thrown into the air, it makes you and every creature and object within 10 feet invisible for 2d4 minutes, ending early for anyone who attacks or casts a spell.$$),
($$Dust of Dryness$$, 'uncommon', false, null, array['wondrous item','consumable','DMG'],
 $$1d6+4 pinches. One pinch absorbs a 15-foot cube of water into a marble-sized pellet that releases it again when smashed. Thrown at a water elemental or similar creature, it deals 10d6 necrotic (DC 13 Constitution for half).$$),
($$Dust of Sneezing and Choking$$, 'uncommon', false, null, array['wondrous item','consumable','DMG'],
 $$Looks like dust of disappearance. When thrown, every creature within 30 feet that breathes makes a DC 15 Constitution save or is incapacitated and suffocating, repeating the save each turn.$$),
($$Dwarven Plate$$, 'very rare', false, null, array['armor','DMG'],
 $$Plate armour. +2 to AC, and when an effect would move you against your will along the ground, your reaction reduces the distance by up to 10 feet.$$),
($$Dwarven Thrower$$, 'very rare', true, $$by a dwarf$$, array['weapon','DMG'],
 $$+3 warhammer with the thrown property (20/60). It flies back to your hand after a ranged attack, and deals an extra 1d8 when thrown (2d8 against giants).$$),
($$Efficient Quiver$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Three extradimensional compartments: up to 60 arrows or bolts, up to 18 javelins, and up to 6 long objects such as bows or staffs. Weighs 2 pounds whatever it holds.$$),
($$Efreeti Bottle$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Unstopper it and an efreeti appears. Roll on its table: it may attack, serve you for an hour, or grant three wishes.$$),
($$Efreeti Chain$$, 'legendary', true, null, array['armor','DMG'],
 $$Chain mail. +3 AC, immunity to fire damage, you can speak Primordial, and you can stand and walk on molten rock.$$),
($$Elemental Gem$$, 'uncommon', false, null, array['wondrous item','consumable','DMG'],
 $$Blue sapphire (air), yellow diamond (earth), red corundum (fire) or emerald (water). Break it to summon that elemental, as conjure elemental. The gem is spent.$$),
($$Elixir of Health$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$Cures any disease and ends the blinded, deafened, paralyzed and poisoned conditions.$$),
($$Elven Chain$$, 'rare', false, null, array['armor','DMG'],
 $$Chain shirt. +1 AC, and you count as proficient with it even without medium armour proficiency.$$),
($$Eversmoking Bottle$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Unstoppered, it pours out thick smoke that fills an ever-widening area of heavy obscurement, up to a 120-foot radius. Stopper it and the smoke disperses over time.$$),
($$Eyes of Charming$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Crystal lenses with 3 charges. Spend one to cast charm person (DC 13) on a humanoid within 30 feet that can see you. Regains all charges at dawn.$$),
($$Eyes of Minute Seeing$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$See fine detail within 1 foot. Advantage on Intelligence (Investigation) checks that rely on sight while searching an area or studying an object there.$$),
($$Eyes of the Eagle$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Advantage on Wisdom (Perception) checks that rely on sight, and you can make out fine detail of distant things in clear visibility.$$),
($$Figurine of Wondrous Power$$, 'varies', false, null, array['wondrous item','DMG'],
 $$A statuette that becomes a living creature when thrown and commanded, obeying you for a time before reverting. Nine kinds, from the silver raven (uncommon) to the obsidian steed (very rare); each has its own creature, duration and recharge.$$),
($$Flame Tongue$$, 'rare', true, null, array['weapon','DMG'],
 $$Any sword. As a bonus action, set the blade alight: it sheds bright light 40 feet and deals an extra 2d6 fire on a hit until you douse it.$$),
($$Folding Boat$$, 'rare', false, null, array['wondrous item','DMG'],
 $$A wooden box that unfolds on command into a 10-foot rowing boat for four, or a 24-foot ship with a sail and room for fifteen, and folds back on a third word.$$),
($$Frost Brand$$, 'very rare', true, null, array['weapon','DMG'],
 $$Any sword. Extra 1d6 cold on a hit and resistance to fire. In freezing temperatures it sheds light, and once per hour you can extinguish nearby nonmagical flames.$$);

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

insert into public.schema_migrations (version) values ('131');

commit;

-- db/133_magic_items_dmg_m_p.sql
--
-- The DMG's magic items, M-P. Fourth of eight seed files on 129's columns;
-- 130's header carries the reasoning for all eight. Only what differs:
--
-- Most of this file is potions. Potion of Healing itself is not here: it has
-- been in the catalogue since 003 at the PHB's 50 gp, and 129 marked it
-- common. Its three stronger tiers are new rows. Potion of Giant Strength is
-- one row per giant, since the tiers differ in rarity. Nolzur's Marvelous
-- Pigments uses the book's name.
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
($$Mace of Disruption$$, 'rare', true, null, array['weapon','DMG'],
 $$Against fiends and undead it deals an extra 2d6 radiant, and one left at 25 hit points or fewer makes a DC 15 Wisdom save or is destroyed. Sheds light on command.$$),
($$Mace of Smiting$$, 'rare', false, null, array['weapon','DMG'],
 $$+1 to attack and damage (+3 against constructs). A natural 20 deals an extra 2d6 bludgeoning (4d6 to a construct), and a construct left at 25 hit points or fewer is destroyed.$$),
($$Mace of Terror$$, 'rare', true, null, array['weapon','DMG'],
 $$3 charges. Spend one to make creatures within 30 feet save (DC 15 Wisdom) or be frightened of you for 1 minute, fleeing. Regains 1d3 at dawn.$$),
($$Mantle of Spell Resistance$$, 'rare', true, null, array['wondrous item','DMG'],
 $$Advantage on saving throws against spells while you wear it.$$),
($$Manual of Bodily Health$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Study it for 48 hours over 6 days and your Constitution score and maximum rise by 2. The book then loses its magic for a century.$$),
($$Manual of Gainful Exercise$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Study it for 48 hours over 6 days and your Strength score and maximum rise by 2. The book then loses its magic for a century.$$),
($$Manual of Golems$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Holds the secrets of making one kind of golem (clay, flesh, iron or stone), with the time and cost each takes. A spellcaster who reads it can build that golem; the book then burns away.$$),
($$Manual of Quickness of Action$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Study it for 48 hours over 6 days and your Dexterity score and maximum rise by 2. The book then loses its magic for a century.$$),
($$Mariner's Armor$$, 'uncommon', false, null, array['armor','DMG'],
 $$Any armour, decorated with fish and shells. A swimming speed equal to your walking speed, and if you start a turn underwater at 0 hit points, you rise 60 feet toward the surface.$$),
($$Medallion of Thoughts$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$3 charges. Spend one to cast detect thoughts (DC 13). Regains 1d3 at dawn.$$),
($$Mirror of Life Trapping$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$A wall mirror with twelve cells. A creature within 30 feet that sees its reflection makes a DC 15 Charisma save or is trapped in a cell. Breaking the mirror frees everyone.$$),
($$Mithral Armor$$, 'uncommon', false, null, array['armor','DMG'],
 $$Medium or heavy armour (not hide). No Stealth disadvantage and no Strength requirement.$$),
($$Necklace of Adaptation$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$You can breathe normally in any environment, and have advantage on saves against harmful gases and vapours.$$),
($$Necklace of Fireballs$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Holds 1d6+3 beads. Throw one up to 60 feet to cast fireball (DC 15); throw several at once to add 1d6 per extra bead.$$),
($$Necklace of Prayer Beads$$, 'rare', true, $$by a cleric, druid, or paladin$$, array['wondrous item','DMG'],
 $$1d4+2 magic beads, each casting one spell once per dawn: bless, cure wounds, lesser restoration, greater restoration, branding smite, planar ally or wind walk, as the necklace has.$$),
($$Nine Lives Stealer$$, 'very rare', true, null, array['weapon','DMG'],
 $$Any sword. +2 to attack and damage. 1d8+1 charges: on a critical hit against a creature under 100 hit points, it makes a DC 15 Constitution save or dies, spending a charge.$$),
($$Nolzur's Marvelous Pigments$$, 'very rare', false, null, array['wondrous item','consumable','DMG'],
 $$1d4 pots of paint. Whatever you paint becomes real: up to 1,000 square feet of objects or terrain per pot, worth no more than 25 gp. Painted creatures and wealth don't become real.$$),
($$Oathbow$$, 'very rare', true, null, array['weapon','DMG'],
 $$Longbow. Speak its oath to name a sworn enemy: you have advantage against it, it gets no cover benefit, and you ignore long-range disadvantage, dealing an extra 3d6 piercing. Using other weapons while the enemy lives gives disadvantage.$$),
($$Oil of Etherealness$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$Spread over a Medium or smaller creature, it grants the etherealness spell's effect for 1 hour.$$),
($$Oil of Sharpness$$, 'very rare', false, null, array['potion','consumable','DMG'],
 $$Coats one slashing or piercing weapon or up to five pieces of ammunition, making it a +3 weapon for 1 hour.$$),
($$Oil of Slipperiness$$, 'uncommon', false, null, array['potion','consumable','DMG'],
 $$Spread on a creature, it grants freedom of movement for 8 hours. Poured on the ground, it acts as the grease spell for 8 hours.$$),
($$Pearl of Power$$, 'uncommon', true, $$by a spellcaster$$, array['wondrous item','DMG'],
 $$Once per dawn, as an action, regain one expended spell slot of up to 3rd level.$$),
($$Periapt of Health$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Immunity to contracting any disease while you wear it. Diseases you already have aren't suppressed.$$),
($$Periapt of Proof against Poison$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Immunity to poison damage and the poisoned condition, and poisons have no effect on you.$$),
($$Periapt of Wound Closure$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$You stabilise at the start of your turn when dying, and hit dice you spend heal double.$$),
($$Philter of Love$$, 'uncommon', false, null, array['potion','consumable','DMG'],
 $$The drinker is charmed for 1 hour by the next creature it sees within 10 minutes of drinking.$$),
($$Pipes of Haunting$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$3 charges. Play them to make creatures within 30 feet save (DC 15 Wisdom) or be frightened of you for 1 minute. Regains 1d3 at dawn.$$),
($$Pipes of the Sewers$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Rats are friendly to you. 3 charges: spend one to summon nearby rat swarms that follow your direction while you keep playing. Regains 1d3 at dawn.$$),
($$Plate Armor of Etherealness$$, 'legendary', true, null, array['armor','DMG'],
 $$Plate armour. Once per dawn, speak its command word to gain the etherealness spell's effect for 10 minutes or until you end it.$$),
($$Portable Hole$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Unfolds into a 6-foot-wide, 10-foot-deep extradimensional hole; fold it back up with anything inside. Creatures inside run out of air. Placing it in another extradimensional space opens a rift to the Astral Plane.$$),
($$Potion of Animal Friendship$$, 'uncommon', false, null, array['potion','consumable','DMG'],
 $$For 1 hour you can cast animal friendship (DC 13) at will.$$),
($$Potion of Clairvoyance$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$You gain the effect of the clairvoyance spell.$$),
($$Potion of Climbing$$, 'common', false, null, array['potion','consumable','DMG'],
 $$For 1 hour you have a climbing speed equal to your walking speed and advantage on Strength (Athletics) checks to climb.$$),
($$Potion of Diminution$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$You gain the reduce effect of the enlarge/reduce spell for 1d4 hours, no concentration needed.$$),
($$Potion of Fire Breath$$, 'uncommon', false, null, array['potion','consumable','DMG'],
 $$For 1 hour, use a bonus action to exhale fire at a target within 30 feet: 4d6 fire (DC 13 Dexterity for half). Three exhalations.$$),
($$Potion of Flying$$, 'very rare', false, null, array['potion','consumable','DMG'],
 $$For 1 hour you have a flying speed equal to your walking speed and can hover. If you are aloft when it ends, you fall.$$),
($$Potion of Gaseous Form$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$You gain the effect of the gaseous form spell for 1 hour, no concentration needed. End it early as a bonus action.$$),
($$Potion of Hill Giant Strength$$, 'uncommon', false, null, array['potion','consumable','DMG'],
 $$Your Strength score becomes 21 for 1 hour. No effect if it is already 21 or higher.$$),
($$Potion of Frost Giant Strength$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$Your Strength score becomes 23 for 1 hour. No effect if it is already 23 or higher.$$),
($$Potion of Stone Giant Strength$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$Your Strength score becomes 23 for 1 hour. No effect if it is already 23 or higher.$$),
($$Potion of Fire Giant Strength$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$Your Strength score becomes 25 for 1 hour. No effect if it is already 25 or higher.$$),
($$Potion of Cloud Giant Strength$$, 'very rare', false, null, array['potion','consumable','DMG'],
 $$Your Strength score becomes 27 for 1 hour. No effect if it is already 27 or higher.$$),
($$Potion of Storm Giant Strength$$, 'legendary', false, null, array['potion','consumable','DMG'],
 $$Your Strength score becomes 29 for 1 hour. No effect if it is already 29 or higher.$$),
($$Potion of Growth$$, 'uncommon', false, null, array['potion','consumable','DMG'],
 $$You gain the enlarge effect of the enlarge/reduce spell for 1d4 hours, no concentration needed.$$),
($$Potion of Greater Healing$$, 'uncommon', false, null, array['potion','consumable','DMG'],
 $$Regain 4d4 + 4 hit points.$$),
($$Potion of Superior Healing$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$Regain 8d4 + 8 hit points.$$),
($$Potion of Supreme Healing$$, 'very rare', false, null, array['potion','consumable','DMG'],
 $$Regain 10d4 + 20 hit points.$$),
($$Potion of Heroism$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$For 1 hour you have 10 temporary hit points and are under the bless spell, no concentration needed.$$),
($$Potion of Invisibility$$, 'very rare', false, null, array['potion','consumable','DMG'],
 $$You become invisible for 1 hour, along with what you wear or carry. Ends early if you attack or cast a spell.$$),
($$Potion of Longevity$$, 'very rare', false, null, array['potion','consumable','DMG'],
 $$Your physical age drops by 1d6+6 years. Each later dose carries a cumulative 10% chance of aging you instead.$$),
($$Potion of Mind Reading$$, 'rare', false, null, array['potion','consumable','DMG'],
 $$You gain the effect of the detect thoughts spell (DC 13) for its duration, no concentration needed.$$),
($$Potion of Poison$$, 'uncommon', false, null, array['potion','consumable','DMG'],
 $$Looks like a beneficial potion. The drinker takes 3d6 poison and is poisoned (DC 13 Constitution), taking more damage each turn until it succeeds.$$),
($$Potion of Resistance$$, 'uncommon', false, null, array['potion','consumable','DMG'],
 $$Resistance to one damage type, fixed when brewed, for 1 hour.$$),
($$Potion of Speed$$, 'very rare', false, null, array['potion','consumable','DMG'],
 $$You gain the effect of the haste spell for 1 minute, no concentration needed.$$),
($$Potion of Vitality$$, 'very rare', false, null, array['potion','consumable','DMG'],
 $$Removes all exhaustion and cures any disease or poison. For 24 hours, hit dice you spend heal their maximum.$$),
($$Potion of Water Breathing$$, 'uncommon', false, null, array['potion','consumable','DMG'],
 $$You can breathe underwater for 1 hour.$$);

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

insert into public.schema_migrations (version) values ('133');

commit;

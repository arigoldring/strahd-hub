-- db/135_magic_items_dmg_t_z.sql
--
-- The DMG's magic items, T-Z: talismans, tomes, wands and the +1/+2/+3
-- weapon. Sixth of eight seed files on 129's columns; 130's header carries
-- the reasoning for all eight. Only what differs:
--
-- Wand of the War Mage and Weapon are one row per bonus.
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
($$Talisman of Pure Good$$, 'legendary', true, $$by a creature of good alignment$$, array['wondrous item','DMG'],
 $$A holy symbol and spellcasting focus that gives +2 to spell attacks. 7 charges: spend one to open a fissure beneath a fiend or undead, which may swallow it. Evil creatures that touch it are burned.$$),
($$Talisman of the Sphere$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$Doubles your proficiency bonus on Intelligence (Arcana) checks to control a sphere of annihilation, and lets you hover it beside you as a bonus action.$$),
($$Talisman of Ultimate Evil$$, 'legendary', true, $$by a creature of evil alignment$$, array['wondrous item','DMG'],
 $$An unholy symbol and focus that gives +2 to spell attacks. 6 charges: spend one to open a fissure beneath a good creature, which may swallow it. Good creatures that touch it are burned.$$),
($$Tome of Clear Thought$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Study it for 48 hours over 6 days and your Intelligence score and maximum rise by 2. The book then loses its magic for a century.$$),
($$Tome of Leadership and Influence$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Study it for 48 hours over 6 days and your Charisma score and maximum rise by 2. The book then loses its magic for a century.$$),
($$Tome of the Stilled Tongue$$, 'legendary', true, $$by a wizard$$, array['wondrous item','DMG'],
 $$A spellbook bound with a dried tongue. Once per dawn, cast a spell written in it without expending a slot or providing verbal or somatic components. Vecna watches whoever uses it.$$),
($$Tome of Understanding$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Study it for 48 hours over 6 days and your Wisdom score and maximum rise by 2. The book then loses its magic for a century.$$),
($$Trident of Fish Command$$, 'uncommon', true, null, array['weapon','DMG'],
 $$3 charges. Spend one to cast dominate beast (DC 15) on a beast with an innate swimming speed. Regains 1d3 at dawn.$$),
($$Universal Solvent$$, 'legendary', false, null, array['wondrous item','consumable','DMG'],
 $$One ounce of liquid that dissolves any adhesive it touches, including sovereign glue.$$),
($$Vicious Weapon$$, 'rare', false, null, array['weapon','DMG'],
 $$Any weapon. On a natural 20, the target takes an extra 7 damage of the weapon's type.$$),
($$Vorpal Sword$$, 'legendary', true, null, array['weapon','DMG'],
 $$Any slashing sword. +3 to attack and damage, ignores resistance to slashing, and on a natural 20 cuts off one of the target's heads, killing it if it can't survive the loss (otherwise an extra 6d8 slashing).$$),
($$Wand of Binding$$, 'rare', true, $$by a spellcaster$$, array['wand','DMG'],
 $$7 charges: hold monster or hold person. Once per dawn, gain advantage on a check or save to escape a grapple or restraint. Regains 1d6+1 at dawn.$$),
($$Wand of Enemy Detection$$, 'rare', true, null, array['wand','DMG'],
 $$7 charges. Spend one to sense the direction of the nearest hostile creature within 60 feet for a minute. Regains 1d6+1 at dawn.$$),
($$Wand of Fear$$, 'rare', true, null, array['wand','DMG'],
 $$7 charges: cast command (flee or grovel) or send out a 60-foot cone of fear (DC 15 Wisdom). Regains 1d6+1 at dawn.$$),
($$Wand of Fireballs$$, 'rare', true, $$by a spellcaster$$, array['wand','DMG'],
 $$7 charges. Spend one or more to cast fireball (DC 15), +1 level per extra charge. Regains 1d6+1 at dawn.$$),
($$Wand of Lightning Bolts$$, 'rare', true, $$by a spellcaster$$, array['wand','DMG'],
 $$7 charges. Spend one or more to cast lightning bolt (DC 15), +1 level per extra charge. Regains 1d6+1 at dawn.$$),
($$Wand of Magic Detection$$, 'uncommon', false, null, array['wand','DMG'],
 $$3 charges. Spend one to cast detect magic. Regains 1d3 at dawn.$$),
($$Wand of Magic Missiles$$, 'uncommon', false, null, array['wand','DMG'],
 $$7 charges. Spend one or more to cast magic missile, +1 level per extra charge. Regains 1d6+1 at dawn.$$),
($$Wand of Paralysis$$, 'rare', true, $$by a spellcaster$$, array['wand','DMG'],
 $$7 charges. Spend one to fire a ray at a creature within 60 feet: DC 15 Constitution or paralyzed for a minute, repeating the save each turn. Regains 1d6+1 at dawn.$$),
($$Wand of Polymorph$$, 'very rare', true, $$by a spellcaster$$, array['wand','DMG'],
 $$7 charges. Spend one to cast polymorph (DC 15). Regains 1d6+1 at dawn.$$),
($$Wand of Secrets$$, 'uncommon', false, null, array['wand','DMG'],
 $$3 charges. Spend one: if a secret door or trap is within 30 feet, the wand pulses and points at the nearest. Regains 1d3 at dawn.$$),
($$Wand of the War Mage, +1$$, 'uncommon', true, $$by a spellcaster$$, array['wand','DMG'],
 $$+1 to spell attack rolls, and your spell attacks ignore half cover.$$),
($$Wand of the War Mage, +2$$, 'rare', true, $$by a spellcaster$$, array['wand','DMG'],
 $$+2 to spell attack rolls, and your spell attacks ignore half cover.$$),
($$Wand of the War Mage, +3$$, 'very rare', true, $$by a spellcaster$$, array['wand','DMG'],
 $$+3 to spell attack rolls, and your spell attacks ignore half cover.$$),
($$Wand of Web$$, 'uncommon', true, $$by a spellcaster$$, array['wand','DMG'],
 $$7 charges. Spend one to cast web (DC 15). Regains 1d6+1 at dawn.$$),
($$Wand of Wonder$$, 'rare', true, $$by a spellcaster$$, array['wand','DMG'],
 $$7 charges. Spend one to target a point within 120 feet and roll on its table for a random effect, from fireballs and lightning to a rain of butterflies or a heavy downpour. Regains 1d6+1 at dawn.$$),
($$Weapon, +1$$, 'uncommon', false, null, array['weapon','DMG'],
 $$Any weapon. +1 to attack and damage rolls.$$),
($$Weapon, +2$$, 'rare', false, null, array['weapon','DMG'],
 $$Any weapon. +2 to attack and damage rolls.$$),
($$Weapon, +3$$, 'very rare', false, null, array['weapon','DMG'],
 $$Any weapon. +3 to attack and damage rolls.$$),
($$Weapon of Warning$$, 'uncommon', true, null, array['weapon','DMG'],
 $$Any weapon. You and allies within 30 feet can't be surprised and have advantage on initiative, and it wakes you and your companions when combat starts.$$),
($$Well of Many Worlds$$, 'legendary', false, null, array['wondrous item','DMG'],
 $$A black cloth that unfolds into a circular portal to another world or plane, chosen at random. Once per 1d8 hours.$$),
($$Wind Fan$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Cast gust of wind (DC 13) from it. Each further use before dawn has a cumulative 20% chance to tear it.$$),
($$Winged Boots$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$A flying speed equal to your walking speed, for up to 4 hours total, recovering 2 hours for every 12 hours of disuse.$$),
($$Wings of Flying$$, 'rare', true, null, array['wondrous item','DMG'],
 $$A cloak that becomes bat or bird wings on command, giving a flying speed of 60 feet for 1 hour. Then unusable for 1d12 hours.$$);

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

insert into public.schema_migrations (version) values ('135');

commit;

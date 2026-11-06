-- db/130_magic_items_dmg_a_b.sql
--
-- Seeds the shared catalogue with the DMG's magic items, A-B. The first of
-- eight seed files on 129's columns:
--
--   130 DMG A-B   131 DMG C-F   132 DMG G-L   133 DMG M-P
--   134 DMG Q-S   135 DMG T-Z   136 XGtE      137 TCoE
--
-- Split by letter only so each file stays reviewable; nothing depends on the
-- split. Alphabetised on the book's own names (Daern's Instant Fortress sits
-- under D, not I).
--
-- WHAT IS IN: every magic item in the 2014 DMG's chapter 7 except the
-- artifacts (decided 2026-11-05: they are plot objects, not stock). The PHB
-- contributes only Potion of Healing, which 129 marked in place.
--
-- ONE ROW PER RARITY. An item the book tiers (+1/+2/+3 Weapon, each Belt of
-- Giant Strength) is one row per tier, so its rarity is a fact the filter can
-- use. An item whose variants share a rarity (Bag of Tricks' three colours)
-- is one row that names them. 'varies' is kept for Spell Scroll and the
-- Figurine of Wondrous Power, whose rarity depends on what it holds.
--
-- EVERY ROW IS kind = 'general', weapons and armour included. Most of the
-- book's magic weapons are "any sword" or "any weapon", so they have no fixed
-- damage dice to put in the weapon columns; the bonus lives in the text and
-- the sheet does not apply it (KNOWN_ISSUES). price_cp = 0: the books give
-- rarity ranges, not prices, and the client shows the rarity instead.
--
-- DESCRIPTIONS ARE SHORT SUMMARIES IN OUR OWN WORDS, never the book's text
-- (CLAUDE.md, the class feature rule). Charges, DCs and bonuses are kept;
-- tables are referenced, not reproduced.
--
-- SHAPE. The rows are written once, into a temp table, and every statement
-- reads from there (CLAUDE.md: a literal that must agree across statements
-- appears once). `items` has no unique name, so the insert is guarded with
-- `not exists` on a shared row of the same name. The assertion is on the end
-- state: every seeded name is present, shared, with the rarity written here.
-- A mundane row that already had one of these names would have a null rarity
-- and fail the assertion loudly instead of being skipped silently.
--
-- RUN AS ONE BLOCK. CORRECT OUTPUT: "Success. No rows returned." If the
-- Supabase editor offers to enable RLS, decline (CLAUDE.md).

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
($$Adamantine Armor$$, 'uncommon', false, null, array['armor','DMG'],
 $$Medium or heavy armour (not hide) reinforced with adamantine. While you wear it, any critical hit against you becomes a normal hit.$$),
($$Alchemy Jug$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$A ceramic jug. As an action, name a liquid from its table (water, beer, wine, vinegar, honey, mayonnaise, oil, acid, poison and more) and the jug fills with up to its daily limit of that liquid. Resets at dawn.$$),
($$Ammunition, +1$$, 'uncommon', false, null, array['weapon','consumable','DMG'],
 $$+1 to attack and damage rolls with this piece of ammunition. Once it hits, it is no longer magical.$$),
($$Ammunition, +2$$, 'rare', false, null, array['weapon','consumable','DMG'],
 $$+2 to attack and damage rolls with this piece of ammunition. Once it hits, it is no longer magical.$$),
($$Ammunition, +3$$, 'very rare', false, null, array['weapon','consumable','DMG'],
 $$+3 to attack and damage rolls with this piece of ammunition. Once it hits, it is no longer magical.$$),
($$Amulet of Health$$, 'rare', true, null, array['wondrous item','DMG'],
 $$Your Constitution score becomes 19 while you wear it. No effect if your Constitution is already 19 or higher.$$),
($$Amulet of Proof against Detection and Location$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$While worn, you are hidden from divination magic: you can't be targeted by it or perceived through magical scrying sensors.$$),
($$Amulet of the Planes$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$As an action, name a familiar plane and make a DC 15 Intelligence check. On a success you cast plane shift to it; on a failure you and up to eight creatures within 15 feet are hurled to a random destination.$$),
($$Animated Shield$$, 'very rare', true, null, array['armor','DMG'],
 $$As a bonus action, speak its command word and the shield floats in your space for 1 minute, protecting you as if you held it and leaving your hands free.$$),
($$Apparatus of Kwalish$$, 'legendary', false, null, array['wondrous item','DMG'],
 $$A sealed iron barrel that, once its hidden hatch is found, becomes a Large lobster-shaped submersible crewed by up to two Medium creatures, with ten levers that work its claws, legs, lights and hatches.$$),
($$Armor, +1$$, 'rare', false, null, array['armor','DMG'],
 $$Any armour. +1 bonus to AC while worn.$$),
($$Armor, +2$$, 'very rare', false, null, array['armor','DMG'],
 $$Any armour. +2 bonus to AC while worn.$$),
($$Armor, +3$$, 'legendary', false, null, array['armor','DMG'],
 $$Any armour. +3 bonus to AC while worn.$$),
($$Armor of Invulnerability$$, 'legendary', true, null, array['armor','DMG'],
 $$Plate armour. You have resistance to nonmagical damage while wearing it. Once per dawn, as an action, you become immune to nonmagical damage for 10 minutes or until you take it off.$$),
($$Armor of Resistance$$, 'rare', true, null, array['armor','DMG'],
 $$Any light, medium or heavy armour. You have resistance to one damage type, fixed when the armour is made (the DM picks or rolls).$$),
($$Armor of Vulnerability$$, 'rare', true, null, array['armor','DMG'],
 $$Plate armour that grants resistance to one of bludgeoning, piercing or slashing. Cursed: you are vulnerable to the other two, and can't remove it while attuned without remove curse.$$),
($$Arrow-Catching Shield$$, 'rare', true, null, array['armor','DMG'],
 $$+2 AC against ranged attacks, on top of the shield's normal bonus. When an ally within 5 feet is targeted by a ranged attack, your reaction makes you the target instead.$$),
($$Arrow of Slaying$$, 'very rare', false, null, array['weapon','consumable','DMG'],
 $$Keyed to one type of creature. A creature of that type it hits makes a DC 17 Constitution save, taking an extra 6d10 piercing on a failure or half on a success. Then it becomes nonmagical.$$),
($$Bag of Beans$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Holds 3d4 beans. Dumped out, they explode for 5d4 fire (DC 15 Dexterity for half). A bean planted and watered produces a random, often bizarre effect a minute later; see the item's table.$$),
($$Bag of Devouring$$, 'very rare', false, null, array['wondrous item','DMG'],
 $$Looks like a bag of holding but is the mouth of an extradimensional creature. It may swallow what is put in it, and can pull in a creature that reaches inside (DC 15 Strength to escape).$$),
($$Bag of Holding$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Holds up to 500 pounds or 64 cubic feet but always weighs 15 pounds. Retrieving an item takes an action. Placing it inside another extradimensional space opens a rift to the Astral Plane.$$),
($$Bag of Tricks$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Gray, rust or tan. As an action, pull out a fuzzy ball and throw it up to 20 feet; it becomes a random beast (by the bag's table) that obeys you and vanishes at dawn. Three uses, recharging at dawn.$$),
($$Bead of Force$$, 'rare', false, null, array['wondrous item','consumable','DMG'],
 $$Thrown up to 60 feet, it bursts for 5d4 force (DC 15 Dexterity for half) and traps creatures in a 10-foot sphere of force for 1 minute.$$),
($$Belt of Dwarvenkind$$, 'rare', true, null, array['wondrous item','DMG'],
 $$+2 Constitution (max 20), advantage on Charisma (Persuasion) with dwarves, advantage on saves against poison and resistance to poison damage, darkvision 60 feet, and you can speak Dwarvish.$$),
($$Belt of Hill Giant Strength$$, 'rare', true, null, array['wondrous item','DMG'],
 $$Your Strength score becomes 21 while you wear it. No effect if it is already 21 or higher.$$),
($$Belt of Stone Giant Strength$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Your Strength score becomes 23 while you wear it. No effect if it is already 23 or higher.$$),
($$Belt of Frost Giant Strength$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Your Strength score becomes 23 while you wear it. No effect if it is already 23 or higher.$$),
($$Belt of Fire Giant Strength$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$Your Strength score becomes 25 while you wear it. No effect if it is already 25 or higher.$$),
($$Belt of Cloud Giant Strength$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$Your Strength score becomes 27 while you wear it. No effect if it is already 27 or higher.$$),
($$Belt of Storm Giant Strength$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$Your Strength score becomes 29 while you wear it. No effect if it is already 29 or higher.$$),
($$Berserker Axe$$, 'rare', true, null, array['weapon','DMG'],
 $$Any axe. +1 to attack and damage, and +1 hit point per level while attuned. Cursed: you can't part with it, have disadvantage with other weapons, and must make a DC 15 Wisdom save when damaged or go berserk.$$),
($$Boots of Elvenkind$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Your steps make no sound, and you have advantage on Dexterity (Stealth) checks that rely on moving silently.$$),
($$Boots of Levitation$$, 'rare', true, null, array['wondrous item','DMG'],
 $$While worn, you can cast levitate on yourself at will.$$),
($$Boots of Speed$$, 'rare', true, null, array['wondrous item','DMG'],
 $$As a bonus action, click the heels: your walking speed doubles and opportunity attacks against you have disadvantage. Up to 10 minutes total per long rest.$$),
($$Boots of Striding and Springing$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Your walking speed becomes 30 feet unless higher, isn't reduced by encumbrance or armour, and you can jump three times the normal distance.$$),
($$Boots of the Winterlands$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Resistance to cold damage, no penalty for difficult terrain from ice or snow, and you can tolerate temperatures as low as -50 F without extra protection.$$),
($$Bowl of Commanding Water Elementals$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Filled with water and commanded as an action, it summons a water elemental, as conjure elemental. Once per dawn.$$),
($$Bracers of Archery$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Proficiency with the longbow and shortbow, and +2 to damage rolls on ranged attacks with them.$$),
($$Bracers of Defense$$, 'rare', true, null, array['wondrous item','DMG'],
 $$+2 bonus to AC while you wear no armour and use no shield.$$),
($$Brazier of Commanding Fire Elementals$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Lit and commanded as an action, it summons a fire elemental, as conjure elemental. Once per dawn.$$),
($$Brooch of Shielding$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$Resistance to force damage and immunity to the magic missile spell.$$),
($$Broom of Flying$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Speak its command word and it hovers; it can be ridden at a flying speed of 50 feet (30 feet if carrying over 200 pounds). It can also fly alone to a spot within a mile.$$);

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

insert into public.schema_migrations (version) values ('130');

commit;

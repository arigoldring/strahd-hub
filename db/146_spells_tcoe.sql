-- db/146_spells_tcoe.sql
--
-- Seeds the shared catalogue with the 21 spells in Tasha's Cauldron of
-- Everything's spell chapter (138's header has the map of 138-147). The book
-- tag in `tags` is 'TCoE'. That chapter reprints Booming Blade, Green-Flame
-- Blade, Lightning Lure and Sword Burst from the Sword Coast guide, so they
-- arrive here, with TCoE's class lists.
--
-- Same rules and shape as 139, whose header explains them. Each row carries
-- its own entry's class list; the book's separate "expanded spell lists"
-- for existing spells are 147's. No Artificer, although most of these name
-- it (KNOWN_ISSUES).
--
-- The summon spells' stat blocks are summarised, not reproduced: each row
-- names its options and the numbers that scale with the slot. The book's
-- stat block is the reference at the table.
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
($$Booming Blade$$, 0, 'evocation', '1 action', 'Self (5-foot radius)', 'SM', $$a melee weapon worth at least 1 sp$$, '1 round', false,
 array['Sorcerer','Warlock','Wizard'], 'damage',
 $$Make a melee attack with a weapon against one creature within reach. On a hit it suffers the attack's normal effects and is sheathed in booming energy until the start of your next turn: if it willingly moves 5 feet or more before then, it takes 1d8 thunder damage and the spell ends. At 5th level the hit also deals an extra 1d8 thunder and the moving damage becomes 2d8; both rise by 1d8 at 11th and 17th.$$, null),
($$Green-Flame Blade$$, 0, 'evocation', '1 action', 'Self (5-foot radius)', 'SM', $$a melee weapon worth at least 1 sp$$, 'Instantaneous', false,
 array['Sorcerer','Warlock','Wizard'], 'damage',
 $$Make a melee attack with a weapon against one creature within reach. On a hit it suffers the attack's normal effects, and green fire leaps to a different creature you can see within 5 feet of it, dealing fire damage equal to your spellcasting ability modifier. At 5th level the hit deals an extra 1d8 fire and the leap 1d8 + your modifier; both rise by 1d8 at 11th and 17th.$$, null),
($$Lightning Lure$$, 0, 'evocation', '1 action', 'Self (15-foot radius)', 'V', null, 'Instantaneous', false,
 array['Sorcerer','Warlock','Wizard'], 'control',
 $$A lash of lightning strikes a creature within 15 feet. It makes a Strength save or is pulled up to 10 feet toward you in a straight line, then takes 1d8 lightning damage if it is within 5 feet of you. Damage rises to 2d8 at 5th level, 3d8 at 11th and 4d8 at 17th.$$, null),
($$Mind Sliver$$, 0, 'enchantment', '1 action', '60 feet', 'V', null, '1 round', false,
 array['Sorcerer','Warlock','Wizard'], 'damage',
 $$Drive a spike of psychic energy into a creature you can see. It makes an Intelligence save or takes 1d6 psychic damage and subtracts 1d4 from the next saving throw it makes before the end of your next turn. Damage rises to 2d6 at 5th level, 3d6 at 11th and 4d6 at 17th.$$, null),
($$Sword Burst$$, 0, 'conjuration', '1 action', 'Self (5-foot radius)', 'V', null, 'Instantaneous', false,
 array['Sorcerer','Warlock','Wizard'], 'damage',
 $$Spectral blades sweep around you. Each other creature within 5 feet of you makes a Dexterity save or takes 1d6 force damage. Damage rises to 2d6 at 5th level, 3d6 at 11th and 4d6 at 17th.$$, null),

-- 1st and 2nd level --------------------------------------------------------
($$Tasha's Caustic Brew$$, 1, 'evocation', '1 action', 'Self (30-foot line)', 'VSM', $$a bit of rotten food$$, 'Concentration, up to 1 minute', false,
 array['Sorcerer','Wizard'], 'damage',
 $$A stream of acid shoots out in a 30-foot-long, 5-foot-wide line. Each creature in it makes a Dexterity save or is covered in acid, taking 2d4 acid damage at the start of each of its turns until the spell ends. A creature can use its action to scrape the acid off itself or one creature within 5 feet.$$,
 $$+2d4 damage for each slot level above 1st.$$),
($$Tasha's Mind Whip$$, 2, 'enchantment', '1 action', '90 feet', 'V', null, '1 round', false,
 array['Sorcerer','Wizard'], 'control',
 $$Psychically lash a creature you can see. It makes an Intelligence save. On a failure it takes 3d6 psychic damage, can't take a reaction until the end of its next turn, and on that turn can do only one of: move, take an action, or take a bonus action. On a success it takes half damage and nothing else.$$,
 $$One additional creature for each slot level above 2nd; the targets must be within 30 feet of each other.$$),
($$Summon Beast$$, 2, 'conjuration', '1 action', '90 feet', 'VSM', $$a feather, tuft of fur, and fish tail inside a gilded acorn worth at least 200 gp$$, 'Concentration, up to 1 hour', false,
 array['Druid','Ranger'], 'summoning',
 $$Call a bestial spirit in an Air, Land or Water form (flying, climbing or swimming). It is friendly to you, shares your initiative and acts right after you, obeying your verbal commands. Its AC is 11 + the spell's level; it has 20 (Air) or 30 hit points + 5 per level above 2nd, and makes a number of Maul attacks equal to half the spell's level (1d8 + 4 + the spell's level piercing).$$,
 $$Use the slot's level wherever the spell's level appears in the stat block.$$),

-- 3rd level ----------------------------------------------------------------
($$Intellect Fortress$$, 3, 'abjuration', '1 action', '30 feet', 'V', null, 'Concentration, up to 1 hour', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'defense',
 $$A willing creature you can see gains resistance to psychic damage and advantage on Intelligence, Wisdom and Charisma saving throws.$$,
 $$One additional creature for each slot level above 3rd; the targets must be within 30 feet of each other.$$),
($$Spirit Shroud$$, 3, 'necromancy', '1 bonus action', 'Self', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Cleric','Paladin','Warlock','Wizard'], 'damage',
 $$Spirits flit around you to 10 feet. Your attacks that hit a creature within 10 feet deal an extra 1d8 radiant, necrotic or cold damage (chosen when you cast), and that creature can't regain hit points until the start of your next turn. As a bonus action you can reduce the speed of a creature you can see within 10 feet by 10 feet until your next turn.$$,
 $$+1d8 damage for every two slot levels above 3rd.$$),
($$Summon Fey$$, 3, 'conjuration', '1 action', '90 feet', 'VSM', $$a gilded flower worth at least 300 gp$$, 'Concentration, up to 1 hour', false,
 array['Druid','Ranger','Warlock','Wizard'], 'summoning',
 $$Call a fey spirit in a Fuming, Mirthful or Tricksy mood. It is friendly, shares your initiative, acts after you and obeys your commands. AC 12 + the spell's level; 30 hit points + 10 per level above 3rd; it makes half the spell's level in Shortsword attacks (2d6 + 3 + the spell's level piercing, plus 1d6 force), and can teleport 30 feet as a bonus action with a rider set by its mood.$$,
 $$Use the slot's level wherever the spell's level appears in the stat block.$$),
($$Summon Shadowspawn$$, 3, 'conjuration', '1 action', '90 feet', 'VSM', $$tears inside a gem worth at least 300 gp$$, 'Concentration, up to 1 hour', false,
 array['Warlock','Wizard'], 'summoning',
 $$Call a shadowy spirit of Fury, Despair or Fear. It is friendly, shares your initiative, acts after you and obeys your commands. AC 11 + the spell's level; 35 hit points + 15 per level above 3rd; it makes half the spell's level in Chilling Rend attacks (1d12 + 3 + the spell's level cold), and can let out a Dreadful Scream that frightens creatures nearby (Wisdom save).$$,
 $$Use the slot's level wherever the spell's level appears in the stat block.$$),
($$Summon Undead$$, 3, 'necromancy', '1 action', '90 feet', 'VSM', $$a gilded skull worth at least 300 gp$$, 'Concentration, up to 1 hour', false,
 array['Warlock','Wizard'], 'summoning',
 $$Call an undead spirit in a Ghostly, Putrid or Skeletal form. It is friendly, shares your initiative, acts after you and obeys your commands. AC 11 + the spell's level; 30 hit points + 10 per level above 3rd (Ghostly and Putrid) or 20 + 10 (Skeletal). Ghostly flies through objects and frightens with its touch, Putrid poisons and paralyzes with a festering aura, and Skeletal fires grave bolts at range.$$,
 $$Use the slot's level wherever the spell's level appears in the stat block.$$),

-- 4th level ----------------------------------------------------------------
($$Summon Aberration$$, 4, 'conjuration', '1 action', '90 feet', 'VSM', $$a pickled tentacle and an eyeball in a platinum-inlaid vial worth at least 400 gp$$, 'Concentration, up to 1 hour', false,
 array['Warlock','Wizard'], 'summoning',
 $$Call an aberrant spirit in a Beholderkin, Slaad or Star Spawn form. It is friendly, shares your initiative, acts after you and obeys your commands. AC 11 + the spell's level; 40 hit points + 10 per level above 4th; it makes half the spell's level in attacks (an eye ray, claws, or a psychic slam), with a rider for its form: Slaad regenerates, Star Spawn whispers psychic damage to nearby foes.$$,
 $$Use the slot's level wherever the spell's level appears in the stat block.$$),
($$Summon Construct$$, 4, 'conjuration', '1 action', '90 feet', 'VSM', $$an ornate stone and metal lockbox worth at least 400 gp$$, 'Concentration, up to 1 hour', false,
 array['Wizard'], 'summoning',
 $$Call a construct spirit of Clay, Metal or Stone. It is friendly, shares your initiative, acts after you and obeys your commands. AC 13 + the spell's level; 40 hit points + 15 per level above 4th; it makes half the spell's level in Slam attacks (1d8 + 4 + the spell's level bludgeoning), and reacts when hit: Clay hastens, Metal burns its attacker, Stone slows foes around it.$$,
 $$Use the slot's level wherever the spell's level appears in the stat block.$$),
($$Summon Elemental$$, 4, 'conjuration', '1 action', '90 feet', 'VSM', $$air, a pebble, ash, and water inside a gold-inlaid vial worth at least 400 gp$$, 'Concentration, up to 1 hour', false,
 array['Druid','Ranger','Wizard'], 'summoning',
 $$Call an elemental spirit of Air, Earth, Fire or Water. It is friendly, shares your initiative, acts after you and obeys your commands. AC 11 + the spell's level; 50 hit points + 10 per level above 4th; it makes half the spell's level in Slam attacks (1d10 + 4 + the spell's level, of its element's damage type), and has its element's movement and resistances.$$,
 $$Use the slot's level wherever the spell's level appears in the stat block.$$),

-- 5th to 9th level ---------------------------------------------------------
($$Summon Celestial$$, 5, 'conjuration', '1 action', '90 feet', 'VSM', $$a golden reliquary worth at least 500 gp$$, 'Concentration, up to 1 hour', false,
 array['Cleric','Paladin'], 'summoning',
 $$Call a celestial spirit as an Avenger (radiant bow) or a Defender (radiant mace, AC +2). It is friendly, shares your initiative, acts after you and obeys your commands. AC 11 + the spell's level; 40 hit points + 10 per level above 5th; it makes half the spell's level in attacks, and once per day can heal a creature for 2d8 + the spell's level.$$,
 $$Use the slot's level wherever the spell's level appears in the stat block.$$),
($$Summon Fiend$$, 6, 'conjuration', '1 action', '90 feet', 'VSM', $$humanoid blood inside a ruby vial worth at least 600 gp$$, 'Concentration, up to 1 hour', false,
 array['Warlock','Wizard'], 'summoning',
 $$Call a fiendish spirit as a Demon, Devil or Yugoloth. It is friendly, shares your initiative, acts after you and obeys your commands. AC 12 + the spell's level; 50 hit points (Demon), 40 (Devil) or 60 (Yugoloth) + 15 per level above 6th; it makes half the spell's level in attacks. The Demon explodes when it dies, the Devil throws hellfire, the Yugoloth teleports after attacking.$$,
 $$Use the slot's level wherever the spell's level appears in the stat block.$$),
($$Tasha's Otherworldly Guise$$, 6, 'transmutation', '1 bonus action', 'Self', 'VSM', $$an object engraved with a symbol of the Outer Planes, worth at least 500 gp$$, 'Concentration, up to 1 minute', false,
 array['Sorcerer','Warlock','Wizard'], 'buff',
 $$Take on the guise of the Lower Planes (immune to fire and poison damage and the poisoned condition) or the Upper Planes (immune to radiant and necrotic damage and the charmed condition). Either way you gain a 40-foot flying speed and +2 AC, your weapon attacks are magical and can use your spellcasting ability, and you can attack twice when you take the Attack action.$$, null),
($$Dream of the Blue Veil$$, 7, 'conjuration', '10 minutes', '20 feet', 'VSM', $$a magic item or a willing creature from the destination world$$, '6 hours', false,
 array['Bard','Sorcerer','Warlock','Wizard'], 'movement',
 $$You and up to eight willing creatures fall unconscious and dream of another world on the Material Plane, using the component as the link. If the spell lasts the full 6 hours you all arrive physically in that world, within 1 mile of where the component came from. Waking early ends it with no travel.$$, null),
($$Blade of Disaster$$, 9, 'conjuration', '1 bonus action', '60 feet', 'VS', null, 'Concentration, up to 1 minute', false,
 array['Sorcerer','Warlock','Wizard'], 'damage',
 $$A blade-shaped planar rift appears. When you cast it, make up to two melee spell attacks with it against creatures within 5 feet of it: each hit deals 4d12 force damage, and it scores a critical hit on 18-20, dealing 12d12 force instead. As a bonus action on later turns, move it up to 30 feet and make up to two attacks again. It passes through barriers, even a wall of force.$$, null);

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
         s.category, s.school, 'TCoE']
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

insert into public.schema_migrations (version) values ('146');

commit;

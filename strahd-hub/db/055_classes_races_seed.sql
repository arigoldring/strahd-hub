-- db/055_classes_races_seed.sql
--
-- The shared class and race catalogues: the twelve classes and nine races of
-- the 2014 Player's Handbook, the edition 040's feats come from. Values are
-- copied from src/data/rules.ts's CLASSES and RACES, which the sheet used
-- while it was a localStorage mock and which are deleted once the client
-- reads these rows instead.
--
-- campaign_id is omitted on every row so it defaults to null: the shared
-- catalogue. 054's INSERT policy forbids a client from writing one; this file
-- can because a migration runs as the table owner, outside RLS.
--
-- Subclasses are deliberately not seeded yet. The table exists (054) so that
-- 056's character_classes can reference it from day one; content arrives with
-- class features, which is the work that actually needs it.
--
-- weapon_training 'martial' means simple + martial. It's an approximation the
-- sheet lets a player override per weapon: Rogues get rapiers, Monks
-- shortswords, Wizards only a short list.
--
-- subclass_level is when the PHB has the subclass chosen: 1st for Cleric,
-- Sorcerer and Warlock, 2nd for Druid and Wizard, 3rd for everyone else.
--
-- Racial ability score increases are not a column: the sheet takes ability
-- scores as final, typed values. Subraces (Hill Dwarf, Wood Elf) are not rows;
-- Wood Elf's 35 ft is the sheet's speed override.
--
-- RUN THE MIGRATION BLOCK BELOW ON ITS OWN. Per 036 the ledger insert is
-- unguarded, so a second run fails on the primary key and rolls back.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

insert into public.classes
  (name, hit_die, save_proficiencies, spell_ability, weapon_training,
   unarmored_ability, subclass_level, description)
values
  ($$Barbarian$$, 12, array['str', 'con'], null,  'martial', 'con', 3,
   $$A fierce warrior who channels primal rage, shrugging off blows that would fell anyone else.$$),
  ($$Bard$$,       8, array['dex', 'cha'], 'cha', 'simple',  null,  3,
   $$A performer whose words and music carry real magic, equally at home inspiring allies and unravelling foes.$$),
  ($$Cleric$$,     8, array['wis', 'cha'], 'wis', 'simple',  null,  1,
   $$A priestly champion who wields divine magic in service of a higher power.$$),
  ($$Druid$$,      8, array['int', 'wis'], 'wis', 'simple',  null,  2,
   $$A priest of the Old Faith, drawing on the power of nature and able to take the shapes of beasts.$$),
  ($$Fighter$$,   10, array['str', 'con'], null,  'martial', null,  3,
   $$A master of martial combat, skilled with a wide range of weapons and armour.$$),
  ($$Monk$$,       8, array['str', 'dex'], null,  'simple',  'wis', 3,
   $$A disciplined warrior who turns the body into a weapon through mastery of ki.$$),
  ($$Paladin$$,   10, array['wis', 'cha'], 'cha', 'martial', null,  3,
   $$A holy warrior bound to a sacred oath, smiting evil with steel and divine power.$$),
  ($$Ranger$$,    10, array['str', 'dex'], 'wis', 'martial', null,  3,
   $$A hunter and tracker of the wild places, using martial skill and nature magic against the threats beyond civilisation.$$),
  ($$Rogue$$,      8, array['dex', 'int'], null,  'simple',  null,  3,
   $$A scoundrel who relies on stealth, precision and a well-placed strike.$$),
  ($$Sorcerer$$,   6, array['con', 'cha'], 'cha', 'simple',  null,  1,
   $$A spellcaster whose magic is an inborn gift, shaped by bloodline or strange circumstance.$$),
  ($$Warlock$$,    8, array['wis', 'cha'], 'cha', 'simple',  null,  1,
   $$A wielder of magic granted by a pact with an otherworldly patron.$$),
  ($$Wizard$$,     6, array['int', 'wis'], 'int', 'simple',  null,  2,
   $$A scholarly magic-user who masters spells through study and a carefully kept spellbook.$$);

insert into public.races (name, speed, size, description) values
  ($$Dragonborn$$, 30, 'medium',
   $$Proud dragon-blooded humanoids with a breath weapon and resistance to its damage type.$$),
  ($$Dwarf$$,      25, 'medium',
   $$Stout, hardy folk of mountain halls; their speed isn't reduced by heavy armour.$$),
  ($$Elf$$,        30, 'medium',
   $$Graceful, long-lived people with keen senses and a fey resistance to charm.$$),
  ($$Gnome$$,      25, 'small',
   $$Small, curious and inventive, with a natural cunning against magic.$$),
  ($$Half-Elf$$,   30, 'medium',
   $$Walking in two worlds, half-elves combine human drive with elven grace.$$),
  ($$Half-Orc$$,   30, 'medium',
   $$Strong and relentless, able to stay standing when a blow should have dropped them.$$),
  ($$Halfling$$,   25, 'small',
   $$Small, nimble and uncommonly lucky folk who prefer the comforts of home.$$),
  ($$Human$$,      30, 'medium',
   $$The most widespread and varied of peoples, ambitious and adaptable.$$),
  ($$Tiefling$$,   30, 'medium',
   $$Bearing an infernal bloodline, tieflings carry innate magic and resistance to fire.$$);

insert into public.schema_migrations (version) values ('055');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: counts and a spot check
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

select
  (select count(*) = 12 from public.classes where campaign_id is null)  as twelve_classes,
  (select count(*) = 9  from public.races   where campaign_id is null)  as nine_races,
  (select count(*) = 8  from public.classes
    where campaign_id is null and spell_ability is not null)            as eight_casters,
  (select hit_die = 12 and save_proficiencies = array['str', 'con']
     from public.classes where name = 'Barbarian' and campaign_id is null) as barbarian_ok,
  (select speed = 25 and size = 'small'
     from public.races where name = 'Halfling' and campaign_id is null) as halfling_ok,
  (select count(*) = 1 from public.schema_migrations where version = '055') as ledger_row;

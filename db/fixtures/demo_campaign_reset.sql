-- db/fixtures/demo_campaign_reset.sql
--
-- Resets the public demo campaign to a known state: six authored seats with
-- gear, spells, feats, purses and player-written descriptions, plus three
-- recaps with bodies. Run it whenever the demo needs to go back to how it
-- looked before strangers touched it.
--
-- Since 2026-11-15 each seat is also a full character sheet (056 onwards):
-- ability scores, HP, race and subrace, a class and subclass at a set level,
-- proficiencies, worn gear (057), feature picks (095/122: fighting styles,
-- maneuvers, infusions), a steel defender (167), and a couple of spent use
-- counters (153). The campaign gets a live encounter (171), a fixed reveal
-- state for locations, NPCs, maps and fortunes, any NPCs its seed predates
-- (058-064), and the party hoard and purse. The seats were chosen so each one
-- shows a different part of the sheet:
--
--   Anika Stroh      Artificer 5, Battle Smith  Pallid Elf   the demo seat: steel defender, infusions
--   Aldric Thorne    Fighter 5, Battle Master   Human        fighting style, maneuvers, no spells
--   Brother Ilyan    Cleric 5, Twilight Domain  Reborn       full caster, spent slots
--   Vasha Ridewind   Ranger 9, Gloom Stalker    Wood Elf     half caster, fighting style
--   Nym Quickfinger  Rogue 5, Arcane Trickster  Lightfoot    third caster, expertise, magic weapon
--   Ysolde Karth     Wizard 9, Evocation        Eladrin      deep caster, 5th-level slots
--
-- Ability scores are entered with racial increases already applied, because
-- the sheet leaves ASIs to the player (character-sheet.md). HP maxima are
-- average-per-level plus CON, entered the same way.
--
-- NOT a migration, and deliberately not numbered into db/*.sql. This writes no
-- schema and takes no schema_migrations row, for the reason 036 built that
-- ledger: it answers "which migrations have been applied", and a fixture in the
-- sequence would put a lie in the answer. Same argument, same directory, as
-- test_campaign_seed.sql.
--
-- ---------------------------------------------------------------------------
-- why this is a separate file from test_campaign_seed.sql
-- ---------------------------------------------------------------------------
--
-- That file and test_campaign_teardown.sql are a matched pair: the seed keys on
-- `name = 'Test Roster'` in nine places and the teardown guards on that same
-- name plus '%@fake.invalid'. Re-pointing the seed at this campaign would have
-- left the teardown aimed at a campaign the seed no longer touches -- a worse
-- failure than a duplicated file, because the guard would still pass while
-- protecting nothing. That pair is left alone. This file is its own thing, and
-- has no teardown: the demo campaign is meant to outlive every reset.
--
-- ---------------------------------------------------------------------------
-- why it keys on an id and not a name
-- ---------------------------------------------------------------------------
--
-- test_campaign_seed.sql selects its campaign by name, and needs two assertions
-- to make that safe: one for zero matches, one for duplicates, because nothing
-- stops a DM creating two campaigns with the same name.
--
-- A public demo cannot afford that shape at all. `campaigns` has an UPDATE
-- policy (018, is_campaign_dm), so the name is editable from the app -- and the
-- day someone renames this campaign, a name-keyed reset stops finding it and
-- starts raising instead of resetting, at exactly the moment it is needed. The
-- id cannot be edited: it is the primary key, and 020 is the only path that
-- removes it. So the id is the key, it appears exactly once below, and every
-- statement reads it from there.
--
-- ---------------------------------------------------------------------------
-- why delete-then-insert, and not `on conflict do nothing`
-- ---------------------------------------------------------------------------
--
-- test_campaign_seed.sql ends every insert in `on conflict do nothing`, which
-- makes a re-run a no-op. That is right for a fixture you look at yourself and
-- wrong for the recovery path of a link posted in public, because "no-op" and
-- "reset" are different operations and only one of them is a safety net:
--
--   deleted a character   do-nothing restores it        (looks like it works)
--   renamed a character   do-nothing keeps the new name (silently does not)
--   added junk gear       do-nothing keeps the junk     (silently does not)
--   rewrote a recap body  do-nothing keeps the rewrite  (silently does not)
--
-- Three of those four are the ones a stranger actually does, and all three fail
-- quietly -- the file reports success and the demo stays vandalised. So the
-- character rows and the recaps are deleted first and written fresh.
--
-- ---------------------------------------------------------------------------
-- what the delete reaches, and what it deliberately does not
-- ---------------------------------------------------------------------------
--
-- One statement removes every character in this campaign, and the schema takes
-- the rest with it. Every FK below is ON DELETE CASCADE, confirmed against the
-- live database rather than assumed:
--
--   characters
--     -> character_inventory            (028/029)
--     -> character_spells               (037)
--     -> character_feats                (041)
--     -> character_item_descriptions    (047)
--     -> character_spell_descriptions   (046)
--     -> character_stats                (056, recreated by its insert trigger)
--     -> character_classes              (056)
--          -> character_feature_choices (095)
--     -> character_proficiencies        (056)
--     -> character_resource_uses        (153)
--     -> character_companions           (167)
--     -> encounter_combatants           (171)
--
-- The encounter row itself does not hang off a character, and `encounters`
-- allows one per campaign, so it is deleted on its own. The party hoard and
-- purse are deleted on their own too.
--
-- Scoped to `campaign_id = <the demo campaign>` and nothing wider. The other
-- campaigns in this database, and the shared item/spell/feat catalogues (all
-- `campaign_id is null`), are untouched and unreferenced.
--
-- NOT deleted, each for its own reason:
--
--   campaign_members   The roster survives, including the real accounts that
--                      have rows here. They lose the characters they made in
--                      this campaign -- that is what a reset means -- but keep
--                      their access. Deleting a membership cascades much wider
--                      (see KNOWN_ISSUES.md) and is not this file's job.
--
--   the DM's row       Untouched, and load-bearing: after 018 every path into a
--                      campaign goes through a member with role 'dm', so a
--                      campaign that loses it is invisible to everyone and
--                      editable by no one. Nothing here writes to a row whose
--                      role is 'dm'.
--
--   locations, npcs    Not deleted, but SET. Reveal state is DM-only to change
--   map reveals,       (018), so a visitor cannot vandalise it, but whoever
--   fortunes           DMs the demo can, and a player only sees what is
--                      revealed. So the reveal flags are set to a fixed list
--                      below rather than left as the DM last clicked them. The
--                      rows themselves (and their DM notes) are untouched;
--                      missing seeded NPCs are added, never replaced.
--
--   party_inventory    Deleted and rewritten (closed 2026-11-15). Both are
--   party_currency     is_campaign_member for read AND write, so a visitor can
--                      spend the purse and empty or junk the hoard.
--
-- ---------------------------------------------------------------------------
-- PREREQS
-- ---------------------------------------------------------------------------
--
--   1. The campaign at the id below exists and has a member with role 'dm'.
--      Both are asserted before anything is written.
--
--   2. Six confirmed users at the emails in `roster`, made in Authentication ->
--      Users -> Add user with Auto Confirm on.
--
-- The five non-demo accounts do not need working passwords and never sign in.
-- They are written here by the table owner, and the one place this file cares
-- about their identity is a GUC, not a session -- see the gear insert. Only the
-- demo seat authenticates, and only through /demo.
--
-- ---------------------------------------------------------------------------
-- RE-RUNNABLE
-- ---------------------------------------------------------------------------
--
-- Yes, and that is the point: the second run produces the same six sheets as
-- the first, whatever happened in between. Assertions run before the delete, so
-- a failure costs nothing and leaves the campaign exactly as it was.
--
-- CORRECT OUTPUT: one result set, six rows, one per seat. no_byline must be 0
-- on every row -- see the gear insert. Recap, roster, encounter, hoard and
-- reveal counts arrive as notices in the Messages pane, because the SQL
-- editor renders only the last result set of a run and the six sheets are the
-- more useful one to see.


begin;

-- ===========================================================================
-- THE TARGET -- the only place the campaign id appears
-- ===========================================================================

-- A temp table rather than a repeated literal: every statement below reads the
-- id from here, so re-pointing this file at a different campaign is a one-line
-- edit with no chance of half of it moving. `on commit drop` means it cannot
-- outlive the transaction, including one that rolls back on a failed assertion.
create temp table target (campaign_id uuid primary key) on commit drop;

insert into target (campaign_id) values ('d721b412-2750-492e-bddd-7387fc464bba');


-- ===========================================================================
-- THE CAST -- everything editable is in this section
-- ===========================================================================

-- is_demo marks the seat the public link signs into. Exactly one row may carry
-- it, and the assertion block checks that: it is the character a visitor owns
-- and can edit, so it is the one worth stocking best.
--
-- Emails are matched to seats by hand and the pairing is arbitrary -- these
-- accounts differ only in their addresses. It is written down rather than
-- derived so a re-run cannot shuffle who plays whom.
--
-- display_name is the player, character_name is who they play: the two halves
-- of the "Aldric Thorne / played by Marek Dral" line the dashboard renders.
-- Character names must arrive trimmed and under 50 characters or 028's check
-- constraint rejects them.
create temp table roster (
  email          text primary key,
  display_name   text not null,
  character_name text not null,
  is_demo        boolean not null default false
) on commit drop;

insert into roster (email, display_name, character_name, is_demo) values
  ('test@demo.fake',   'Demo Guest',  'Anika Stroh',     true),
  ('test@demo1.fake',  'Marek Dral',  'Aldric Thorne',   false),
  ('test@demo2.fake',  'Sable Whit',  'Brother Ilyan',   false),
  ('test@demo3.fake',  'Tove Rask',   'Vasha Ridewind',  false),
  ('test1@false.fake', 'Corin Ashe',  'Nym Quickfinger', false),
  ('test4@demo.fake',  'Perrin Vale', 'Ysolde Karth',    false);

-- ---------------------------------------------------------------------------
-- purses (045)
-- ---------------------------------------------------------------------------

-- Five denominations, stored separately, with no conversion between them -- so
-- a purse holding only gold cannot pay a copper price. That is 045's accepted
-- trade-off and KNOWN_ISSUES.md documents it. The spread here exists so the
-- Character page shows all five columns populated on at least one sheet rather
-- than a row of zeroes.
create temp table purse (
  character_name text primary key,
  copper   int not null default 0,
  silver   int not null default 0,
  electrum int not null default 0,
  gold     int not null default 0,
  platinum int not null default 0
) on commit drop;

insert into purse (character_name, copper, silver, electrum, gold, platinum) values
  ('Anika Stroh',     84, 31, 4, 22, 2),
  ('Aldric Thorne',   12,  8, 0, 15, 0),
  ('Brother Ilyan',   40, 22, 0,  9, 1),
  ('Vasha Ridewind',  63, 14, 2, 11, 0),
  ('Nym Quickfinger', 27, 45, 1, 38, 0),
  ('Ysolde Karth',     5, 19, 0, 27, 3);

-- ---------------------------------------------------------------------------
-- gear
-- ---------------------------------------------------------------------------

-- from_dm decides whose name appears in the "added by" line: false stamps the
-- owner (they bought it), true stamps this campaign's DM (they were handed it).
-- 029 added that column because DM-granted and player-bought loot are genuinely
-- different things on a shared sheet, and a fixture where every row said the
-- same thing would never show the difference. Every seat here has at least one
-- of each.
--
-- item_name is joined against the shared catalogue, so these must match the
-- seeded rows exactly -- 'Lantern, Hooded' and 'Studded leather Armor' are the
-- catalogue's spellings, odd as the second one reads. Every name below was
-- checked against the live catalogue before this file was written, and the
-- assertion block re-checks them on every run.
--
-- equipped (057) is what the sheet derives AC and the attack table from, so
-- every seat wears its armour and holds its weapon. Only armour and weapon
-- rows may carry it, and each seat wears at most one body armour and one
-- shield -- the client un-equips the old armour when new armour goes on, and
-- the assertion block holds this file to the same rule.
create temp table gear (
  character_name text not null,
  item_name      text not null,
  quantity       int  not null,
  from_dm        boolean not null default false,
  equipped       boolean not null default false
) on commit drop;

insert into gear (character_name, item_name, quantity, from_dm, equipped) values
  -- Anika Stroh -- the demo seat, and the widest kit on the page, because it is
  -- the only sheet a visitor can edit: enough stacks to try a decrement, a stow
  -- and a give-away without running the sheet empty. An Artificer's kit since
  -- 2026-11-15: medium armour and a shield (AC 18 with DEX 16), a crossbow, and
  -- the All-Purpose Tool as the DM-handed magic item. The tools an Artificer is
  -- proficient with are proficiencies below, not gear -- the catalogue has no
  -- tool items.
  ('Anika Stroh',     'Scale Mail',            1,  false, true),
  ('Anika Stroh',     'Shield',                1,  false, true),
  ('Anika Stroh',     'Crossbow, Light',       1,  false, true),
  ('Anika Stroh',     'Case, Crossbow Bolt',   1,  false, false),
  ('Anika Stroh',     'Dagger',                2,  false, false),
  ('Anika Stroh',     'Component Pouch',       1,  false, false),
  ('Anika Stroh',     'Lantern, Hooded',       1,  false, false),
  ('Anika Stroh',     'Oil',                   3,  false, false),
  ('Anika Stroh',     'Rope',                  1,  false, false),
  ('Anika Stroh',     'Rations',               4,  false, false),
  ('Anika Stroh',     'Healer''s Kit',         1,  true,  false),
  ('Anika Stroh',     'Potion of Healing',     2,  true,  false),
  ('Anika Stroh',     'Holy Water',            1,  true,  false),
  ('Anika Stroh',     'All-Purpose Tool, +1',  1,  true,  false),

  -- Aldric Thorne -- the front line. No spells at all, which is the point of
  -- him: he is the seat that proves a sheet drops its empty half rather than
  -- printing a zero.
  ('Aldric Thorne',   'Greatsword',            1,  false, true),
  ('Aldric Thorne',   'Chain Mail',            1,  false, true),
  ('Aldric Thorne',   'Handaxe',               2,  false, false),
  ('Aldric Thorne',   'Rations',               5,  false, false),
  ('Aldric Thorne',   'Torch',                 10, false, false),
  ('Aldric Thorne',   'Potion of Healing',     2,  true,  false),

  -- Brother Ilyan -- the cleric, and the reason Holy Water is on the sheet.
  ('Brother Ilyan',   'Mace',                  1,  false, true),
  ('Brother Ilyan',   'Chain Shirt',           1,  false, true),
  ('Brother Ilyan',   'Shield',                1,  false, true),
  ('Brother Ilyan',   'Holy Symbol',           1,  false, false),
  ('Brother Ilyan',   'Holy Water',            3,  true,  false),
  ('Brother Ilyan',   'Healer''s Kit',         1,  false, false),
  ('Brother Ilyan',   'Rations',               4,  false, false),

  ('Vasha Ridewind',  'Longbow',               1,  false, true),
  ('Vasha Ridewind',  'Quiver',                1,  false, false),
  ('Vasha Ridewind',  'Studded leather Armor', 1,  false, true),
  ('Vasha Ridewind',  'Dagger',                2,  false, false),
  ('Vasha Ridewind',  'Hunting Trap',          1,  false, false),
  ('Vasha Ridewind',  'Rope',                  1,  false, false),
  ('Vasha Ridewind',  'Rations',               6,  false, false),
  ('Vasha Ridewind',  'Potion of Healing',     1,  true,  false),

  -- Dagger of Venom is one of 163's magic weapons with a base, so it reaches
  -- the attack table with its +1. Handed over by the DM, which is the honest
  -- way for a rogue to come by one.
  ('Nym Quickfinger', 'Dagger of Venom',       1,  true,  true),
  ('Nym Quickfinger', 'Dagger',                2,  false, false),
  ('Nym Quickfinger', 'Leather Armor',         1,  false, true),
  ('Nym Quickfinger', 'Crowbar',               1,  false, false),
  ('Nym Quickfinger', 'Caltrops',              2,  false, false),
  ('Nym Quickfinger', 'Lantern, Hooded',       1,  false, false),
  ('Nym Quickfinger', 'Oil',                   4,  false, false),
  ('Nym Quickfinger', 'Ball Bearings',         1,  true,  false),

  -- Ysolde Karth -- the deep caster. Light on gear on purpose: her panel is
  -- carried by the spell list, which is the widest one on the page. The cloak
  -- is a wondrous item that needs attunement, so one attunement line is on
  -- screen; its +1 AC is in her ac_bonus below, since nothing counts it.
  ('Ysolde Karth',    'Quarterstaff',          1,  false, true),
  ('Ysolde Karth',    'Spellbook',             1,  false, false),
  ('Ysolde Karth',    'Arcane Focus',          1,  false, false),
  ('Ysolde Karth',    'Component Pouch',       1,  false, false),
  ('Ysolde Karth',    'Potion of Healing',     1,  true,  false),
  ('Ysolde Karth',    'Cloak of Protection',   1,  true,  false);

-- ---------------------------------------------------------------------------
-- spells
-- ---------------------------------------------------------------------------

-- Spread across levels rather than piled at one, because a spell list groups
-- under a header per level (spellsByLevel in services/spells.ts) and a
-- single-level list never shows that the grouping works. Ysolde reaches level
-- 5, which is what makes her panel the tall one; Anika spans cantrip to 2,
-- the most a 5th-level Artificer can cast.
--
-- Every list is one its class can actually learn at its level: Anika's is the
-- Artificer list (wizard spells swapped out 2026-11-15), Nym's are an Arcane
-- Trickster's two (Disguise Self is illusion; Grease is his one any-school
-- pick), and Vasha's Conjure Animals is why she is a 9th-level Ranger.
--
-- Aldric is absent from this table entirely -- see the note on his gear above.
create temp table spellbook (
  character_name text not null,
  spell_name     text not null
) on commit drop;

insert into spellbook (character_name, spell_name) values
  ('Anika Stroh',     'Fire Bolt'),
  ('Anika Stroh',     'Guidance'),
  ('Anika Stroh',     'Cure Wounds'),
  ('Anika Stroh',     'Faerie Fire'),
  ('Anika Stroh',     'Absorb Elements'),
  ('Anika Stroh',     'Feather Fall'),
  ('Anika Stroh',     'Web'),
  ('Anika Stroh',     'Heat Metal'),
  ('Anika Stroh',     'Enlarge/Reduce'),

  ('Brother Ilyan',   'Sacred Flame'),
  ('Brother Ilyan',   'Guidance'),
  ('Brother Ilyan',   'Bless'),
  ('Brother Ilyan',   'Cure Wounds'),
  ('Brother Ilyan',   'Healing Word'),
  ('Brother Ilyan',   'Command'),
  ('Brother Ilyan',   'Aid'),
  ('Brother Ilyan',   'Spiritual Weapon'),
  ('Brother Ilyan',   'Revivify'),
  ('Brother Ilyan',   'Daylight'),

  ('Vasha Ridewind',  'Longstrider'),
  ('Vasha Ridewind',  'Jump'),
  ('Vasha Ridewind',  'Pass Without Trace'),
  ('Vasha Ridewind',  'Barkskin'),
  ('Vasha Ridewind',  'Conjure Animals'),

  -- Two, and both level 1: enough to put a spell panel on the rogue's seat
  -- without pretending he is a caster.
  ('Nym Quickfinger', 'Disguise Self'),
  ('Nym Quickfinger', 'Grease'),

  ('Ysolde Karth',    'Fire Bolt'),
  ('Ysolde Karth',    'Mage Armor'),
  ('Ysolde Karth',    'Magic Missile'),
  ('Ysolde Karth',    'Shield'),
  ('Ysolde Karth',    'Feather Fall'),
  ('Ysolde Karth',    'Misty Step'),
  ('Ysolde Karth',    'Mirror Image'),
  ('Ysolde Karth',    'Web'),
  ('Ysolde Karth',    'Fireball'),
  ('Ysolde Karth',    'Counterspell'),
  ('Ysolde Karth',    'Fly'),
  ('Ysolde Karth',    'Greater Invisibility'),
  ('Ysolde Karth',    'Polymorph'),
  ('Ysolde Karth',    'Cone of Cold'),
  ('Ysolde Karth',    'Telekinesis');

-- ---------------------------------------------------------------------------
-- feats
-- ---------------------------------------------------------------------------

-- Spread across categories for the reason the spell list is spread across
-- levels: the sheet groups them under a header per category (featsByCategory in
-- services/feats.ts), and a list that lands in one bucket never shows the
-- grouping works. The shared catalogue has six categories -- combat, defense,
-- general, magic, skill, social -- and between them these seats reach all six.
--
-- Aldric is in this table even though he is absent from `spellbook`: the point
-- of him is a character with no magic, not a character with nothing.
create temp table featbook (
  character_name text not null,
  feat_name      text not null
) on commit drop;

insert into featbook (character_name, feat_name) values
  -- Anika reaches four categories on her own, so the demo seat demonstrates the
  -- grouping without a visitor having to open anyone else's sheet.
  ('Anika Stroh',     'Dungeon Delver'),
  ('Anika Stroh',     'Actor'),
  ('Anika Stroh',     'Magic Initiate'),
  ('Anika Stroh',     'Durable'),

  ('Aldric Thorne',   'Great Weapon Master'),
  ('Aldric Thorne',   'Sentinel'),
  ('Aldric Thorne',   'Heavy Armor Master'),
  ('Aldric Thorne',   'Tough'),

  ('Brother Ilyan',   'War Caster'),
  ('Brother Ilyan',   'Inspiring Leader'),
  ('Brother Ilyan',   'Moderately Armored'),

  ('Vasha Ridewind',  'Sharpshooter'),
  ('Vasha Ridewind',  'Mobile'),
  ('Vasha Ridewind',  'Alert'),

  -- Skulker is the one seeded feat with a Dexterity prerequisite, so at least
  -- one row on one sheet exercises the prerequisite line under a name.
  ('Nym Quickfinger', 'Skulker'),
  ('Nym Quickfinger', 'Observant'),
  ('Nym Quickfinger', 'Lucky'),

  -- Elemental Adept is here to put a `repeatable` tag on screen. The sheet can
  -- still only hold it once -- see KNOWN_ISSUES.md.
  ('Ysolde Karth',    'Elemental Adept'),
  ('Ysolde Karth',    'Spell Sniper'),
  ('Ysolde Karth',    'Resilient');

-- ---------------------------------------------------------------------------
-- player-authored descriptions (046, 047)
-- ---------------------------------------------------------------------------

-- Both tables need rows or the feature is invisible on a fresh demo. Both carry
-- the same constraints: custom_name is 1-60 characters trimmed,
-- custom_description is 1-2000, and `_not_empty` refuses a row where both are
-- null -- a row that overrides nothing is unrepresentable by design.
--
-- All three shapes are exercised on purpose, because they render differently
-- and a fixture that only wrote one would never show the other two: name and
-- prose together, prose alone (the catalogue name stays), and a name alone.
create temp table item_desc (
  character_name     text not null,
  item_name          text not null,
  custom_name        text,
  custom_description text
) on commit drop;

insert into item_desc (character_name, item_name, custom_name, custom_description) values
  ('Anika Stroh', 'Lantern, Hooded', 'Sarn''s Lantern',
   'Taken from the wagon on the road in. The shutter sticks halfway, so it throws a bar of light instead of a circle -- useless for reading by, better for not being seen reading.'),
  ('Anika Stroh', 'Dagger', null,
   'Plain, balanced for throwing, and the only thing she brought from home that she has not had to explain to anybody.'),
  ('Nym Quickfinger', 'Crowbar', 'The Persuader', null);

create temp table spell_desc (
  character_name     text not null,
  spell_name         text not null,
  custom_name        text,
  custom_description text
) on commit drop;

insert into spell_desc (character_name, spell_name, custom_name, custom_description) values
  ('Anika Stroh', 'Fire Bolt', 'Emberflick',
   'Barely a spell. A snap of the fingers, and something the size of a wasp goes where she points and keeps going until it hits.'),
  ('Ysolde Karth', 'Fireball', null,
   'She has stopped calling it by its name in front of the others, on the grounds that saying it out loud makes them duck.');

-- ---------------------------------------------------------------------------
-- the sheet: scores, HP, race (056, 164)
-- ---------------------------------------------------------------------------

-- Written as an UPDATE of the row 056's trigger makes on the characters
-- insert, not an insert of its own. Scores are final, racial increases
-- included. hp_current sits below the maximum on two seats so the HP widget
-- shows a wounded bar next to full ones. ac_bonus is for what the sheet cannot
-- count -- Ysolde's Cloak of Protection.
--
-- race and subrace are names, resolved against the shared catalogue
-- (campaign_id is null) and checked in the assertion block. subrace is null
-- for races that have none (Human, Reborn).
create temp table sheet (
  character_name text primary key,
  str int not null, dex int not null, con int not null,
  int_ int not null, wis int not null, cha int not null,
  hp_max     int not null,
  hp_current int not null,
  ac_bonus   int not null default 0,
  race       text not null,
  subrace    text
) on commit drop;

insert into sheet (character_name, str, dex, con, int_, wis, cha, hp_max, hp_current, ac_bonus, race, subrace) values
  ('Anika Stroh',      8, 16, 14, 17, 13, 10, 38, 31, 0, 'Elf',      'Pallid Elf'),
  ('Aldric Thorne',   18, 12, 16,  9, 11, 11, 59, 44, 0, 'Human',    null),
  ('Brother Ilyan',   14, 10, 14, 10, 17, 13, 38, 38, 0, 'Reborn',   null),
  ('Vasha Ridewind',  12, 18, 14, 10, 15,  8, 76, 76, 0, 'Elf',      'Wood Elf'),
  ('Nym Quickfinger',  8, 18, 12, 14, 12, 13, 33, 33, 0, 'Halfling', 'Lightfoot'),
  ('Ysolde Karth',     8, 14, 14, 18, 12, 11, 56, 56, 1, 'Elf',      'Eladrin');

-- ---------------------------------------------------------------------------
-- classes (056, 066)
-- ---------------------------------------------------------------------------

-- One class each, all starting classes, all at or past their subclass level so
-- the subclass shows. Saving throws are not listed: they are written from the
-- class's own save_proficiencies, the way setStartingClass does it.
create temp table class_levels (
  character_name text primary key,
  class_name     text not null,
  subclass_name  text not null,
  level          int  not null
) on commit drop;

insert into class_levels (character_name, class_name, subclass_name, level) values
  ('Anika Stroh',     'Artificer', 'Battle Smith',        5),
  ('Aldric Thorne',   'Fighter',   'Battle Master',       5),
  ('Brother Ilyan',   'Cleric',    'Twilight Domain',     5),
  ('Vasha Ridewind',  'Ranger',    'Gloom Stalker',       9),
  ('Nym Quickfinger', 'Rogue',     'Arcane Trickster',    5),
  ('Ysolde Karth',    'Wizard',    'School of Evocation', 9);

-- ---------------------------------------------------------------------------
-- proficiencies (056)
-- ---------------------------------------------------------------------------

-- Skills from class and background, tools, and expertise (level 2). Not
-- listed: saves (above), and anything the race grants -- an elf's Perception
-- comes from the race row, so writing it here would only duplicate it. Keys
-- must satisfy 056's character_proficiencies_key_valid.
create temp table profs (
  character_name text not null,
  kind           text not null,
  key            text not null,
  level          int  not null default 1
) on commit drop;

insert into profs (character_name, kind, key, level) values
  ('Anika Stroh',     'skill', 'arcana',        1),
  ('Anika Stroh',     'skill', 'investigation', 1),
  ('Anika Stroh',     'skill', 'history',       1),
  ('Anika Stroh',     'skill', 'sleightOfHand', 1),
  ('Anika Stroh',     'tool',  'Thieves'' Tools', 1),
  ('Anika Stroh',     'tool',  'Tinker''s Tools', 1),
  ('Anika Stroh',     'tool',  'Smith''s Tools',  1),

  ('Aldric Thorne',   'skill', 'athletics',     1),
  ('Aldric Thorne',   'skill', 'intimidation',  1),
  ('Aldric Thorne',   'skill', 'perception',    1),
  ('Aldric Thorne',   'skill', 'survival',      1),
  ('Aldric Thorne',   'tool',  'Smith''s Tools',  1),

  ('Brother Ilyan',   'skill', 'insight',       1),
  ('Brother Ilyan',   'skill', 'religion',      1),
  ('Brother Ilyan',   'skill', 'medicine',      1),
  ('Brother Ilyan',   'skill', 'persuasion',    1),

  ('Vasha Ridewind',  'skill', 'stealth',       1),
  ('Vasha Ridewind',  'skill', 'survival',      1),
  ('Vasha Ridewind',  'skill', 'nature',        1),
  ('Vasha Ridewind',  'skill', 'animalHandling', 1),

  -- The one seat with expertise (Rogue 1), so the doubled bonus is on screen.
  ('Nym Quickfinger', 'skill', 'stealth',       2),
  ('Nym Quickfinger', 'skill', 'sleightOfHand', 1),
  ('Nym Quickfinger', 'skill', 'acrobatics',    1),
  ('Nym Quickfinger', 'skill', 'deception',     1),
  ('Nym Quickfinger', 'skill', 'perception',    1),
  ('Nym Quickfinger', 'skill', 'investigation', 1),
  ('Nym Quickfinger', 'tool',  'Thieves'' Tools', 2),

  ('Ysolde Karth',    'skill', 'arcana',        1),
  ('Ysolde Karth',    'skill', 'history',       1),
  ('Ysolde Karth',    'skill', 'investigation', 1),
  ('Ysolde Karth',    'skill', 'insight',       1);

-- ---------------------------------------------------------------------------
-- feature picks (095, 122, 151)
-- ---------------------------------------------------------------------------

-- Feature and option by name, both from the shared catalogue. The feature is
-- looked up within the seat's class, which is what keeps the Fighter's and the
-- Ranger's two "Fighting Style" rows apart. Counts are within 122's allowance
-- at these levels (Combat Superiority 3 at level 3, Infuse Item 4 at level 2);
-- its insert trigger refuses anything over, with 23514.
create temp table picks (
  character_name text not null,
  feature_name   text not null,
  option_name    text not null
) on commit drop;

insert into picks (character_name, feature_name, option_name) values
  ('Anika Stroh',     'Infuse Item',        'Enhanced Defense'),
  ('Anika Stroh',     'Infuse Item',        'Enhanced Weapon'),
  ('Anika Stroh',     'Infuse Item',        'Repeating Shot'),
  ('Anika Stroh',     'Infuse Item',        'Homunculus Servant'),

  ('Aldric Thorne',   'Fighting Style',     'Great Weapon Fighting'),
  ('Aldric Thorne',   'Combat Superiority', 'Trip Attack'),
  ('Aldric Thorne',   'Combat Superiority', 'Riposte'),
  ('Aldric Thorne',   'Combat Superiority', 'Menacing Attack'),

  ('Vasha Ridewind',  'Fighting Style',     'Archery');

-- ---------------------------------------------------------------------------
-- companion (167)
-- ---------------------------------------------------------------------------

-- Anika's steel defender. 167 stores damage, not current HP, and derives the
-- rest from her level and INT; a little damage shows the defender's own HP bar
-- doing something.
create temp table companion (
  character_name text primary key,
  kind           text not null,
  name           text,
  damage         int  not null default 0
) on commit drop;

insert into companion (character_name, kind, name, damage) values
  ('Anika Stroh', 'steel_defender', 'Rivet', 4);

-- ---------------------------------------------------------------------------
-- spent counters (153)
-- ---------------------------------------------------------------------------

-- Every seat starts rested (the cascade empties this table), except these, so
-- a counter that is not full is on screen somewhere. Not on Anika: the visitor
-- can spend her counters and rest them back, and should find them full.
-- resource is either 'slot:<n>' (spell slots have no feature_resources row)
-- or a feature name, resolved to 153's 'res:<uuid>' within the seat's class.
create temp table spent (
  character_name text not null,
  resource       text not null,
  used           int  not null
) on commit drop;

insert into spent (character_name, resource, used) values
  ('Aldric Thorne', 'Second Wind', 1),
  ('Brother Ilyan', 'slot:1',      2),
  ('Brother Ilyan', 'Channel Divinity', 1);

-- ---------------------------------------------------------------------------
-- the encounter (171)
-- ---------------------------------------------------------------------------

-- One fight in progress, round 2, so the Combat page has a turn order, a
-- bloodied monster and a downed one on a fresh demo. Rewritten on every run:
-- a player can write their own PC's initiative (171), so the demo seat can
-- reorder this. Anika's defender joins as a companion, which shares her
-- initiative and so has none of its own.
--
-- combatant is the character name for a PC and for a companion (its owner),
-- or the monster's display name. Monster status is not written: 171's trigger
-- derives it from hp_current.
create temp table fight (
  combatant  text not null,
  kind       text not null,   -- 'pc' | 'companion' | 'monster'
  initiative int,
  dex        int,             -- monsters only
  hp_max     int,
  hp_current int,
  ac         int,
  init_bonus int,
  is_turn    boolean not null default false,
  primary key (kind, combatant)
) on commit drop;

insert into fight (combatant, kind, initiative, dex, hp_max, hp_current, ac, init_bonus, is_turn) values
  ('Vasha Ridewind',   'pc',        21, null, null, null, null, null, false),
  ('Ysolde Karth',     'pc',        17, null, null, null, null, null, false),
  ('Aldric Thorne',    'pc',        14, null, null, null, null, null, true),
  ('Dire Wolf',        'monster',   13, 15,   37,   15,   14,   2,    false),
  ('Nym Quickfinger',  'pc',        12, null, null, null, null, null, false),
  ('Strahd Zombie',    'monster',    9,  6,   37,   37,    8,  -2,    false),
  ('Anika Stroh',      'pc',         8, null, null, null, null, null, false),
  ('Anika Stroh',      'companion', null, null, null, null, null, null, false),
  ('Brother Ilyan',    'pc',         6, null, null, null, null, null, false),
  ('Strahd Zombie 2',  'monster',    3,  6,   37,    0,    8,  -2,    false);

-- ---------------------------------------------------------------------------
-- reveal state (042, 048, 065)
-- ---------------------------------------------------------------------------

-- Where the party is after recap 3: the Village of Barovia, with the castle
-- looming over it. Everything named here is revealed and everything else in
-- that table is hidden, so the reset produces one state whatever the DM last
-- clicked. Mad Mary's townhouse and Rahadin stay hidden on purpose, so DM
-- preview has something to show that players do not see.
create temp table revealed (
  tbl  text not null,   -- 'location' | 'npc' | 'map' | 'fortune'
  name text not null,   -- location/npc name, map_key, or fortune card number
  is_found boolean not null default false,  -- fortunes only
  primary key (tbl, name)
) on commit drop;

insert into revealed (tbl, name, is_found) values
  ('map',      'barovia',                  false),
  ('map',      'village-of-barovia',       false),
  ('location', 'Village of Barovia',       false),
  ('location', 'Castle Ravenloft',         false),
  ('location', 'Tser Falls',               false),
  ('location', 'Burgomaster''s Mansion',   false),
  ('location', 'Blood of the Vine Tavern', false),
  ('location', 'Bildrath''s Mercantile',   false),
  ('location', 'Church',                   false),
  ('location', 'Cemetery',                 false),
  ('npc',      'Strahd von Zarovich',      false),
  ('npc',      'Ismark Kolyanovich',       false),
  ('npc',      'Ireena Kolyanovich',       false),
  ('npc',      'Kolyan Indirovich',        false),
  ('npc',      'Rose and Thorn',           false),
  ('npc',      'Lancelot',                 false),
  -- Two cards read, one of them already found, so the Fortunes page shows all
  -- three states: hidden, revealed, found. Found is for artifact cards only
  -- (campaign_fortunes_found_artifact_check), so it is card 1, not the ally.
  ('fortune',  '1',                        true),
  ('fortune',  '4',                        false);

-- NPCs the campaign's seed predates. 048's trigger only seeds campaigns made
-- after it, and this one was made before 058-064, so it has Strahd and Rahadin
-- and none of the Death House or Kolyanovich NPCs recap 3 talks about. Copied
-- from 064's seed_campaign_npcs, the latest version (seeding-portraits.md),
-- and added only where the name is missing -- npcs has no unique
-- (campaign_id, name), so `not exists` is the guard, 051's shape. Existing
-- rows are never rewritten. location is resolved by name; this campaign has no
-- Death House pin, so Rose and Thorn and Lancelot land with no location.
create temp table npc_backfill (
  name         text primary key,
  description  text not null,
  location     text not null,
  portrait_key text not null
) on commit drop;

insert into npc_backfill (name, description, location, portrait_key) values
  ('Rose and Thorn',
   'A young girl and her little brother.',
   'Death House', 'rose-and-thorn'),
  ('Lancelot',
   'A dog.',
   'Death House', 'lancelot'),
  ('Ismark Kolyanovich',
   'Son of the late burgomaster and the village''s acting leader, sworn to protect his sister Ireena.',
   'Burgomaster''s Mansion', 'ismark-kolyanovich'),
  ('Ireena Kolyanovich',
   'Portrait credit to www.patreon.com/calebisdrawing' || chr(10) ||
   'Daughter of the late burgomaster and sister to Ismark -- red-haired, sword in hand, and the object of Strahd''s attention.',
   'Village of Barovia', 'ireena-kolyanovich'),
  ('Kolyan Indirovich',
   'Portrait credit to www.patreon.com/calebisdrawing' || chr(10) ||
   'Burgomaster of the Village of Barovia, and father of Ismark and Ireena.',
   'Village of Barovia', 'kolyan-indirovich');

-- ---------------------------------------------------------------------------
-- party hoard and purse (021, 031, 045)
-- ---------------------------------------------------------------------------

-- Both are member-writable, so both are deleted and rewritten. Hoard stacks
-- are stamped as the DM's: party_inventory has no added_by trigger, and loot
-- in a shared pile is the DM's to have handed out.
create temp table hoard (
  item_name text primary key,
  quantity  int not null
) on commit drop;

insert into hoard (item_name, quantity) values
  ('Potion of Healing', 3),
  ('Rations',           10),
  ('Torch',             6),
  ('Holy Water',        2),
  ('Bag of Holding',    1);

create temp table hoard_purse (
  copper int not null, silver int not null, electrum int not null,
  gold   int not null, platinum int not null
) on commit drop;

insert into hoard_purse values (140, 65, 0, 210, 4);

-- ---------------------------------------------------------------------------
-- recaps
-- ---------------------------------------------------------------------------

-- Bodies, not just titles. Recaps is the one screen in this app that is pure
-- prose, so three empty recaps demonstrate nothing -- which is exactly what
-- this campaign held before this file existed.
--
-- session_number is unique per campaign, and these are rewritten from scratch
-- on every run rather than updated: a fresh insert leaves last_edited_by/at
-- null, so a visitor's edit does not leave their name on a recap after the
-- reset. Deleting also sidesteps stamp_session_recap entirely -- it is a BEFORE
-- UPDATE trigger and never sees an insert.
create temp table recap (
  session_number int primary key,
  title          text not null,
  body           text not null
) on commit drop;

insert into recap (session_number, title, body) values
  (1, 'The Mists Take the Road',
   'The road to Daggerford never arrived. Fog closed over the party somewhere past the last waystone, and when it thinned there were gates -- iron, open, and shutting behind them with nobody''s hand on them. A wagon sat abandoned on the verge, horses gone, traces still buckled. Aldric found the driver a hundred paces into the trees, arranged rather than fallen. Nobody slept.'),
  (2, 'The House on Old Svalich Road',
   'Two children stood in the road and asked for help with a monster in the basement. The house was warm, well kept, and entirely empty of the family whose portraits lined the stair. Nym found the nursery first, then the door behind the wardrobe. What waited below was not the monster the children had described, and neither child was in the road when the party climbed back out.'),
  (3, 'Barovia, and the Burgomaster''s Door',
   'The village keeps its shutters closed in daylight. Ismark Kolyanovich opened his to strangers because there was nobody left in Barovia to open it to, and asked the party to carry his sister out of the valley before dark. Brother Ilyan agreed before the rest had finished hearing the terms. Ysolde was the one who noticed the coffin in the front room was already occupied.');


-- ===========================================================================
-- ASSERTIONS -- before anything is deleted, not after
-- ===========================================================================

-- The inserts below all resolve a name to an id through a join, and a join that
-- finds nothing does not error -- it contributes no row. So a single mistyped
-- item name would leave one stack quietly missing from one sheet, and the only
-- symptom would be a tally that looks a bit low.
--
-- Running before the writes matters more here than it did in
-- test_campaign_seed.sql, because this file DELETES first. A failure caught
-- here costs nothing and the campaign is left exactly as it was; the same
-- failure caught afterwards would mean the demo had been emptied and not
-- refilled.

do $$
declare
  target_campaign uuid;
  missing         text;
  demo_seats      int;
begin
  select campaign_id into target_campaign from target;

  -- The campaign itself. Keyed by id, so "wrong name" and "two of them" -- the
  -- two cases test_campaign_seed.sql has to guard -- cannot arise. Only
  -- "deleted" can, and that is what this catches.
  if not exists (select 1 from campaigns where id = target_campaign) then
    raise exception
      'No campaign with id %. It was deleted, or this file is pointed at the wrong database.', target_campaign;
  end if;

  -- The DM row. 018 makes this the difference between a campaign and an
  -- orphan, and this file relies on it twice: for the from_dm byline below, and
  -- for the campaign being readable at all afterwards.
  if not exists (
    select 1 from campaign_members
    where campaign_id = target_campaign and role = 'dm'
  ) then
    raise exception
      'Campaign % has no member with role ''dm''. Adopt it before resetting -- after 018 nobody can read it.', target_campaign;
  end if;

  -- The six dashboard users, reported as one list rather than one at a time, so
  -- a half-finished round of clicking takes one run to diagnose instead of six.
  select string_agg(r.email, ', ' order by r.email) into missing
  from roster r
  where not exists (select 1 from auth.users u where u.email = r.email);

  if missing is not null then
    raise exception
      'No auth user for: %. Create them in Authentication -> Users -> Add user, with Auto Confirm on (see PREREQS).', missing;
  end if;

  -- Exactly one demo seat. Zero means the public link signs in as somebody with
  -- no character; two means the sheet a visitor lands on depends on which row
  -- the planner reached first.
  select count(*) into demo_seats from roster where is_demo;

  if demo_seats <> 1 then
    raise exception 'Expected exactly one is_demo seat in `roster`, found %.', demo_seats;
  end if;

  -- The demo seat is the only account here that ever authenticates, so it is
  -- the only one whose confirmation state matters. Unconfirmed, GoTrue refuses
  -- the password grant and /demo shows a sign-in failure with nothing on screen
  -- explaining why.
  if exists (
    select 1 from roster r
    join auth.users u on u.email = r.email
    where r.is_demo and u.email_confirmed_at is null
  ) then
    raise exception
      'The demo seat''s auth user is unconfirmed. Turn on Auto Confirm for it, or /demo cannot sign in.';
  end if;

  -- The other five never sign in, so unconfirmed is harmless there -- worth a
  -- notice rather than a raise, because forgetting the toggle is easy and the
  -- symptom is nothing at all.
  select string_agg(u.email, ', ' order by u.email) into missing
  from roster r join auth.users u on u.email = r.email
  where not r.is_demo and u.email_confirmed_at is null;

  if missing is not null then
    raise notice 'Unconfirmed (harmless, these never sign in): %', missing;
  end if;

  -- Every gear, spell, feat, purse and description row has to name a character
  -- in `roster`, or it is addressed to nobody.
  select string_agg(distinct character_name, ', ') into missing
  from (select character_name from gear
        union select character_name from spellbook
        union select character_name from featbook
        union select character_name from purse
        union select character_name from item_desc
        union select character_name from spell_desc) g
  where character_name not in (select character_name from roster);

  if missing is not null then
    raise exception 'Rows assigned to a character not in `roster`: %', missing;
  end if;

  -- `campaign_id is null` on the three catalogue lookups below, and it is
  -- load-bearing rather than tidy: it is what makes these the shared SRD rows.
  -- A homebrew row of the same name belonging to another campaign would resolve
  -- here and then read back null through 016's SELECT policy in the app --
  -- visible as a stack with no name on it, which is a bad way to find out.
  select string_agg(distinct n, ', ') into missing
  from (select item_name as n from gear
        union select item_name from item_desc) g
  where not exists (
    select 1 from items i where i.name = g.n and i.campaign_id is null
  );

  if missing is not null then
    raise exception 'Not in the shared item catalogue: %', missing;
  end if;

  select string_agg(distinct n, ', ') into missing
  from (select spell_name as n from spellbook
        union select spell_name from spell_desc) s
  where not exists (
    select 1 from spells sp where sp.name = s.n and sp.campaign_id is null
  );

  if missing is not null then
    raise exception 'Not in the shared spell catalogue: %', missing;
  end if;

  -- Same clause, and it matters more here than for spells: 039 shipped an
  -- INSERT policy with the table, so a campaign's homebrew feat of the same
  -- name is not hypothetical. Resolving one would attach a feat this campaign
  -- cannot read, which the sheet renders by throwing -- see 041's BLOCK 6.
  select string_agg(distinct f.feat_name, ', ') into missing
  from featbook f
  where not exists (
    select 1 from feats ft where ft.name = f.feat_name and ft.campaign_id is null
  );

  if missing is not null then
    raise exception 'Not in the shared feat catalogue: %', missing;
  end if;

  -- A description keys on (character, item) independently of whether that
  -- character owns the item -- 046/047 did that deliberately, so flavour
  -- survives a stow-and-take. It also means nothing in the schema would stop
  -- this fixture describing gear nobody is carrying, which would render as
  -- prose attached to an item absent from the sheet. Checked here instead.
  select string_agg(d.character_name || '/' || d.item_name, ', ') into missing
  from item_desc d
  where not exists (
    select 1 from gear g
    where g.character_name = d.character_name and g.item_name = d.item_name
  );

  if missing is not null then
    raise exception 'Item description for gear the character does not carry: %', missing;
  end if;

  select string_agg(d.character_name || '/' || d.spell_name, ', ') into missing
  from spell_desc d
  where not exists (
    select 1 from spellbook s
    where s.character_name = d.character_name and s.spell_name = d.spell_name
  );

  if missing is not null then
    raise exception 'Spell description for a spell the character does not know: %', missing;
  end if;

  -- Every seat needs a purse row, or 045's five columns fall to their defaults
  -- on that sheet and the reset is not reproducing what it claims to.
  select string_agg(r.character_name, ', ' order by r.character_name) into missing
  from roster r
  where not exists (select 1 from purse p where p.character_name = r.character_name);

  if missing is not null then
    raise exception 'No purse row for: %', missing;
  end if;

  -- ---- the sheet tables (056 onwards) ----

  -- Every seat needs a sheet and a class, or it renders as the all-10s,
  -- classless sheet this section exists to replace.
  select string_agg(r.character_name, ', ' order by r.character_name) into missing
  from roster r
  where not exists (select 1 from sheet s where s.character_name = r.character_name)
     or not exists (select 1 from class_levels c where c.character_name = r.character_name);

  if missing is not null then
    raise exception 'No sheet or class_levels row for: %', missing;
  end if;

  select string_agg(distinct character_name, ', ') into missing
  from (select character_name from sheet
        union select character_name from class_levels
        union select character_name from profs
        union select character_name from picks
        union select character_name from companion
        union select character_name from spent
        union select combatant from fight where kind <> 'monster') x
  where character_name not in (select character_name from roster);

  if missing is not null then
    raise exception 'Sheet rows assigned to a character not in `roster`: %', missing;
  end if;

  select string_agg(s.character_name, ', ') into missing
  from sheet s
  where s.hp_current > s.hp_max or s.hp_current < 0;

  if missing is not null then
    raise exception 'hp_current outside 0..hp_max for: %', missing;
  end if;

  -- Race and subrace, shared rows only, and the subrace must belong to the race.
  select string_agg(s.character_name || '/' || s.race || coalesce('/' || s.subrace, ''), ', ') into missing
  from sheet s
  where not exists (select 1 from races ra where ra.name = s.race and ra.campaign_id is null)
     or (s.subrace is not null and not exists (
           select 1 from subraces sr join races ra on ra.id = sr.race_id
           where sr.name = s.subrace and ra.name = s.race
             and sr.campaign_id is null and ra.campaign_id is null));

  if missing is not null then
    raise exception 'Race or subrace not in the shared catalogue: %', missing;
  end if;

  -- Class and subclass, shared rows, the subclass belonging to the class, and
  -- the level at least the class's subclass level -- below it the sheet hides
  -- the subclass, and the seat would demonstrate nothing.
  select string_agg(c.character_name || '/' || c.class_name || '/' || c.subclass_name, ', ') into missing
  from class_levels c
  where not exists (
    select 1 from classes cl join subclasses sc on sc.class_id = cl.id
    where cl.name = c.class_name and sc.name = c.subclass_name
      and cl.campaign_id is null and sc.campaign_id is null
      and c.level between cl.subclass_level and 20
  );

  if missing is not null then
    raise exception 'Class/subclass not in the shared catalogue, or level below the subclass level: %', missing;
  end if;

  -- Expertise is for skills and tools only (056's CHECK would also refuse it,
  -- but after the delete).
  select string_agg(p.character_name || '/' || p.key, ', ') into missing
  from profs p
  where p.level not in (1, 2) or (p.level = 2 and p.kind not in ('skill', 'tool'));

  if missing is not null then
    raise exception 'Invalid proficiency level: %', missing;
  end if;

  -- Each pick names exactly one shared feature of the seat's class, at or
  -- below its level, and an option linked to that feature. "Exactly one",
  -- because a name repeated within a class would make the insert's join write
  -- the pick twice.
  select string_agg(p.character_name || '/' || p.feature_name || '/' || p.option_name, ', ') into missing
  from picks p
  join class_levels c on c.character_name = p.character_name
  where (
    select count(*)
    from class_features f
    join classes cl on cl.id = f.class_id
    left join subclasses sc on sc.id = f.subclass_id
    join class_feature_options cfo on cfo.feature_id = f.id
    join feature_options o on o.id = cfo.option_id
    where f.name = p.feature_name and cl.name = c.class_name
      and f.campaign_id is null and o.campaign_id is null
      and o.name = p.option_name
      and f.level <= c.level
      and (sc.id is null or sc.name = c.subclass_name)
  ) <> 1;

  if missing is not null then
    raise exception 'Pick not resolvable to exactly one feature option of the seat''s class: %', missing;
  end if;

  -- Feature-named counters, resolved the same way. Slot keys must fit 153's
  -- CHECK.
  select string_agg(s.character_name || '/' || s.resource, ', ') into missing
  from spent s
  join class_levels c on c.character_name = s.character_name
  where s.resource !~ '^slot:[1-9]$'
    and (
      select count(*)
      from feature_resources fr
      join class_features f on f.id = fr.feature_id
      join classes cl on cl.id = f.class_id
      left join subclasses sc on sc.id = f.subclass_id
      where f.name = s.resource and cl.name = c.class_name
        and f.campaign_id is null and f.level <= c.level
        and (sc.id is null or sc.name = c.subclass_name)
    ) <> 1;

  if missing is not null then
    raise exception 'Spent counter not resolvable to exactly one feature resource: %', missing;
  end if;

  -- A steel defender only exists for a Battle Smith at 3rd level or higher.
  select string_agg(co.character_name, ', ') into missing
  from companion co
  left join class_levels c on c.character_name = co.character_name
  where co.kind = 'steel_defender'
    and not (c.class_name = 'Artificer' and c.subclass_name = 'Battle Smith' and c.level >= 3);

  if missing is not null then
    raise exception 'Steel defender on a seat that is not a Battle Smith 3+: %', missing;
  end if;

  -- Worn gear: armour and weapons only, one body armour and one shield at
  -- most per seat.
  select string_agg(distinct g.character_name || '/' || g.item_name, ', ') into missing
  from gear g
  join items i on i.name = g.item_name and i.campaign_id is null
  where g.equipped and i.kind not in ('armor', 'weapon');

  if missing is not null then
    raise exception 'Equipped item that is neither armour nor a weapon: %', missing;
  end if;

  select string_agg(x.character_name, ', ') into missing
  from (
    select g.character_name
    from gear g
    join items i on i.name = g.item_name and i.campaign_id is null
    where g.equipped and i.kind = 'armor'
    group by g.character_name
    having count(*) filter (where i.armor_category = 'shield') > 1
        or count(*) filter (where i.armor_category is distinct from 'shield') > 1
  ) x;

  if missing is not null then
    raise exception 'More than one body armour or shield equipped: %', missing;
  end if;

  -- ---- the campaign tables ----

  -- One fight, one current turn, and the companion's owner in it as a PC.
  -- The turn is on a PC: the pointer is set through `seat`, which a monster
  -- is not in.
  if (select count(*) from fight where is_turn and kind = 'pc') <> 1
     or exists (select 1 from fight where is_turn and kind <> 'pc') then
    raise exception 'Expected exactly one is_turn row in `fight`, on a PC.';
  end if;

  select string_agg(f.combatant, ', ') into missing
  from fight f
  where (f.kind = 'monster' and (f.dex is null or f.hp_max is null or f.hp_current is null
                                 or f.hp_current not between 0 and f.hp_max
                                 or length(f.combatant) > 40))
     or (f.kind = 'companion' and (f.initiative is not null or not exists (
           select 1 from companion co where co.character_name = f.combatant)))
     or (f.kind = 'companion' and not exists (
           select 1 from fight p where p.kind = 'pc' and p.combatant = f.combatant))
     or f.kind not in ('pc', 'companion', 'monster');

  if missing is not null then
    raise exception 'Malformed `fight` rows: %', missing;
  end if;

  -- Every reveal names a row that exists in this campaign (or, for an NPC, one
  -- the backfill is about to add), so a typo cannot quietly leave something
  -- hidden.
  select string_agg(rv.tbl || ':' || rv.name, ', ') into missing
  from revealed rv
  where (rv.tbl = 'location' and not exists (
           select 1 from locations l where l.campaign_id = target_campaign and l.name = rv.name))
     or (rv.tbl = 'npc' and not exists (
           select 1 from npcs n where n.campaign_id = target_campaign and n.name = rv.name)
         and not exists (select 1 from npc_backfill b where b.name = rv.name))
     or (rv.tbl = 'map' and not exists (
           select 1 from campaign_map_reveals m where m.campaign_id = target_campaign and m.map_key = rv.name))
     or (rv.tbl = 'fortune' and not exists (
           select 1 from campaign_fortunes cf where cf.campaign_id = target_campaign and cf.card::text = rv.name))
     or rv.tbl not in ('location', 'npc', 'map', 'fortune')
     or (rv.is_found and rv.tbl <> 'fortune')
     or (rv.is_found and not exists (
           select 1 from campaign_fortunes cf where cf.campaign_id = target_campaign
             and cf.card::text = rv.name and cf.is_artifact));

  if missing is not null then
    raise exception 'Reveal names nothing in this campaign: %', missing;
  end if;

  select string_agg(h.item_name, ', ') into missing
  from hoard h
  where not exists (select 1 from items i where i.name = h.item_name and i.campaign_id is null);

  if missing is not null then
    raise exception 'Hoard item not in the shared item catalogue: %', missing;
  end if;

  if (select count(*) from hoard_purse) <> 1 then
    raise exception 'Expected exactly one row in `hoard_purse`.';
  end if;
end
$$;


-- ===========================================================================
-- THE DELETE -- scoped to one campaign_id, and nothing wider
-- ===========================================================================

-- Everything hanging off a character goes with it by cascade: inventory,
-- spells, feats, both description tables, the sheet tables, picks, the
-- companion, any combatant rows, and spent use counters (153), so every demo
-- character starts rested. See the header for the full list and for what is
-- deliberately left alone.
--
-- This takes the DM's own character too, if they made one. That is correct --
-- the reset restores the six seats below and nothing else -- and it is why the
-- DM's campaign_members row is never touched: their access comes from the
-- membership, not from having a PC.
delete from characters
where campaign_id = (select campaign_id from target);

-- Deleted rather than updated, so last_edited_by/at come back null and a
-- visitor's name does not survive the reset on a recap they rewrote.
delete from session_recaps
where campaign_id = (select campaign_id from target);

-- The encounter, which outlives its combatants: `encounters` is unique on
-- campaign_id, so the fresh one below needs this one gone. Its monsters'
-- combatant and stat rows cascade.
delete from encounters
where campaign_id = (select campaign_id from target);

-- The party hoard and purse, both member-writable (see the header).
delete from party_inventory
where campaign_id = (select campaign_id from target);

delete from party_currency
where campaign_id = (select campaign_id from target);


-- ===========================================================================
-- THE WRITES
-- ===========================================================================

-- profiles, first, because campaign_members references it.
--
-- role is left at its 'player' default and never named. That is not cosmetic:
-- profiles.role is the global flag is_dm() reads, and the demo account is
-- posted in public -- holding it would let any visitor create campaigns
-- anywhere in this database. Never naming the column means neither a fresh
-- insert nor a re-run can set it, and 009 makes set_display_name the only
-- client path that writes this table at all.
--
-- The conflict clause updates display_name rather than doing nothing, and here
-- that is the reset doing its job: set_display_name is available to any
-- authenticated user, so a visitor can rename the demo seat, and do-nothing
-- would keep whatever they chose.
insert into profiles (id, display_name)
select u.id, r.display_name
from roster r
join auth.users u on u.email = r.email
on conflict (id) do update set display_name = excluded.display_name;

-- campaign_members. role defaults to 'player' and is named explicitly here
-- because the value matters: 018 reads this column, not profiles.role, for
-- every content policy, and 'player' is what keeps a visitor out of the DM
-- branches.
--
-- do-nothing rather than an update, and deliberately: the only row this could
-- collide with is one of these six, and re-running must never rewrite a role.
-- The DM's row is not in `roster` and is never reached by this statement.
insert into campaign_members (campaign_id, user_id, role)
select t.campaign_id, u.id, 'player'
from roster r
join auth.users u on u.email = r.email
cross join target t
on conflict (campaign_id, user_id) do nothing;

-- characters, with 045's purse columns in the same statement -- one row per
-- seat, one write.
--
-- No conflict clause, on purpose. The delete above removed every character in
-- this campaign, so a conflict here would mean something wrote one between the
-- delete and now, and that is worth an error rather than a silent skip.
insert into characters (campaign_id, user_id, name,
                        copper, silver, electrum, gold, platinum)
select t.campaign_id, u.id, r.character_name,
       p.copper, p.silver, p.electrum, p.gold, p.platinum
from roster r
join auth.users u on u.email = r.email
join purse p on p.character_name = r.character_name
cross join target t;

-- character name -> the id just inserted, resolved once through the owner
-- (roster.email -> auth.users -> characters.user_id) the way every insert
-- below this point used to spell out. The sheet writes read it from here.
create temp table seat (
  character_name text primary key,
  character_id   uuid not null unique
) on commit drop;

insert into seat (character_name, character_id)
select r.character_name, ch.id
from roster r
join auth.users u on u.email = r.email
cross join target t
join characters ch on ch.campaign_id = t.campaign_id and ch.user_id = u.id;

-- character_stats: UPDATE, because 056's create_character_stats_row trigger
-- made a default row for each character on the insert above.
-- pin_character_stats_row only pins character_id, so every column named here
-- lands.
update character_stats cs
set strength = s.str, dexterity = s.dex, constitution = s.con,
    intelligence = s.int_, wisdom = s.wis, charisma = s.cha,
    hp_max = s.hp_max, hp_current = s.hp_current, hp_temp = 0,
    ac_bonus = s.ac_bonus, speed_override = null,
    race_id = ra.id,
    subrace_id = sr.id
from sheet s
join seat st on st.character_name = s.character_name
join races ra on ra.name = s.race and ra.campaign_id is null
left join subraces sr on sr.name = s.subrace and sr.race_id = ra.id
                     and sr.campaign_id is null
where cs.character_id = st.character_id;

-- character_classes, at their final level. Before the picks, which reference
-- the entry, and at the final level rather than levelled up, so 122's
-- allowance trigger counts against the level the picks are meant for.
insert into character_classes (character_id, class_id, subclass_id, level, is_starting)
select st.character_id, cl.id, sc.id, c.level, true
from class_levels c
join seat st       on st.character_name = c.character_name
join classes cl    on cl.name = c.class_name and cl.campaign_id is null
join subclasses sc on sc.name = c.subclass_name and sc.class_id = cl.id
                  and sc.campaign_id is null;

-- Saving throws, from the class row, the way setStartingClass writes them.
insert into character_proficiencies (character_id, kind, key, level)
select st.character_id, 'save', unnest(cl.save_proficiencies), 1
from class_levels c
join seat st    on st.character_name = c.character_name
join classes cl on cl.name = c.class_name and cl.campaign_id is null;

insert into character_proficiencies (character_id, kind, key, level)
select st.character_id, p.kind, p.key, p.level
from profs p
join seat st on st.character_name = p.character_name;

-- Feature picks, joined exactly as the assertion block resolved them.
insert into character_feature_choices
  (character_id, character_class_id, class_id, feature_id, option_id)
select st.character_id, cc.id, cl.id, f.id, o.id
from picks p
join seat st          on st.character_name = p.character_name
join class_levels c   on c.character_name = p.character_name
join classes cl       on cl.name = c.class_name and cl.campaign_id is null
join character_classes cc on cc.character_id = st.character_id and cc.class_id = cl.id
join class_features f on f.class_id = cl.id and f.name = p.feature_name
                     and f.campaign_id is null and f.level <= c.level
left join subclasses sc on sc.id = f.subclass_id
join class_feature_options cfo on cfo.feature_id = f.id
join feature_options o on o.id = cfo.option_id and o.name = p.option_name
                      and o.campaign_id is null
where sc.id is null or sc.name = c.subclass_name;

insert into character_companions (character_id, kind, name, damage, hp_temp)
select st.character_id, co.kind, co.name, co.damage, 0
from companion co
join seat st on st.character_name = co.character_name;

-- Spent counters: slot keys as written, feature names as 'res:<uuid>'.
insert into character_resource_uses (character_id, resource_key, used)
select st.character_id, s.resource, s.used
from spent s
join seat st on st.character_name = s.character_name
where s.resource ~ '^slot:[1-9]$';

insert into character_resource_uses (character_id, resource_key, used)
select st.character_id, 'res:' || fr.id, s.used
from spent s
join seat st          on st.character_name = s.character_name
join class_levels c   on c.character_name = s.character_name
join classes cl       on cl.name = c.class_name and cl.campaign_id is null
join class_features f on f.class_id = cl.id and f.name = s.resource
                     and f.campaign_id is null and f.level <= c.level
left join subclasses sc on sc.id = f.subclass_id
join feature_resources fr on fr.feature_id = f.id
where s.resource !~ '^slot:[1-9]$'
  and (sc.id is null or sc.name = c.subclass_name);

-- character_inventory, in two parts, and the reason is a trigger that is not
-- currently there.
--
-- 029 defines a BEFORE INSERT trigger assigning `new.added_by := auth.uid()` --
-- identity from the JWT, never the payload, which is what stops a player filing
-- their own find under the DM's name. test_campaign_seed.sql is written for
-- that world: it sets request.jwt.claims per adder, omits added_by from the
-- column list entirely, and says naming it "would only be a value for the
-- trigger to discard."
--
-- **When this file was written, 029 had not been applied** (it landed
-- 2026-11-05). With no trigger present the GUC technique was a silent no-op on
-- its own: the first run of this file produced null bylines on all 45 stacks,
-- because nothing was reading the claim it went to the trouble of setting. So
-- this file does BOTH, and is correct either way round:
--
--   029 not applied (before)  added_by is named in the insert, and the named
--                             value lands.
--   029 applied (now)         the trigger overwrites added_by with auth.uid(),
--                             which the GUC has already set to that same
--                             adder_id. Identical rows, no edit needed here.
--
-- Naming the column is therefore not the mistake test_campaign_seed.sql warns
-- about; belt and braces are what make the file survive 029 landing without
-- anyone remembering this fixture exists.
--
-- Note what is NOT done here: no `set local role`. auth.uid() reads
-- request.jwt.claims->>'sub', which set_config supplies on its own, and
-- switching role would re-enable RLS -- at which point 028's INSERT policy
-- (`user_id = auth.uid()`) refuses every row for a character that is not the
-- current claim's. The GUC is the whole technique; the role must stay owner.
--
-- Hence the resolved table: the identity has to be constant across an INSERT
-- (one GUC, one statement), so rows are grouped by adder and inserted a group
-- at a time.

create temp table gear_resolved (
  character_id uuid not null,
  item_id      uuid not null,
  quantity     int  not null,
  adder_id     uuid not null,
  equipped     boolean not null,
  primary key (character_id, item_id)
) on commit drop;

-- The join to characters goes through roster.email -> auth.users -> user_id,
-- NOT through characters.name. That mattered in test_campaign_seed.sql because
-- a rename would break a name join; here the characters were just inserted from
-- these same rows, so it is the owner that is stable either way. Kept for the
-- same reason it was written: character_name is the key inside this file's own
-- tables, where it is only ever compared against itself.
insert into gear_resolved (character_id, item_id, quantity, adder_id, equipped)
select ch.id,
       i.id,
       g.quantity,
       case when g.from_dm then dm.user_id else ch.user_id end,
       g.equipped
from gear g
join roster r     on r.character_name = g.character_name
join auth.users u on u.email = r.email
cross join target t
join characters ch on ch.campaign_id = t.campaign_id and ch.user_id = u.id
join items i       on i.name = g.item_name and i.campaign_id is null
cross join lateral (
  select cm.user_id from campaign_members cm
  where cm.campaign_id = t.campaign_id and cm.role = 'dm'
  limit 1
) dm;

do $$
declare
  adder uuid;
begin
  -- Seven passes: one per seat's owner, plus the DM. Grouped rather than looped
  -- row by row because the GUC is the only thing that has to change between
  -- them, and it changes once per adder.
  for adder in select distinct adder_id from gear_resolved loop
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', adder, 'role', 'authenticated')::text,
      true  -- transaction-local, so it cannot outlive this file
    );

    -- added_by IS named, unlike test_campaign_seed.sql -- see the block above.
    -- Before 029 landed this value was what landed; now the trigger
    -- replaces it with auth.uid(), which the set_config above has just set to
    -- the same adder. The GUC and the column agree by construction, so the row
    -- is the same under either regime.
    insert into character_inventory (character_id, item_id, quantity, added_by, equipped)
    select gr.character_id, gr.item_id, gr.quantity, gr.adder_id, gr.equipped
    from gear_resolved gr
    where gr.adder_id = adder;
  end loop;

  -- Cleared rather than left set. Nothing after this point reads auth.uid(),
  -- but leaving the last adder's identity in the session is the kind of thing
  -- that makes a later statement in the same editor tab behave oddly for a
  -- reason nobody would look for.
  perform set_config('request.jwt.claims', '', true);
end
$$;

-- character_spells. No conflict clause for the reason the characters insert has
-- none: the cascade emptied this table for these characters moments ago.
insert into character_spells (character_id, spell_id)
select ch.id, sp.id
from spellbook s
join roster r     on r.character_name = s.character_name
join auth.users u on u.email = r.email
cross join target t
join characters ch on ch.campaign_id = t.campaign_id and ch.user_id = u.id
join spells sp     on sp.name = s.spell_name and sp.campaign_id is null;

-- character_feats, 037's table one over and written the same way.
insert into character_feats (character_id, feat_id)
select ch.id, ft.id
from featbook f
join roster r     on r.character_name = f.character_name
join auth.users u on u.email = r.email
cross join target t
join characters ch on ch.campaign_id = t.campaign_id and ch.user_id = u.id
join feats ft      on ft.name = f.feat_name and ft.campaign_id is null;

-- The description tables (047, 046). Both key on the character's idea of the
-- thing rather than on the row that says they have it, which is why neither
-- join touches character_inventory or character_spells.
insert into character_item_descriptions
  (character_id, item_id, custom_name, custom_description)
select ch.id, i.id, d.custom_name, d.custom_description
from item_desc d
join roster r     on r.character_name = d.character_name
join auth.users u on u.email = r.email
cross join target t
join characters ch on ch.campaign_id = t.campaign_id and ch.user_id = u.id
join items i       on i.name = d.item_name and i.campaign_id is null;

insert into character_spell_descriptions
  (character_id, spell_id, custom_name, custom_description)
select ch.id, sp.id, d.custom_name, d.custom_description
from spell_desc d
join roster r     on r.character_name = d.character_name
join auth.users u on u.email = r.email
cross join target t
join characters ch on ch.campaign_id = t.campaign_id and ch.user_id = u.id
join spells sp     on sp.name = d.spell_name and sp.campaign_id is null;

-- Recaps. last_edited_by/at are left unset rather than stamped: they are the
-- app's record of who touched a recap last, and after a reset the honest answer
-- is nobody.
insert into session_recaps (campaign_id, session_number, title, body)
select t.campaign_id, rc.session_number, rc.title, rc.body
from recap rc
cross join target t;

-- NPCs the campaign's seed predates, added only if missing. No npc_dm_notes
-- row: 064's only seeded note is Rose and Thorn's, and notes are the DM's to
-- write -- npcs.ts reads a missing row as no notes.
insert into npcs (campaign_id, name, description, location_id, is_revealed, portrait_key)
select t.campaign_id, b.name, b.description,
       (select l.id from locations l
        where l.campaign_id = t.campaign_id and l.name = b.location
        limit 1),
       false, b.portrait_key
from npc_backfill b
cross join target t
where not exists (
  select 1 from npcs n where n.campaign_id = t.campaign_id and n.name = b.name
);

-- Reveal state: listed means revealed, unlisted means hidden. Plain UPDATEs as
-- the table owner; the pin triggers on these tables restore only the columns
-- they pin, and is_revealed / is_found are the columns the DM edits.
update locations l
set is_revealed = exists (
  select 1 from revealed rv where rv.tbl = 'location' and rv.name = l.name)
where l.campaign_id = (select campaign_id from target);

update npcs n
set is_revealed = exists (
  select 1 from revealed rv where rv.tbl = 'npc' and rv.name = n.name)
where n.campaign_id = (select campaign_id from target);

update campaign_map_reveals m
set is_revealed = exists (
  select 1 from revealed rv where rv.tbl = 'map' and rv.name = m.map_key)
where m.campaign_id = (select campaign_id from target);

update campaign_fortunes cf
set is_revealed = rv.name is not null,
    is_found    = coalesce(rv.is_found, false)
from campaign_fortunes cf2
left join revealed rv on rv.tbl = 'fortune' and rv.name = cf2.card::text
where cf.id = cf2.id
  and cf.campaign_id = (select campaign_id from target);

-- The encounter: the row, then its combatants, then monster stats, then the
-- turn pointer, which needs a combatant id to point at.
insert into encounters (campaign_id, round)
select t.campaign_id, 2 from target t;

insert into encounter_combatants (encounter_id, kind, character_id, name, dex, initiative)
select e.id, f.kind,
       case when f.kind = 'monster' then null else st.character_id end,
       case when f.kind = 'monster' then f.combatant end,
       f.dex,
       f.initiative
from fight f
join encounters e on e.campaign_id = (select campaign_id from target)
left join seat st on st.character_name = f.combatant and f.kind <> 'monster';

insert into encounter_monster_stats (combatant_id, hp_max, hp_current, hp_temp, ac, init_bonus)
select ec.id, f.hp_max, f.hp_current, 0, f.ac, f.init_bonus
from fight f
join encounters e on e.campaign_id = (select campaign_id from target)
join encounter_combatants ec on ec.encounter_id = e.id
                            and ec.kind = 'monster' and ec.name = f.combatant
where f.kind = 'monster';

update encounters e
set turn_combatant_id = ec.id
from fight f
join seat st on st.character_name = f.combatant
join encounter_combatants ec on ec.character_id = st.character_id and ec.kind = f.kind
where f.is_turn
  and ec.encounter_id = e.id
  and e.campaign_id = (select campaign_id from target);

-- The party hoard and purse. added_by is the DM (see the CAST note).
insert into party_inventory (campaign_id, item_id, quantity, added_by)
select t.campaign_id, i.id, h.quantity, dm.user_id
from hoard h
cross join target t
join items i on i.name = h.item_name and i.campaign_id is null
cross join lateral (
  select cm.user_id from campaign_members cm
  where cm.campaign_id = t.campaign_id and cm.role = 'dm'
  limit 1
) dm;

insert into party_currency (campaign_id, copper, silver, electrum, gold, platinum)
select t.campaign_id, hp.copper, hp.silver, hp.electrum, hp.gold, hp.platinum
from hoard_purse hp
cross join target t;


-- ===========================================================================
-- WHAT LANDED
-- ===========================================================================

-- The counts that do not fit on the per-character result set arrive as notices,
-- because the SQL editor renders only the LAST result set of a run -- a second
-- select here would silently replace the six sheets below, which are the more
-- useful thing to see.
do $$
declare
  target_campaign uuid;
  n_recaps  int;
  n_members int;
  n_chars   int;
  n_fight   int;
  n_turn    int;
  n_hoard   int;
  n_npcs    int;
  revealed_summary text;
begin
  select campaign_id into target_campaign from target;

  select count(*) into n_recaps  from session_recaps  where campaign_id = target_campaign;
  select count(*) into n_members from campaign_members where campaign_id = target_campaign;
  select count(*) into n_chars   from characters       where campaign_id = target_campaign;
  select count(*) into n_fight
    from encounter_combatants ec join encounters e on e.id = ec.encounter_id
   where e.campaign_id = target_campaign;
  select count(*) into n_turn
    from encounters where campaign_id = target_campaign and turn_combatant_id is not null;
  select count(*) into n_hoard from party_inventory where campaign_id = target_campaign;
  select count(*) into n_npcs  from npcs where campaign_id = target_campaign;

  select format('locations %s/%s, npcs %s/%s, maps %s/%s, fortunes %s/%s (found %s)',
    (select count(*) filter (where is_revealed) from locations where campaign_id = target_campaign),
    (select count(*) from locations where campaign_id = target_campaign),
    (select count(*) filter (where is_revealed) from npcs where campaign_id = target_campaign),
    n_npcs,
    (select count(*) filter (where is_revealed) from campaign_map_reveals where campaign_id = target_campaign),
    (select count(*) from campaign_map_reveals where campaign_id = target_campaign),
    (select count(*) filter (where is_revealed) from campaign_fortunes where campaign_id = target_campaign),
    (select count(*) from campaign_fortunes where campaign_id = target_campaign),
    (select count(*) filter (where is_found) from campaign_fortunes where campaign_id = target_campaign))
  into revealed_summary;

  raise notice 'recaps: % (expect 3)', n_recaps;
  raise notice 'characters: % (expect 6)', n_chars;
  raise notice 'campaign_members: % (6 seeded seats + the DM + anyone else already on the roster)', n_members;
  raise notice 'encounter combatants: % (expect %), turn set: % (expect 1)',
    n_fight, (select count(*) from fight), n_turn;
  raise notice 'party hoard stacks: % (expect %)', n_hoard, (select count(*) from hoard);
  raise notice 'revealed: %', revealed_summary;
end
$$;

-- Counted from the tables rather than from this file's own lists, so this
-- reports what the database holds and not what the file meant to put there.
--
-- Aldric Thorne showing spells = 0 is correct and is the point of him.
--
-- no_byline is the column that checks the trigger workaround above actually
-- worked, and it must be 0 on every row. Any other number means added_by came
-- back null -- the request.jwt.claims loop did not take -- and those stacks
-- render with no "added by" name in the app. Not fatal, and nothing else on
-- screen would tell you.
select ch.name        as character,
       p.display_name as played_by,
       (select string_agg(cl.name || coalesce(' (' || sc.name || ')', '') || ' ' || cc.level, ', ')
        from character_classes cc
        join classes cl on cl.id = cc.class_id
        left join subclasses sc on sc.id = cc.subclass_id
        where cc.character_id = ch.id) as class,
       (select coalesce(sr.name, ra.name)
        from character_stats cs
        left join races ra on ra.id = cs.race_id
        left join subraces sr on sr.id = cs.subrace_id
        where cs.character_id = ch.id) as race,
       (select cs.hp_current || '/' || cs.hp_max from character_stats cs
        where cs.character_id = ch.id) as hp,
       (select count(*) from character_proficiencies cp
        where cp.character_id = ch.id) as profs,
       (select count(*) from character_feature_choices fc
        where fc.character_id = ch.id) as picks,
       (select count(*) from character_companions co
        where co.character_id = ch.id) as companions,
       (select count(*) from character_resource_uses ru
        where ru.character_id = ch.id) as spent,
       (select count(*) from character_inventory ci
        where ci.character_id = ch.id and ci.equipped) as worn,
       (select count(*) from character_inventory ci
        where ci.character_id = ch.id) as gear,
       (select coalesce(sum(ci.quantity), 0) from character_inventory ci
        where ci.character_id = ch.id) as carried,
       (select count(*) from character_spells cs
        where cs.character_id = ch.id) as spells,
       (select count(*) from character_feats cf
        where cf.character_id = ch.id) as feats,
       (select count(*) from character_item_descriptions d
        where d.character_id = ch.id)
       + (select count(*) from character_spell_descriptions d
          where d.character_id = ch.id) as descriptions,
       ch.copper || '/' || ch.silver || '/' || ch.electrum || '/'
         || ch.gold || '/' || ch.platinum as purse_cp_sp_ep_gp_pp,
       (select count(*) from character_inventory ci
        where ci.character_id = ch.id and ci.added_by is null) as no_byline
from characters ch
join target t on t.campaign_id = ch.campaign_id
left join profiles p on p.id = ch.user_id
order by ch.name;

commit;


-- ===========================================================================
-- AFTERWARDS
-- ===========================================================================
--
-- No `notify pgrst, 'reload schema'` needed: this file creates no table, column
-- or function, and the schema cache does not track rows. Nothing to regenerate
-- either -- npm run gen:types reads the schema, which is unchanged.
--
-- There is no teardown counterpart. test_campaign_teardown.sql exists to remove
-- a campaign that was only ever a fixture; this one is a live demo that should
-- outlive every reset, and the six auth users behind it are reused rather than
-- recreated. To retire the demo entirely, delete the campaign from the app
-- (020) and the six users from the dashboard, in that order -- the ordering
-- argument in test_campaign_teardown.sql's header applies here unchanged.

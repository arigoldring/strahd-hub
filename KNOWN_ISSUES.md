# Known issues

Open work: things that are wrong and still want fixing. Each entry says what it
takes to trigger, what it costs, and what the fix would be.

**Current through migration 168. Last updated 2026-11-07.**

This is the single source of truth for open work. `CLAUDE.md` holds decisions
and invariants and deliberately does not duplicate anything below. Two sibling
files hold what is no longer open:

- `ACCEPTED_ISSUES.md` — trade-offs judged not worth fixing. Move an entry
  there when it is accepted, and back here if the answer changes.
- `FIXED_ISSUES.md` — entries that have been fixed, newest first. Move an entry
  there when it is fixed rather than deleting it.

Older comments in `db/` and `src/` say "see KNOWN_ISSUES" for entries that now
live in one of those two files; search all three.

---

## Open

### Death House sits at placeholder coordinates (noted 2026-09-18)

048 added Death House to the locations seed with `(20.0, 70.0)`, and its header
said to replace those with real coordinates from `MapView`'s DM coordinate finder
before running. That never happened. The live campaign's row (from 048's
trigger) and every campaign created since use the made-up spot. 051 flagged it
and left it out of scope.

**Trigger:** opening the Village of Barovia map once Death House is revealed.

**Cost:** one pin in the wrong place. Lancelot's home resolves correctly, since
that lookup is by name.

**Fix:** read the real coordinates off the finder, then a small migration that
does two things: re-creates `seed_campaign_locations` (fifth version, copied
from 048) with those numbers, and updates `x`/`y` on existing Death House rows
where `map_key = 'village-of-barovia'`. `locations` has no pin trigger, so a
plain UPDATE works. The client can't move pins, despite 050's header suggesting
"drag it", so this can't be done in the app.

### `truncate locations cascade` now empties `npcs` (noted 2026-08-14)

`npcs` carries a composite FK to `locations`, and `TRUNCATE CASCADE` follows
every foreign key pointing at a table regardless of what that key's `ON DELETE`
action says. The FK's `on delete set null (location_id)` protects a single-row
delete and does nothing here.

**Trigger:** reseeding the map. This project has done it before (015, 026).

**Cost:** the entire NPC roster, silently, as a side effect of a statement about
locations.

**Fix:** `delete from locations where ...` instead of `truncate`, or reseed the
roster after. Flagged at the bottom of `033_npcs.sql` as well as here.

### `ignoreDuplicates: true` is load-bearing on `character_spells` (noted 2026-08-17)

037 deliberately gives `character_spells` no UPDATE policy — every column is a
key or a defaulted timestamp, so there is nothing an update could change. That
decision is documented in the migration. What is documented nowhere is the client
contract it creates.

supabase-js renders `{ ignoreDuplicates: true }` as
`Prefer: resolution=ignore-duplicates` → `ON CONFLICT DO NOTHING`, which needs
only INSERT privilege. Set it to `false` and PostgREST emits
`ON CONFLICT DO UPDATE` instead; the table-level UPDATE grant still exists, so
the _first_ add succeeds and only the conflicting one fails with 42501.

**Trigger:** anyone editing `addSpellToCharacter` who reads `ignoreDuplicates` as
a preference rather than a requirement.

**Cost:** the worst failure shape this project has — "works once per spell, then
starts refusing mid-session." It is exactly the bug 033 wrote a whole
verification block to catch on `npc_dm_notes`, arriving from the opposite
direction. It will not show up in a first-run smoke test.

**Fix:** one comment in `services/characterSpells.ts` naming the dependency. The
same note belongs on `getOrCreateProfile`, where the argument is different (the
losing insert is expected) but the mechanism is the same.

### The party cache goes stale for a minute after a write from a sheet (noted 2026-08-17, corrected 2026-08-22)

`useCharacterSpells` and `useCharacterInventory` invalidate only their own key.
The same rows are read through a _second_ cache entry, `["party", campaignId]`,
built from `getPartyCharacters`' embeds and consumed by `CharacterRoster` (and by
`Party.tsx`, whose route is currently commented out). `TeachForm`, `GiveForm` and
`Character.tsx`'s `GiveItemForm` hand-invalidate the party key because they know
this; nothing on the character's own sheet does.

**This entry used to say the party cache was "correct only because `staleTime` is
0". That is no longer true and the conclusion inverted with it** —
`lib/queryClient.ts` sets `staleTime: 60_000`, with a comment arguing for it (a
cache that refetches on every mount isn't a cache, and it hides missing
invalidations). So the predicted breakage has already happened, quietly: a spell
or item added from your own sheet leaves the roster's tally wrong until the entry
goes stale or the window is refocused.

**Trigger:** add a spell to your own sheet, then have the DM open the roster
inside the next minute without refocusing the window.

**Cost:** small and real rather than hypothetical. `CharacterRoster` shows counts
only ("3 stacks · 5 spells"), so what's wrong is a number, briefly. It would cost
more the day anything on that cache entry renders content rather than a tally.

**Not widened by 046/047.** The overrides ride `["characterSpells", …]` and
`["characterInventory", …]`, which their own mutations invalidate, and
`PARTY_SELECT` doesn't carry them — the roster shows no descriptions, so there is
nothing new to go stale.

**Fix:** invalidate `["party", campaignId]` inside both character hooks, which
means giving those hooks the campaign id they currently and deliberately do
without. Decide it once, in one sitting, for both.

### `CharacterSpellRow` asserts the embedded spell is non-null (noted 2026-08-17)

`CHARACTER_SPELLS_SELECT` is `"*, spells(*)"` and the row type declares
`spells: Tables<"spells">`. 037 names the one path that could falsify it: a spell
belonging to another campaign's homebrew, whose `character_spells` row resolves
while 022's SELECT policy filters the embed to null. `toCharacterSpellEntry`
would then call `toSpell(null)` and throw a TypeError rather than a handled
error.

**Trigger:** homebrew spells existing. `spells` has no INSERT policy, so nothing
can create one today.

**Cost:** currently zero. Note that "unreachable because there's no INSERT
policy" is exactly the shape that protected `items` until 025 shipped and made it
reachable — see "Cross-campaign homebrew visible in every campaign's catalogue"
in `FIXED_ISSUES.md`. This is the same bet, one table over,
and 039 has since lost it for feats: `character_feats` has the identical hole and
it is live, because feats shipped with DM homebrew in the same migration as the
table. See "`CharacterFeatRow` asserts the embedded feat is non-null" below for
what that actually costs.

**Fix when spell homebrew lands:** either scope `character_spells`' FK the way
`npcs` scopes its location FK (a composite key that makes the cross-campaign row
unrepresentable), or make the embed nullable in the type and handle it. The FK is
the better answer; the type change is the cheap one.

### `getCharacterSpells` returns rows in no particular order (noted 2026-08-17)

Every sibling service owns its ordering — `getNpcs` orders by name,
`getPartyCharacters` sorts both embeds after mapping. This one has no `.order()`
and no post-sort, and is correct only because every consumer pipes it through
`spellsByLevel`, which sorts.

**Cost:** none today; a surprise for the first consumer that renders the list
raw.

**Fix:** sort in the service after mapping (the DB can't order by the embedded
name usefully), or state in the file that ordering is the caller's job here and
why. Either is fine — the current silence is the problem.

Related and smaller: `getPartyCharacters` sorts `spells` by level-then-name, and
`PartyCharacter.spells` is commented as "already sorted… the order every caller
wants" — but its only consumer immediately re-groups with `spellsByLevel`, which
sorts again. Drop the sort or drop the claim.

### `removeSpellFromCharacter` treats a refused delete as success (noted 2026-08-17)

No zero-row check, matching `removeFromCharacterInventory`. The justification in
the comment — everyone who reaches it already passed `can_edit_character` — is
true only because the remove control renders on your own sheet and nowhere else.

**Trigger:** putting a remove control anywhere a non-owner non-DM can reach it.
The Party panel is the obvious candidate, since Give and Grant already live
there.

**Cost:** a silent success followed by the row reappearing on the next refetch.
Compare `deleteCharacter` and `deleteRecap`, which both use
`.select().maybeSingle()` precisely so a refused delete surfaces.

**Fix:** name the condition in the comment now (one sentence), and add the check
if the control ever moves.

### `feats.repeatable` is display-only; a sheet can hold each feat once (noted 2026-08-19)

041 gives `character_feats` a `unique (character_id, feat_id)`, copied from 037
where it is simply true — a spell is known or it is not. Feats are not all like
that: Elemental Adept and Magic Initiate both say you may take them again, and
the seed marks them `repeatable = true`. The card and the row print the flag, and
the second add is silently swallowed by the same `ignoreDuplicates` that makes an
accidental double-add a no-op. Nothing tells the player the difference.

**Trigger:** taking either of those two feats twice. 041's BLOCK 5 is the case,
written from the accident side.

**Cost:** two feats out of forty-two, on a sheet that records no level either, so
"took it at 8 and again at 12" is not expressible in the first place.

**Fix:** a `times_taken int not null default 1 check (times_taken > 0)` and 030's
insert-or-increment RPC, since PostgREST cannot express increment — which is the
whole apparatus `character_spells` was designed to avoid. Worth it only if
someone actually hits this. Cheaper interim: have the picker disable a feat
already on the sheet, so the no-op is visible rather than silent.

### `feats.prerequisite` is text nothing can check (noted 2026-08-19)

The column holds strings like "Strength 13 or higher" and "Proficiency with heavy
armor". `characters` stores a name, a campaign and an owner — no level, no class,
no ability scores, no proficiencies — so there is nothing to evaluate them
against, in the database or the client. Eleven of the forty-two seeded feats carry
one and any player can take any of them.

**Cost:** none as a bug; the app is a shared reference sheet, and the DM at the
table is the enforcement layer. It is written down because "prerequisite" is a
word that implies a check, and the next person to read the schema will look for
one.

**Fix:** nothing, unless characters grow stats. If they ever do, the honest
version is a warning beside the picker rather than a disabled option — a DM
waiving a prerequisite is a normal thing to do, and a hard block would be wrong.

### Feats can't be edited from the app, not even a DM's own homebrew (noted 2026-09-18)

039 ships SELECT and INSERT policies on `feats` and no UPDATE, so once a feat
exists nothing in the client can change it — not a typo in the description, not
its category. 052 recategorised five feats by running as the table owner in the
SQL editor, outside RLS, which is the only path today.

**Trigger:** a DM wanting to fix or recategorise a homebrew feat.

**Cost:** a trip to the SQL editor per correction. The same is true of shared
catalogue rows, and there it is correct: those should never be editable from
the client.

**Fix:** an UPDATE policy scoped like the INSERT one (`campaign_id is not null`
and DM of that campaign), plus an edit form. 052 is explicitly not a precedent
for skipping that and writing more owner-run migrations instead.

053 has since done exactly this for items, and it is the template: the policy,
a `pin_feat_row` trigger pinning `id`/`campaign_id`/`created_at`, an
`updateFeat` that treats "no row back" as a refusal, and CreateFeat's form
seeded from an `initial` feat the way `HomebrewItemForm` now is. Feats are
simpler than items, with no kind-dependent columns to null on a change.

### Picking a class is three requests, not one transaction (noted 2026-10-05)

`setStartingClass` updates (or inserts) the `character_classes` row, then
deletes the character's save proficiencies, then inserts the new class's two.
A failure between the steps leaves the class changed and the saves stale or
missing.

**Trigger:** a dropped connection mid-pick, or a refused write on the second
or third request.

**Cost:** wrong saving throw totals until the class is re-picked or the saves
are ticked by hand, both of which repair it. The error line on the sheet says
the save failed.

**Fix:** a `set_starting_class(character, class)` plpgsql function doing all
three in one transaction, security invoker so RLS stays the boundary.

### Classes, subclasses and races can't be created or edited from the app (noted 2026-10-05)

054 ships SELECT and INSERT policies on all three, so a DM is allowed to
create homebrew, but there is no form for it yet, and no UPDATE policy at all.
A homebrew class also needs its `subclass_title` set (066), or its picker
reads "Subclass". The shared subclasses are seeded (067-078, and Battle
Smith in 149), except three of the Artificer's (below).

**Fix:** a CreateFeat-style form; 053's homebrew-edit policy plus a pin
trigger for editing.

### Class features are mostly display only (noted 2026-10-11, widened by 081/082, 084-094 and 097-120, narrowed 2026-11-05 by 095 and 121, and 2026-11-07 by 159/160)

079-094 and 097-120 store and show the text for every class and subclass.
The sheet computes from two fighting styles and from the 24 rows that carry
a 121 `effect` key (two of them the Battle Smith's, 150; Brutal Critical's,
160); every other row is text. Since 159/160 one race and five feats carry a
key too (below).

- **Fighting style:** Defense (+1 AC while body armour is worn) and Archery
  (+2 to-hit on ranged weapons) are applied by `armorClass` and
  `styleAttackBonus` in `rules.ts`, for every pick the character holds. The rest
  stay manual, each for a reason. Dueling depends on what's in the other
  hand, and the sheet doesn't track hands. Thrown Weapon Fighting's +2
  applies only when the weapon is thrown, and the attack row shows one
  damage line per weapon. Great Weapon Fighting is a reroll, not a number.
  Protection, Interception, Blind Fighting, Superior Technique and Unarmed
  Fighting are reactions, senses or new attacks.
- **Archery misses the Dart.** `isRangedWeapon` says "has a range and isn't
  thrown", and the Dart is the one ranged weapon with the thrown property.
  Its columns are identical in shape to a dagger's (simple, finesse, thrown,
  20/60, 1d4), so nothing but the name tells them apart. Fix: a
  melee/ranged column on weapon items, or a `ranged` property on the Dart's
  row.
- **Computed since 121:** attacks per Attack action, crit range, Sneak
  Attack dice, Martial Arts (DEX and its die on monk weapons and unarmed
  strikes), Jack of All Trades and Remarkable Athlete on untrained skills,
  passives and initiative, Dread Ambusher, Tactical Wit and Rakish Audacity
  on initiative, Aura of Protection on saves, Fast Movement and Unarmored
  Movement on speed, Draconic Resilience's AC 13 + DEX, and Battle Ready's
  martial weapons and INT on a magic weapon (150; the INT half reaches
  seeded magic weapons since 163).
- **Computed since 160:** Brutal Critical's extra dice (in the attack
  legend), Warforged's Integrated Protection (+1 AC), Alert (+5
  initiative), Observant (+5 passive Perception and Investigation), Mobile
  (+10 ft), Tough (+2 HP per level, in the average-HP hint only) and Medium
  Armor Master (+3 DEX cap in medium armour). **Players who typed any of
  these in by hand are now double-counted** (Warforged's +1 in the AC bonus
  box most likely); 160's BLOCK 1 lists the Warforged ones. Decided
  2026-11-07 to tell them rather than zero the box in a migration.
- **Computed since 164-166 (races):** Dwarven Toughness (+1 HP per level,
  in the average-HP hint), Savage Attacks (in the attack legend, stacking
  with Brutal Critical), the Dwarf's full speed in heavy armour, a
  subrace's speed and darkvision, and racial skill, weapon and armour
  proficiencies. Skills and weapons that players added by hand before this
  are now granted twice; harmless, since the higher level wins, and the
  weapon extra stays removable. Racial score increases and choices are
  manual (ACCEPTED_ISSUES).
- **Shown, but the condition is the player's:** Sneak Attack still needs
  advantage or an ally beside the target; Aura of Protection needs the
  paladin conscious and within range; Dread Ambusher's first-turn extra
  attack isn't shown. Draconic Resilience's hit points appear only in the
  "Average for level" hint, because max HP is a number the player types.
- **The Dart counts as a monk weapon.** `isMonkWeapon` uses the same
  "thrown, so not ranged" test as Archery, so it accepts the Dart, which the
  PHB lists as a ranged weapon. The same fix as above corrects both.
- **Derived numbers nothing applies:** Rage's damage bonus and resistances
  (rage is a state the sheet doesn't track), Primal Champion's +4 (the
  player edits the scores), Slippery Mind and Diamond Soul's save
  proficiencies (the player can add those by hand), Potent Spellcasting and
  Agonizing Blast on cantrip damage (the sheet shows no cantrip damage),
  Extra Attack from an invocation (Thirsting Blade), Dual Wielder's +1 AC
  (the sheet doesn't track hands), and proficiencies a feat grants. A
  homebrew race, subrace or feat can carry a key on insert, but CreateFeat
  offers no effect picker and races have no form.
- **Uses the counters don't cover:** 153-157 track every feature and feat
  whose text says it recharges on a rest, with these exceptions. The Rune
  Knight's runes want one counter per rune picked (each is once per short
  rest, twice from 15th), not one counter per feature row. Infusions don't
  record which items hold them. Rage's unlimited uses at 20th hide its
  counter rather than showing "unlimited". Signature Spells is one counter
  of 2, not one per spell. Spell-Storing Item's floor is 1, where the book
  says 2. 155 and 156's headers list the rest-related text deliberately left
  uncounted (Divine Intervention, Hex Warrior, Limited Wish...).

**Trigger:** any feature whose effect is a number the sheet derives or a use
that recharges on a rest.

**Cost:** the player adds the remaining bonuses and counts the uses in their
head.

**Fix:** use tracking wants a `character_feature_uses` table, or
counters on the class entry, plus a short/long rest action; that is a design
of its own.

### Spellcasting has no school model, and slots are single-class (noted 2026-10-13, widened by 084-094, narrowed 2026-11-07 by 158)

158 gave classes and subclasses a `caster_type`, and the sheet derives slots
from it (`spellSlots` / `pactSlots` in `rules.ts`): full, half, Artificer
and third casters, and the Warlock's Pact Magic on short rests. Each slot
level is a counter in the Resources band. What's still missing: prepared and
known counts aren't checked, and the spell picker offers every spell.
Domain, oath, circle and patron spells are listed in their rows' text and
nothing marks them always prepared. The Eldritch Knight (082) and Arcane
Trickster (091) both have a school restriction nobody enforces. Slots come
from the starting class only (see "Use counters and rests").

**Fix:** a school filter in the picker driven by the subclass, and the
PHB multiclass slot table in `rules.ts` once multiclassing is on the sheet.

### Many-pick features without a picker yet (noted 2026-10-11, widened by 082 and 084-094, narrowed 2026-11-05 by 095 and 122)

122 added the machinery: `class_feature_picks` says how many picks a
feature allows per class level, and the sheet shows a checklist picker for
any feature with linked options and steps. Battle Master maneuvers (122),
Metamagic (123), Arcane Shots (124), runes (125), Eldritch Invocations
(126) and Artificer infusions (151) are on it, Tasha's options included and
labelled. Every other such pick is still
text the player notes by hand, with the options listed in the row: Expertise (Bard, Rogue),
Magical Secrets, Favored Enemy and Natural Explorer, the Hunter's four
picks, Totem animals (three picks, which can differ), the Circle of the
Land's terrain, the Four Elements disciplines, Dragon Ancestor, Pact Boon,
Mystic Arcanum and the Kensei's weapons (107).

The pickers' prerequisites are display only: nothing stops a 2nd-level
warlock picking Witch Sight, or a Rune Knight taking Storm before 7th
level. Enforcing them would need the pact boon to be a pick first, and a
structured prerequisite instead of text.

Some single picks are also noted by hand, because each one would need a new
`feature_options` kind: Storm Aura's environment and Divine Fury's damage
type (097), Divine Magic's affinity (115), the Genie's kind (118), and the
bonus skill, tool, save or language several subclasses grant. Those are the
cheapest next pickers: one row per feature, which 095 already supports.

**Fix:** per list, one migration: a new `feature_options` kind (shipped to
the client first), its options in our own words, the links, and the
feature's steps. Pact Boon and Dragon Ancestor are single picks and the
cheapest next ones. Expertise and skill picks
want to write `character_proficiencies` instead, and Favored Enemy's
humanoid races want the old branch's free-text `detail` column.

**Not linkable:** the Superior Technique fighting style and the Martial
Adept feat each teach a maneuver, but neither is a `class_features` row, so
the player notes that maneuver by hand.

**The remote branch `feat/feature-choices` is superseded, not rebased.** It
was written against 082. Its files are numbered 083/084, numbers the live
database has since used for other migrations. It replaces a column without
knowing about 083's `class_features.fighting_style_options`, and its header
says "RUN 082 FIRST". 095/096 rebuild its design against the current schema,
without its `class_feature_picks` table and `detail` column (122 brought its picks table back). The remote
branch is kept on purpose (decided 2026-11-05), as the reference for those
two pieces when many-pick features arrive.

### Tasha's optional class features are unseeded (noted 2026-10-20)

097-120 seeded every Xanathar's and Tasha's subclass's features, but not
Tasha's optional base-class features (Primal Knowledge, Deft Explorer,
Harness Divine Power, Martial Versatility and the rest). They are optional
by the book: the DM decides whether the table uses them, so seeding them
into every campaign's shared catalogue would be a rules call made in a
migration.

**Fix:** decide first whether this table uses them. If it does, either seed
them as shared base-class rows (every campaign gets them), or as one
campaign's homebrew rows (only this campaign does). The second keeps the
optional rule optional.

### The demo characters start with default stats (noted 2026-10-05)

`demo_campaign_reset.sql` predates 056. Its characters still get a stats row
(the trigger fires for the fixture's insert too), but with every score 10, 1
HP and no class, so the demo sheet looks empty.

**Fix:** extend the fixture with an UPDATE of `character_stats` and inserts
into `character_classes`, after its characters insert.

### Magic templates and armour are text; nothing counts attunement (noted 2026-11-05, narrowed 2026-11-07 by 161-163)

161 gave items `magic_bonus` and `base_weapon_id`, and 163 turned the 15
seeded magic weapons with one named base (Dagger of Venom, Sun Blade...) into
weapon rows, so those reach the attack table with their bonus. What's left:

- **"Any weapon" templates stay text.** Weapon +1/+2/+3, Flame Tongue, Vorpal
  Sword and the other "any sword" items are `kind = 'general'`, because the
  book leaves the weapon to the DM. A character holding the shop's
  "Weapon, +1" gets nothing on the sheet. The DM makes the concrete one as
  homebrew (Base weapon + Bonus in the item form) and gives that instead.
- **Magic armour adds no AC.** 161's `magic_bonus` allows armour, but the
  form doesn't offer it and `armorClass` doesn't read it; Armor +1 and the
  rest are still general text.
- **Ammunition bonuses** (+1 Ammunition) aren't applied: the attack table has
  no ammunition row.
- **Attunement:** `requires_attunement` is shown, but nothing caps a
  character at three attuned items, and nothing records which are attuned.

**Trigger:** a player buying "Weapon, +1" from the shop; wearing magic armour.

**Cost:** the player adds the bonus in their head, as with features (above).

**Fix:** for templates, a "make it a..." action on the item that creates the
homebrew copy with a base picked. For armour, the form field plus one line in
`armorClass`. Attunement wants an `attuned` boolean on `character_inventory`,
057's `equipped` shape.

### The 81 original spells read differently from the other 394 (noted 2026-11-06)

023/024 wrote near-verbatim book text with the upcast rule inside
`description`, and never filled `material_component` or `higher_levels`.
139-146 write own-words summaries, upcasting in `higher_levels` and every
material component. 138 repaired the old rows' levels, components and class
lists, and wrote the material component on the 36 rows it touched, but left
their text alone. So 26 old rows still show "M" with no component (counted
live 2026-11-06), and none of the 81 has an "At Higher Levels" block.

**Trigger:** opening, say, Fireball beside Chain Lightning in the grimoire.

**Cost:** cosmetic; nothing is missing, just in a different place.

**Fix:** a backfill in 138's shape: a temp table of (name, material_component,
higher_levels, description) for the 81 rows, an update, and an assertion.

### Three Artificer specialists are unseeded (noted 2026-11-07)

149 seeds the Artificer with Battle Smith only. Alchemist, Armorer and
Artillerist aren't in the catalogue, so the "Artificer Specialist" picker
offers one choice.

**Trigger:** a player wanting one of the other three.

**Cost:** none until then. A DM could add one as homebrew, but there is no
form for it (above).

**Fix:** one migration per specialist, or one for all three: a subclass
insert in 149's shape (bump its end-state count), plus feature rows in 098's
shape (subclass rows only; 150 already holds the base rows). Each has a
spell list row at 3rd and features at 3, 5, 9 and 15. The Armorer's Arcane
Armor and the Artillerist's Eldritch Cannon would be text; the cannon
could instead be a second `character_companions` kind (167), the steel
defender's shape. Alchemist and Artillerist would need no new effect key; the
Armorer's model choice (Guardian or Infiltrator) is a single pick, a new
`feature_options` kind.

### Replicate Magic Item can be learned only once (noted 2026-11-07)

The book lets an artificer take Replicate Magic Item more than once, a
different item each time. `character_feature_choices` is
`unique (character_id, option_id)` (095), so the picker allows it once.

**Trigger:** an artificer wanting two replicated items.

**Cost:** the second item is noted by hand.

**Fix:** a nullable `detail` on the pick naming the item (the free-text
column `feat/feature-choices` had), with the unique widened to include it
for this option. Not worth it for one infusion.

### 152's Artificer spell list was written from memory (noted 2026-11-07)

Like 147, the 95 names in 152 were written from memory of TCoE's table.
The guard proves each is a real shared spell, not that it belongs on the
list.

**Trigger:** a player asking why a spell is or isn't on the artificer list.

**Cost:** one wrong line on a detail card; the sheet doesn't gate spells by
class.

**Fix:** check against TCoE's Artificer spell list, then `array_remove` or
add the difference in a follow-up migration.

### 147's TCoE expanded spell lists were written from memory (noted 2026-11-06)

The 63 (spell, class) pairs in 147 were not copied from the book. The
likeliest slips are named in its header: Sorcerer's Flame Blade and the
8th/9th rows.

**Trigger:** a player asking why a spell is or isn't on their list.

**Cost:** one wrong line on a detail card; the sheet doesn't gate spells by
class.

**Fix:** check the 63 pairs against TCoE's "Expanded Spell Lists" tables,
then add or `array_remove` the difference in a follow-up migration.

### EditItem forgets where it came from on a refresh (noted 2026-09-30)

The Edit link passes the page it was pressed on as router state, and EditItem
returns there after Save or Cancel. Router state lives in the history entry, so
a refresh or a pasted link loses it and both buttons fall back to the Shop.

**Cost:** one extra click back to the hoard, rarely.

**Fix:** a `?from=` search param instead of state, if it ever annoys anyone.

### `CharacterFeatRow` asserts the embedded feat is non-null (noted 2026-08-19)

The spells version of this entry is above, and is currently unreachable. This one
is not. `CHARACTER_FEATS_SELECT` is `"*, feats(*)"` with the row type declaring
`feats: Tables<"feats">`, and 039 ships a working INSERT policy — so a DM who
belongs to two campaigns can create a homebrew feat in campaign B and attach it to
a character in campaign A, where 039's SELECT policy filters the embed to null and
`toCharacterFeatEntry` calls `toFeat(null)` and throws a TypeError. 041's BLOCK 6
demonstrates exactly this rather than asserting it away.

**Trigger:** a hand-made request. The UI cannot produce it — the picker is fed by
`getFeats(campaignId)`, which is already scoped to shared-plus-this-campaign — so
reaching it means calling PostgREST directly with a feat id from elsewhere.

**Cost:** one character's Feats panel throws instead of rendering, for everyone
who can see that character, until the row is deleted in the SQL editor. Not a
leak: the feat's contents stay invisible, which is what makes the embed null in
the first place.

**Fix:** the composite-FK answer the spells entry prefers does not work here —
shared feats have a null `campaign_id` and would match nothing — so it is either a
BEFORE INSERT trigger re-deriving the character's campaign and rejecting a
mismatch, or making the embed nullable in the type and dropping the row from the
list. The trigger is the right one; the type change is a two-line stopgap.

### `getCharacterFeats` returns rows in no particular order (noted 2026-08-19)

The same gap as `getCharacterSpells` above, made the same way: no `.order()`, no
post-sort, correct only because every consumer pipes it through
`featsByCategory`, which sorts. Copied knowingly, so it is copied here too rather
than left for someone to find twice.

**Fix:** whatever is decided for the spells version, applied to both in one edit.

### `removeFeatFromCharacter` treats a refused delete as success (noted 2026-08-19)

`removeSpellFromCharacter`'s entry above, one table over and with the same
justification and the same dependency on it: the remove control renders on your
own sheet and nowhere else, so nobody who can press it can be refused. The Party
panel is the trigger for both.

**Fix:** whichever way the spells one goes.

### `useCharacterFeats` invalidates only its own key (noted 2026-08-19)

`["characterFeats", characterId]` and nothing else, matching `useCharacterSpells`.
Today that is complete, because the Feats panel on the sheet is the only thing
that reads character feats. The Party page's `TeachForm` had to invalidate
`["party", campaignId]` by hand for exactly this reason, and a feats embed in
`PARTY_SELECT` would need the same hand-written second invalidation.

**Trigger:** the Party page coming back (its route and nav link are commented out
as of `6b7dee5`) with feats added to its embed.

**Fix:** the same one the spells entry wants — a mutation that invalidates both
keys, or a shared invalidator that knows a character belongs to a campaign.

### Player preview is a per-page discipline with nothing enforcing it (noted 2026-08-19)

Preview is two independent opt-ins that every page has to remember separately:
`asPlayer: previewing` on each reveal-gated read, and `showDmUi` in place of
`campaign.isDm` on each DM control. Nothing checks that a page did either. A new
page is preview-blind by default, and a preview-blind page looks completely
normal — the leak is only visible to someone who knows what the row should have
said.

That is how three of them accumulated on Home.tsx, the page a DM lands on
straight after toggling: an unfiltered `useLocations` drawing a pin at the true
coordinates of every unrevealed location, a "Roads Known" count reading 4 / 17
where a player sees 4 / 4, and a band captioned "For the DM's eyes only" still
standing in player view. All three fixed 2026-08-19, along with the same gate on
Inventory's forge link, Recaps' New-recap form and Delete, and Party's Give and
Teach footers.

**Trigger:** adding a page, or adding a reveal-gated read to an existing one.

**Cost:** the mode exists to be trusted. A DM who has checked the dashboard in
preview and found it clean has been told something false about their table.

**Fix:** the two halves want different answers. The reads could stop being
opt-in — a `useRevealGated` wrapper, or the preview flag moving into the query
layer — but the hooks deliberately take `asPlayer` as an argument rather than
reading the context, so that they stay data and work outside the provider, and
that is worth keeping. The controls are the more tractable half: `showDmUi` is
recomputed identically in six files now, and belongs on the campaign context
beside `isDm` where a page gets it without knowing to ask.

Note the coupling, which is what makes this worse than a checklist item: fixing
only the read half is a **regression**, not a partial fix. Home's DM band counts
`hidden` and `annotated` off the location list, so filtering the list without
also hiding the band leaves it confidently reporting "Every road revealed" while
ten locations are hidden. Any page doing both must change both in one edit.

### `asPlayerView` cannot filter a field that came from another table (noted 2026-08-19)

`asPlayerView` filters `isRevealed` and strips `dmNotes` — both fields of the row
it is given. `Npc.locationName` is neither: it is denormalised out of
`locations ( name )` in NPC_SELECT, so it answers to **locations'** RLS, not
npcs'. A player's copy of an NPC standing somewhere unrevealed arrives with
`locations: null`; a previewing DM's still carried the name until 2026-08-19.

Fixed by `hideUnseenLocationNames` in `lib/playerView.ts`, called from NPC.tsx
because that page is the only place the NPC list and the previewed location list
meet.

**Trigger:** any future embed of a reveal-gated table into a differently-gated
one. The pattern to watch for is a field whose null-ness is decided by a policy
on a table other than the row's own.

**Cost:** currently zero — the one case is fixed. Recorded because the general
shape is invisible: nothing about `locationName: string | null` says the null is
load-bearing, and `Npc`'s own comment describing it ("the home is a location this
viewer cannot see") was already correct while the preview path quietly wasn't.

### Lists sort on the catalogue name while the row shows the custom one (noted 2026-08-22)

`spellsByLevel` groups and sorts on `entry.name`, and `CharacterCarried`'s "first
four" sorts the same way, but both now print `customName ?? name`. So a player
who renames Fireball to "Grandmother's Hearth" finds it filed under F.

**Why it's like this:** `spellsByLevel` is generic and shared with the grimoire,
where there is no custom name to sort by, so threading a display-name comparator
through it would push the feature into a function that has nothing to do with it.
The row prints the catalogue name beside the custom one, so the ordering is at
least explicable on sight rather than arbitrary.

**Cost:** mild confusion on a list long enough to scan. A sheet holds a dozen
spells.

**Fix:** an optional comparator argument on `spellsByLevel`, defaulted to the
current one. Cheap, just not yet earned.

⚠ The "the row prints the catalogue name beside the custom one" half of that
justification is not true of `CharacterCarried`, which is the other half of this
entry's own example. See "`CharacterCarried` shows the DM only the names a player
invented" below.

### The pickers and the grimoire show only catalogue names (noted 2026-08-22)

The "Choose a spell…" and "Choose an item…" selects are fed by `getSpells` /
`getItems` — the shared catalogue, which has no character and therefore no
override. So a player who renamed something and wants to add another one has to
remember what the book calls it.

**Cost:** near zero. Adding a second of something you already carry goes through
the pack's own `+`-shaped paths, not the picker, and the picker is where you go
for things you don't have yet.

**Fix:** the pickers would have to merge the character's override map over the
catalogue list. Doable in the page; not worth the coupling for the case it
serves.

### The DM cannot write item descriptions, only spell ones (noted 2026-08-22)

046 and 047 both gate writes on `can_edit_character`, so the campaign's DM may
write either. But the only door to an item's description is the pack's inspect
card on `Inventory.tsx`, and that page is always "mine" — there is no path onto
another character's pack from it. Spells are fine: `CharacterDetail` renders the
same `CharacterSheet` for a DM, spell card included.

**Trigger:** a DM wanting to hand out a magic item that arrives already carrying
its story.

**Cost:** the DM types it in chat instead. `GiveItemForm` on the character sheet
can already put the item in the pack; only the words are missing.

**Fix:** an inspect card on `CharacterCarried`, which is today deliberately a
summary strip and a link. That is a real design change to that band, not a
plumbing job — the RLS half already permits it.

⚠ Do not build that door before reading the next entry. Opening it makes the
authorship problem live for gear as well as spells, and the two changes touch
the same component.

### The DM's writing is labelled as the player's, and Clear destroys it (noted 2026-08-22)

046 and 047 both widen the write to the campaign's DM, and both headers name the
reason: so a cursed blade can arrive already carrying its story. Through
`CharacterDetail` → `CharacterSheet` → `CharacterSpells`, where
`canEdit = isOwn || campaign.isDm`, that door is open today for spells.

`CustomDescriptionBlock` has no concept of a second author. It labels the text
**"Your telling"** and the editor labels its field **"What you call it"**,
whoever wrote them. So a player opens a spell the DM annotated, finds prose they
do not remember writing under a heading claiming they did, and the Clear button
— "Go back to the book's own words for this spell?" — deletes it outright, with
no trace and no signal back to the DM. Saving does the same thing more quietly:
the editor seeds its draft from the stored row, so a player opening it to adjust
a rename carries the DM's paragraph forward as their own, or drops it if they
clear the field first.

Both tables record `updated_at` and nothing else. There is no `written_by`, so
a DM who suspected has nothing to check.

**Trigger:** the DM writing flavour onto a player's spell — the exact use the
widening exists for. Gear is safe only by accident, via the missing door in the
entry above.

**Cost:** currently zero, because nobody has used the DM path yet. The day it is
used it is a table argument rather than a bug report: prose written for a player
is gone and the two people involved have different accounts of what was on the
card.

**Fix:** the honest version is a column —
`author_id uuid not null default auth.uid()`, named in both pin triggers
alongside the key columns (they are blocklists; see above), denormalised onto the
entry the way `addedByName` already is, and the label branching on it. Clear
should then confirm differently when the words are someone else's. The cheap
interim is presentational only: the block already knows text exists, it just does
not know whose.

### `CharacterCarried` shows the DM only the names a player invented (noted 2026-08-22)

The strip prints `entry.customName ?? entry.name` with no alias beside it, unlike
`PackRow` (`.inv-alias`) and `SpellRow` (`.ch-spell-alias`), which both print the
catalogue name in small type for the stated reason: hiding it takes the rules'
own word away from the DM reading over a player's shoulder. This is the one
surface where that DM is the _only_ reader, and it is the one surface that drops
it.

It compounds with the sort — see "Lists sort on the catalogue name" above. The
"first four" are chosen by sorting on `entry.name`, so a DM looking at a renamed
pack gets four invented words ordered by a key that is not on screen, with no
inspect card on the band to resolve any of them.

**Trigger:** a DM opening a player's sheet from `CharacterRoster` when that
player has renamed anything.

**Cost:** the DM's only view of a player's gear becomes unreadable in exactly the
moment it is wanted — mid-session, checking whether someone is carrying rope.

**Fix:** the band is tight on space, so an alias per name is wrong. Either
`title={entry.name}` on each, or the parenthetical form for renamed entries only
(`Grandmother's Hearth (Fireball)`), which costs width only where something was
actually renamed. Both are a line. Superseded if the inspect card from the
DM-cannot-write entry ever lands on this band.

### Destructive confirms and the remove `aria-label` name the catalogue item (noted 2026-08-22)

`PackRow.handleRemove` and `SpellRow.handleRemove` both build their confirm from
`entry.name`, and `SpellRow`'s Remove button carries
``aria-label={`Remove ${entry.name} from this character`}``. The row above them
displays `customName ?? name`. So the row reads "Ireena's Braid" and the confirm
asks about Rope.

The `aria-label` is the unambiguous half: a screen reader announces the row's
inspect button under the custom name and its Remove button under a different
one, which reads as a control belonging to some other row.

**Trigger:** removing anything that has been renamed.

**Cost:** small and briefly confusing in the visual case. Larger for a
screen-reader user, who has no visible row to reconcile the two names against.

**Fix:** `customName ?? name` in the `aria-label` unconditionally — it exists to
name what is on screen. The confirm is a judgement call rather than an obvious
swap, since it is the one place the catalogue name is arguably the safer thing to
say; if both are wanted, say both rather than picking the one the user did not
click. `HoardRow`'s confirm is correct as it stands — the hoard has no overrides.

### `customName ?? name` is resolved in five places with three alias treatments (noted 2026-08-22)

The display rule lives in `PackRow` (name + `.inv-alias`), `SpellRow` (name +
`.ch-spell-alias`), `CharacterCarried` (name, no alias), and `ItemDetailCard` /
`SpellDetailCard` (name + `.detail-alias`). `useSearchBar` matches on both names;
`spellsByLevel` and the "first four" sort on neither of the displayed ones.

This is the argument already made for `customDescription.css` owning its own
stylesheet — two places to keep in step is one too many — not applied to the
thing that stylesheet is about. The `CharacterCarried` entry above is what the
drift looks like in practice: it is not a considered exception, it is the file
that was written last.

**Trigger:** any new surface showing a character's gear or spells. It will pick
one of the four by copying whichever file was open.

**Cost:** nothing functional. What it costs is that "how a renamed thing is
displayed" is an emergent property of six files rather than a decision anywhere.

**Fix:** a small `<SubjectName entry={…} variant="row" | "compact" />` in
`components/`, beside `CustomDescription.tsx`, owning the three variants and the
`.detail-alias` / `.inv-alias` / `.ch-spell-alias` split. A bare
`displayName(entry)` helper is not enough — the disagreement is about the alias,
not the primary. Sorting stays on the catalogue name and stays documented as
such; that part is a deliberate call, not drift.

### `035_npc_desc_fix.sql` has no header comment (noted 2026-08-17)

Two bare lines of SQL. Every other file in `db/` opens with a paragraph
explaining what it does and why, and that convention is load-bearing for more
than readability: a file with no prose is effectively unsearchable, which is how
a review of migrations 034–037 managed to conclude the file wasn't committed at
all.

**Fix:** three lines at the top saying what it cleans and that it is idempotent.

---

## Minor

Small, understood, not worth an entry of their own.

- **`formatPrice` deferred.** Prices are integer copper and display as
  `price_cp / 100`, so sub-gold items render as "0.01 gold". More visible since
  the general-item seed added many sub-gold entries.
- **Dead campaign uuid in old migrations.** `00000000-…-0001` (015, 005)
  references a campaign that does not exist in this database. It misled the NPC
  seed work once already. 026 reseeded locations campaign-scoped; the literal
  survives in the older files.
- **Which uuid is the live campaign isn't recorded.** 033 onward hardcode
  `d721b412-…` (the campaign those files call "The cool kids"); 050 and 051
  resolve "Not Curse of Strahd" by name instead because nothing says whether
  those are the same row. One `select id, name from campaigns` would settle it.
- **`public/portraits/strahd.png` is dead.** The old hardcoded path; `NPC.tsx`
  reads only `src/assets/portraits/` now, and 049 shipped the real Strahd there.
  Delete it — an unreferenced file at a formerly load-bearing path misleads the
  next grep.
- **Double `console.error` on a failed NPC save.** `updateNpc` logs the Supabase
  error and `NpcEditor`'s catch logs again. One failure, two entries. The same
  pattern is now in `characterSpells.ts` and its callers.
- **A player attempting `update npc_dm_notes` is untested.** Covered by
  inspection rather than execution: block 9 of the verification shows its USING
  and WITH CHECK are the same `is_campaign_dm` expression that block 8 proves
  refuses a player on INSERT.
- **Comment cleanup backlog.** AI-assisted sessions left comments that narrate
  edit history and cite migration numbers ("013 changed…", "007's trigger…")
  rather than explaining the code in front of the reader. Per-file with review,
  not one agentic sweep.
- **`characters.ts` casts `data as PartyCharacterRow[]`.** The only hand-written
  row shape left; `PARTY_SELECT`'s three embeds defeat inference. Contained to
  one line, and the type next to it is honest about what it's asserting.
- **An override row needs no ownership of the item.**
  `character_item_descriptions` has no FK to `character_inventory` and its
  policies ask only `can_edit_character`, so a hand-written request can write a
  description for an item the character has never held. Unreachable from the UI
  — the card only opens from a pack row — and it is the same property that makes
  the orphan-row behaviour in "Description rows outlive the gear they describe" (`ACCEPTED_ISSUES.md`)
  work, so it is arguably load-bearing rather than a hole. Recorded because the
  table reads like it is scoped to a pack and is not.
- **Concurrent demo visitors share one character.** GoTrue is happy to issue
  many simultaneous sessions for one account, so the link works for any number
  of people at once — but they all own the same sheet, so two of them editing it
  overwrite each other, and TanStack's cache means neither sees the other until
  a refetch. Fine for a demo; worth knowing before it reads as a sync bug.
- **The demo credentials live in two places.** `.env` covers `npm run dev`; the
  deployed build reads its own copy from the Cloudflare Pages dashboard, where
  build config lives. Set in neither, `/demo` renders its named
  missing-variables screen rather than failing silently — but a build that has
  only one of the two is the case that looks like a code bug.
- **`CustomDescriptionBlock`'s `custom` prop is typed `CustomDescription | null`
  and never receives null.** Both callers pass the entry itself (`custom={panel}`),
  which always has the two keys. The null branch in `hasCustom` is dead. Harmless
  — the prop is honest about the shape it needs — but the `?.` chains inside read
  as if absence were reachable.


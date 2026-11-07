# Accepted issues

Things that are wrong on purpose: understood, judged not worth fixing at this
size, and written down so they stay decisions rather than becoming discoveries.
Each entry says what it takes to trigger, what it costs, and what would make the
answer change.

An entry belongs here when its fix is conditional ("if the answer changes",
"if it ever matters") or the entry says it was accepted or decided. If the
answer does change, move the entry back to `KNOWN_ISSUES.md` as open work.

---

### Racial ability score increases and racial choices are added by hand (noted 2026-11-07)

Since 164/165 the sheet applies a race's and subrace's traits by itself:
speed, darkvision, skill, weapon and armour proficiencies, languages,
resistances, the Racial Traits list, use counters (Breath Weapon, Relentless
Endurance, Drow Magic, Infernal Legacy) and four effect keys (Integrated
Protection, Dwarven Toughness, Savage Attacks, and the Dwarf's heavy-armour
speed). Two things it leaves to the player on purpose:

- **Ability score increases (the "+2 DEX").** The sheet takes final scores
  (055), so a racial bonus is part of the number the player types. Storing
  base scores plus the increase would mean a second set of six columns,
  every score derived, and a race change rewriting someone's stats.
- **Every choice a race offers.** Half-Elf's two skills, the Dwarf's tool,
  a High Elf's wizard cantrip, Dragonborn ancestry (and so its resistance
  and breath damage type), Warforged's Specialized Design, and the extra
  language of Humans, Half-Elves, High Elves and Warforged. The trait text
  says what to pick; the player sets it with the ordinary controls (a skill
  pip, a weapon extra, the Spells section). Innate cantrips (Thaumaturgy,
  Dancing Lights, Minor Illusion) are trait text too, not spell-list rows.

Also not seeded: Variant Human (an optional rule whose feat and skill are
both choices) and every non-PHB race but Warforged.

**Trigger:** any new character, at creation.

**Cost:** a few typed numbers and clicks once per character. A forgotten
+2 shows as a wrong modifier, which the player notices the first time they
roll.

**What would change the answer:** a character-creation flow that starts
from base scores (point buy or rolled), at which point the increase is one
more input. For the choices, extending 095's pickers to races: the picks
table is keyed to a class entry today, so it would need a second parent.

---

### The demo account can rewrite its own sheet, and the reset is the only undo (noted 2026-08-31)

The public `/demo` login is a shared `'player'` seat, and a player's ordinary
permissions are the whole of what it has: it can rename its character, add and
drop its own gear, spend its own purse, edit any recap in the campaign, and
rename itself through `set_display_name`. It can also delete its character
outright (`owner deletes own character` is `user_id = auth.uid()`) and make a new
one under any name — `unique (campaign_id, user_id)` only stops two existing at
once, so "the demo account has exactly one character" is true at reset time and
not between resets.

Accepted, not a bug. A `viewer` role and a `campaigns.frozen` column were both
considered and rejected: either adds a branch to every policy in the app to
serve one account.

**Trigger:** anyone following the link doing anything at all.

**Cost:** the demo looks like whatever the last visitor left. Bounded to one
campaign — `read campaigns you can see` (018) is pure membership and this account
has exactly one row — and bounded away from anything structural, since
`is_campaign_dm` is false for it: it cannot rename or delete the campaign, touch
the roster, reveal a location or map, or read a DM note. What it cannot do is the
part worth knowing: it also cannot remove itself, because `campaign_members` has
only `dm manages memberships` (ALL, gated `is_campaign_dm`) and `members read own
memberships` (SELECT). There is no player-facing DELETE, so the link cannot be
broken from inside. That is what makes an unattended public link survivable.

**Fix if the answer changes:** re-run `db/fixtures/demo_campaign_reset.sql`. It
is delete-then-insert precisely so a rename and a junk stack go away rather than
being topped up around.

### The demo reset does not restore the party hoard or purse (noted 2026-08-31)

`demo_campaign_reset.sql` scopes its delete to characters (and, by cascade, their
inventory, spells, feats and descriptions) plus the recap rows.
`party_inventory` and `party_currency` are outside it. Both are
`is_campaign_member` for read **and** write — that is 045's stated design, "the
DM can add to the party's pool" being no special case because the DM is a member
— so a demo visitor can add to and spend from both, and nothing puts them back.

**Trigger:** a visitor using the Inventory page's party half, or the party purse.

**Cost:** the one drift in the demo that accumulates. Small in practice, because
the hoard starts at a single row and there is nothing to buy, but it is the one
place where "re-running the seed is the recovery path" is not currently true.

**Fix if the answer changes:** two more deletes scoped to the same
`campaign_id`, and a seeded hoard and purse in the fixture's cast section. About
eight lines, and the file's header names the gap so it is findable from there.

### An invite posted beside the demo link would let it out of its campaign (noted 2026-08-31)

The demo account's containment is entirely its single `campaign_members` row.
`claim_player_invite` is security-definer and its whole job is to add one — it
works for a caller who cannot read the invite row, by design, because an invitee
is by definition not yet a member of anything. So a demo visitor holding any
valid player-invite code can join whatever campaign it belongs to, with a real
seat.

**Trigger:** posting a player invite in the same place as the demo link. Not
hypothetical if that Discord is also where players get recruited.

**Cost:** potentially a real campaign, with a stranger in it who can edit recaps
and read every revealed location. Nothing else in the app makes this reachable —
`dm_invites` is unreadable to a non-DM, `generate_player_invite` needs
`is_campaign_dm`, and codes are bare uuids nobody can guess.

**Fix if the answer changes:** hand player invites out privately rather than in
the channel carrying the demo link. Nothing in the schema needs changing, and
narrowing `claim_player_invite` would break the invitee case it exists for.

### Currency denominations don't auto-convert (noted 2026-08-20)

045 gives a purse five separate integer columns — copper, silver, electrum,
gold, platinum — and `adjust_character_currency`/`adjust_party_currency` each
touch exactly one. There is no "break a gold piece into 10 silver" operation
anywhere: spending 100 cp when a purse holds only gold pieces means manually
adding copper (or converting by hand) before the spend can succeed, because
the copper column's own floor check refuses to go negative even though the
purse's total value would cover it.

**Trigger:** any spend that mismatches the denomination actually held. Common
at the table — loot rarely arrives in the exact coins a price is written in.

**Cost:** low and mostly friction, not data loss — the refusal is a clean
"not enough of that denomination", not a crash, and nothing stops a player or
the DM from doing the conversion by hand with two Add/Spend calls. What it
costs is convenience: nothing in the app currently prices anything to spend
_against_, so it hasn't bitten yet, but it will the day a shop or a service
charge is priced in gold and a party is holding platinum.

**Fix if the answer changes:** a `convert_currency` RPC taking a purse target,
a source denomination, an amount, and a target denomination, doing the spend
and the add as one transaction at fixed 5e rates (1 sp = 10 cp, 1 ep = 5 sp,
1 gp = 2 ep, 1 pp = 10 gp). Not hard, just not written yet.

### `locations` has no `campaign_id`-pinning trigger (noted 2026-08-12)

`session_recaps`, `characters` and `npcs` all carry a BEFORE-UPDATE trigger that
pins `campaign_id` to its old value. `locations` does not. Both clauses of "dms
update locations" pass for a DM who runs two campaigns, so that DM can move a
location from one campaign into the other with an ordinary update.

**Trigger:** being the DM of two campaigns and sending an update that names
`campaign_id`. Nothing in the UI does this — `updateLocationDescription` and
`updateLocationVisibility` send one column each — so it needs a hand-written
request or a client bug.

**Cost:** low, and this is not a privilege hole. Only a DM of _both_ campaigns
can do it, and reassigning a location is a DM action either way; a
single-campaign DM still cannot move a location out. What it costs is
consistency — this is the one content table where the "pin the immutable facts"
rule isn't enforced, and the exception is invisible until someone goes looking.

**Fix if the answer changes:** the same trigger shape recaps uses. Four lines,
plus a `create trigger`.

`locations.map_key` (042) is unpinned the same way and for the same reason —
042 gave the table no BEFORE-UPDATE trigger of its own, so a two-campaign DM
can also move a location's map assignment cross-campaign with an ordinary
update. Same cost, same fix, one trigger doing both jobs if it's ever added.

### Maps have no RLS boundary — the reveal flag does, the image does not (noted 2026-08-20)

042 added multi-map support: `campaign_map_reveals` gates whether a campaign
has revealed a given map, and that table is real, RLS-protected data — a
player cannot flip or forge it. What it gates is not protected by anything.
`src/data/maps.ts` is a plain module compiled into the JS bundle every
authenticated user downloads, images included by reference; `MapView.tsx`'s
`mapsAsPlayer` flag is the only thing standing between a hidden map and a
player's screen, and it is a client-side `if`, not a database policy. Every
other reveal-gated thing in this app (locations, NPCs, their DM notes) is
hidden by RLS before it ever leaves Postgres; this is the first feature where
that is not true.

**Trigger:** none needed for the flag itself — `is_campaign_member`/
`is_campaign_dm` on `campaign_map_reveals` are exactly as solid as every other
policy in this app (042's verification blocks 2 and 3 cover the read and the
write). The gap is reaching the image directly: devtools, a saved page, or
simply reading `src/data/maps.ts` in the deployed bundle.

**Cost:** a picture. Concretely narrower than it sounds, for two reasons
worth keeping rather than hand-waving away: Vite emits each map as a separate
hashed asset referenced by URL, so the bytes are not inlined into the parsed
JS and nothing on a player's screen requests them unless `MapView` actually
renders an `<img>` for that map — reachable, not served. And every pin on
every map stays fully RLS-gated regardless: an unrevealed location's
existence, description and DM notes never leave the database for a real
player, on any map. What could leak is the map art; the DM's actual secrets
about it do not.

Accepted at this size — the threat model is a player glancing at a map on
screen before the DM means them to, not someone deliberately dumping the
bundle, and these are published Curse of Strahd images findable in five
seconds regardless.

**Related gap, same entry:** `Home.tsx`'s dashboard thumbnail always renders
`REGION_MAP.image` unconditionally — it never checks that map's own reveal
flag. Today `REGION_MAP.defaultRevealed` is `true` and realistically stays
that way, so this is currently theoretical, but it means hiding the region
map would not actually remove it from a player's dashboard. Left alone rather
than gated, on the same "not worth it for a picture" reasoning above.

**Fix if the answer changes:** move map images into a Supabase Storage bucket
behind signed URLs, with a storage policy joining `campaign_map_reveals` and
`is_campaign_member` — the real boundary, turning `MapDef.image` into an async
fetch. A day of work and a new failure mode (expiring URLs) to protect a
picture; worth it only if the calculus above changes. If it's ever done, fix
the Home thumbnail gap in the same change rather than leaving it as a second
trip through this reasoning.

### The pin triggers are blocklists, so new columns are writable by default (noted 2026-08-14)

`pin_npc_row`, `pin_character_row` and `stamp_session_recap` all name the columns
an update may _not_ touch. Every column added to those tables from here on is
client-writable until someone remembers to pin it.

**Trigger:** adding a column. `npcs.faction_id`, a `characters.level`, anything.
The failure is invisible at the moment it is introduced — the migration adding
the column succeeds, the app works, and the column is simply open.

**Cost:** depends entirely on the column. Harmless for a display field, a
privilege hole for anything the DM is supposed to control. It fails open, which
is the wrong direction, and the comment at each trigger saying so only helps
someone who reads the trigger — and the reason they are editing is that they are
thinking about the column, not about the trigger.

**Fix if the answer changes:** invert to an allowlist. Start from `old` and copy
across only the writable set, so an unlisted column is read-only rather than
open:

```sql
declare r npcs := old;
begin
  r.name        := trim(new.name);
  r.description := new.description;
  r.location_id := new.location_id;
  r.is_revealed := new.is_revealed;
  return r;
end;
```

Identical behaviour today. This is a convention change rather than one table's
fix — do all three together or none, so the pattern stays legible.

046 and 047 add two more of the same shape —
`pin_character_spell_description_row` and `pin_character_item_description_row`,
each naming its two key columns and `updated_at`. Both say so in their own
headers. Five blocklists now; the inversion gets one table more expensive every
time this pattern is copied.

053 makes it six: `pin_item_row` pins `id`, `campaign_id` and `created_at` on
`items`. This one is wider than it looks, because `items` is the table most
likely to grow columns (rarity, attunement, weight), and every one of them is
DM-editable on homebrew the moment it lands. Today that is the right answer for
each of them, which is exactly how a blocklist stays unnoticed.

129 made the prediction true: `rarity`, `requires_attunement` and
`attunement_note` landed unpinned, which is right (a DM should be able to fix
their homebrew's rarity), and the CHECKs still apply.

### `npcs.description` is normalised in the client only (noted 2026-08-14, partly addressed by 035)

`name` is trimmed by `pin_npc_row` and backstopped by `npcs_name_check`, so the
database is where that rule lives. `description` is normalised by
`blankDescriptionToNull` in `services/npcs.ts` and by nothing in Postgres — two
adjacent fields, two different layers, for no stated reason.

**Trigger:** anything writing a description without going through `updateNpc`.
Today that means the seed and anything typed into the SQL editor, which is also
exactly where the roster comes from. A description of `'   '` stored that way
renders as an empty paragraph, because `npc.description ?? "No description yet"`
treats `''` as present.

**Cost:** cosmetic. One card with a blank space where its blurb should be, and no
sign anything went wrong.

**What 035 did and did not do.** `035_npc_desc_fix.sql` is the one-time cleanup
of existing rows and nothing else — no trigger change, no constraint. The rule
still lives only in the client.

```sql
-- the whole of 035
update npcs set description = null
where description is not null and trim(description) = '';
```

⚠ **Whether 035 actually ran is unconfirmed.** 036's ledger records it, but data-
only migrations are backfilled on the word of whoever ran the ledger file, and
the after-the-fact check (`select count(*) ... where trim(description) = ''`)
returns 0 both if it ran and if there was never anything to clean. The statement
is idempotent, so the cheap resolution is to run it once more and stop wondering.

**Fix if the answer changes:** mirror what `name` already does — normalise in the
trigger, backstop with a constraint. Clean first, then constrain, or the
constraint will not validate.

```sql
-- in pin_npc_row, beside the name trim
new.description := nullif(btrim(new.description), '');

alter table npcs add constraint npcs_description_check
  check (description is null or (description = trim(description) and description <> ''));
```

Block 9 of `033_npcs_verification.sql` confirms this constraint is **not**
currently present.

### NPCs cannot be created or deleted from the app (noted 2026-08-14)

`npcs` has SELECT and UPDATE policies and deliberately no INSERT and no DELETE.
The roster arrives through the SQL editor, which is also where portraits and
seeded notes are prepared. `034_npc_seed.sql` is written to be copied for this.

**Trigger:** wanting a new NPC mid-session. There is no button, and adding one is
a migration.

**Cost:** the DM leaves the app to add a row. Acceptable while the roster is
prepared between sessions, annoying the first time a player names an innkeeper
that needs to exist immediately.

**Fix if the answer changes:** an INSERT policy gated on `is_campaign_dm`, a
`with check` that pins `campaign_id` to a campaign the caller runs, and a
decision about `portrait_key` — which is currently pinned against updates
precisely because a key naming no file fails silently. This is a piece of work,
not a policy line. **The absence is the design; do not add either policy for
symmetry.**

Narrowed by 048: a *new* campaign no longer needs the SQL editor for the
standard roster, because a trigger on `campaigns` seeds it (see CLAUDE.md,
"Campaign seeding"). Anything beyond that roster, and any backfill into an
existing campaign, is still a hand-run migration. Copy 051 for that, not 034.

### Removing a player from a campaign destroys their character, gear, spells and feats (noted 2026-08-12, widened by 037 and 041)

`characters` carries a composite FK to `campaign_members (campaign_id, user_id)`
with `on delete cascade`, and `character_inventory.character_id`, — since 037 —
`character_spells.character_id` and — since 041 — `character_feats.character_id`
all cascade from `characters` in turn. So deleting one `campaign_members` row
silently deletes that player's PC, every item on it, every spell on it and every
feat on it, in the same statement, with no intermediate state and nothing to
restore from.

Each new child table widens this by one list without touching the entry, which
is the shape of the problem: the cascade is correct and invisible, and the count
of what it takes only ever goes up. 046 and 047 widen it again, and by the thing
that is least replaceable: both description tables cascade from `characters`, so
the words a player wrote go with everything else.

**Trigger:** any delete against `campaign_members`. There is no kick UI today —
the only paths are leaving a campaign yourself and a manual delete in the
Supabase console — so this is latent rather than live. It is written down now
because the day a "remove player" button is built, the cascade is already wired
and does not appear anywhere near the button that fires it. A DM demoting a
player who missed a session would not expect to be deleting their character
sheet, and the UI would give no sign that they had.

**Cost:** unrecoverable loss of one PC and everything on it. Cheap at this size
(a character is a name, a gear list and a spell list, and reset already exists as
a deliberate version of the same destruction), expensive in surprise, because
nothing in the action's wording implies it.

**Fix if the answer changes:** the cascade itself is right — 028 chose it so that
leaving a campaign takes your character with you rather than stranding a row that
fails its own FK. What is missing is at the call site, not in the schema: any
kick UI needs to name the consequence in its confirm, the way the reset form
already does, and should read the character first so it can name it. If
characters ever need to outlive membership, that is a different change —
`on delete cascade` becomes a nullable `campaign_members` link plus a retirement
flag, which 028 explicitly declined ("there is no retired_at, by decision").

### `removeFromPartyInventory` assumes party gear is common property

Any campaign member may remove any row from the party inventory. That is the
intended model — the party stash belongs to the party — and it matches how
recaps are editable by everyone.

**Fix if the answer changes:** if the DM ever needs sole control of removals, or
if `added_by` is ever meant to confer ownership, the DELETE policy is where that
split goes, not the service. `added_by` is already stamped server-side from
`auth.uid()` in a trigger, so the column is trustworthy enough to gate on.

### The Party page mounts two background queries per character, for the DM (noted 2026-08-17)

`GiveForm` and `TeachForm` write through `useCharacterInventory` and
`useCharacterSpells`, which are queries as well as mutations. A DM viewing a
party of six mounts six gear fetches and six spell fetches that the page never
renders — `useParty` already carried both, in one request.

**Trigger:** the DM opening the Party page. Players don't see the forms and don't
pay the cost.

**Cost:** eleven redundant requests at a party of six, all small and all cached.
Real but negligible at this size. 046/047 doubled each of those reads — both
`getCharacterSpells` and `getCharacterInventory` now fire a second request for
the override map — so the true figure is twenty-two.

**Why it's like this:** it buys the repo's rule that a mutation lives in a hook
rather than being wired up ad hoc in a page. That is worth eleven cheap requests.

**Fix if the party grows enough to matter:** `giveItem` and `teachSpell`
mutations on `useParty` — not bare service calls from the page.

### A homebrew class or race can be attached across campaigns (noted 2026-10-05)

041's hole, on 054/056's tables. A DM of campaigns A and B can create a class
or race in B and point a character in A at it, where A's players can't read
the row: the sheet then shows no class (or race) for that character.

**Trigger:** writing the row by hand; the client never offers it, because its
pickers read `getClasses(campaignId)` / `getRaces(campaignId)`.

**Cost:** one DM mislabelling their own table. Same reasoning as 041 for
leaving it open: closing it needs a trigger re-deriving the character's
campaign on every write.

### Use counters and rests: what the first version leaves out (noted 2026-11-07)

The counters work (`features-count`, 153 on) tracks uses of class features,
feats and spell slots, and has a Short Rest and a Long Rest button that clear
them. Its scope was cut on purpose. Each item below was decided with the
design and is not an oversight.

- **Spending a slot isn't linked to casting.** Slots are pips of their own.
  Nothing on the spell list spends one, and nothing records upcasting.
  *Fix:* a "Cast" control on each spell row that spends a slot at a level
  you choose, no lower than the spell's.
- **Partial recoveries are done by hand.** The rest buttons clear a counter
  completely. Features that win back only part of a pool are left to the
  player, who un-fills pips by hand. That covers Arcane Recovery, Natural
  Recovery, Harness Divine Power, Font of Magic's slot and point
  conversion, Psionic Power's one die per short rest, and every "regain one
  use when you roll initiative" feature (Ever-Ready Shot, Tireless Spirit,
  Superior Inspiration, Perfect Self...).
  *Fix:* one action per feature that knows what it gives back, for
  example an Arcane Recovery button that offers slots up to its level
  budget.
- **Magic item charges aren't tracked.** Items have no charges column (129
  added rarity and attunement only), and charges often come back as dice
  "at dawn".
  *Fix:* a `charges` and `recharge` pair on `items`, a counter per
  carried stack, and perhaps a third "Dawn" rest kind.
- **Multiclass characters get counters from their starting class only.**
  This is the sheet's existing single-class rule, which the Class Features
  list already follows. Slots use that one class's own table, not the
  PHB's multiclass table.
  *Fix:* walk every class entry, the same way `collectEffects` already
  does, and add the multiclass slot table to `rules.ts`.
- **A Long Rest only clears counters, like a Short Rest.** It doesn't
  restore the character's hit points (it does restore a steel defender's,
  167, whose stored damage makes that one write), clear temporary HP, give Hit Dice back or lower
  exhaustion. A Short Rest doesn't offer to spend Hit Dice. Spent Hit Dice
  aren't tracked at all: the tile shows `{level}d{die}`.
  *Fix:* HP to max and temp HP to 0 are two more columns in the long rest's
  write. Hit Dice want a `hit_dice_spent` column on `character_stats`,
  half of it returned on a long rest and a spend control for short rests.
- **Only the character's own sheet rests.** There's no DM-wide "the party
  takes a long rest" button. The owner and the DM can each press a
  character's buttons, as with every other sheet write (`can_edit_character`).
- **Homebrew features and feats can't define counters.** Counters are rows
  in `feature_resources` (153). Only the migrations write those, and the
  app has no form for them, the same gap as the rest of homebrew class
  editing (above).

### Magic items are free to add, and worth 0 in the hoard (noted 2026-11-05)

Decided with the seed: magic items behave like the rest of the Shop, so any
member can press "Add to party inventory" on a Vorpal Sword. And they are
priced 0 (the books give rarity ranges, not prices), so the hoard's "in goods"
total ignores them.

**Trigger:** a player adding loot the DM didn't hand out; a DM reading the
goods total as the party's wealth.

**Cost:** trust at the table; one misleading total.

**Fix if the answer changes:** hide the Add button when `item.rarity` is set
and `!showDmUi` (a client gate, like Give and Teach; RLS on `party_inventory`
is membership). For value, a per-rarity price table in code, used only by the
total.

### Editing a homebrew item rewrites every stack that holds it (noted 2026-09-30)

053 edits the `items` row in place, which is the point: no copy, no reseed. But
the hoard and every pack store an `item_id` and nothing else, so a change shows
up everywhere at once, including on stacks bought at the old price. Raise a
homebrew sword from 50 to 500 gold and the hoard's "in goods" total jumps by
450 per sword the party already holds. There is no history, so the old values
are gone.

**Trigger:** editing price or stats on a homebrew item someone already carries.

**Cost:** usually what the DM meant (a typo in the damage dice should be fixed
on the sword in the fighter's hands, too). The price case is the surprise, and
at a table of five it is one sentence of explanation.

**Fix if it ever matters:** snapshot the price onto the stack at purchase. Not
worth it while no screen distinguishes "what we paid" from "what it's worth".

### The faction feats lost their original categories (noted 2026-09-18)

052 moved the five faction feats into `factions`, and a feat has exactly one
category, so Harpers stopped being `social`, Zhentarim stopped being `skill`,
and so on. Accepted: the original assignments were arbitrary (five feats across
four categories), and what the five actually share is being faction
memberships.

**Cost:** filtering by Social no longer shows Harpers.

**Fix:** if per-feat flavour matters, put it in `tags`, which exists and is
unused. Don't add a second category column.

### Description rows outlive the gear they describe (noted 2026-08-22)

047 keys `character_item_descriptions` on `(character_id, item_id)` rather than
on the `character_inventory` row, precisely so a description survives a
stow-and-take and a decrement to zero. The other half of that choice is that
nothing ever cleans one up: sell the sword for good and the row you wrote about
it stays behind, unreachable from any screen, until the day that character owns a
sword again — at which point your old words reappear on it.

**Trigger:** permanently parting with an item you had written about.

**Cost:** one narrow row per abandoned idea, at a table of five. The reappearance
is arguably the feature working — it is the same character and the same kind of
object — but it will surprise someone eventually.

**Fix if it ever matters:** nothing automatic. A trigger on
`character_inventory` DELETE would defeat the entire point of the key. If the
rows ever need clearing it wants a deliberate control ("forget this"), or a
periodic sweep of overrides whose `(character_id, item_id)` matches no stack and
whose `updated_at` is old. Neither is worth writing yet.


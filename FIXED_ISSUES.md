# Fixed issues

Issues that were once open in `KNOWN_ISSUES.md` and have since been resolved,
newest first. Kept for the reasoning: each entry says what was wrong, what
fixed it, and which migration did it.

---

### Battle Ready's INT never reached a seeded magic weapon (noted 2026-11-07, resolved 2026-11-07 by 161 and 163)

`battleReadyAbility` swaps in INT on a magic weapon, but every seeded magic
weapon was `kind = 'general'`, so none was on the attack table. 161 gave
items a base weapon and a bonus, and 163 turned the 15 seeded magic weapons
with one named base into weapon rows, so a Battle Smith with a Mace of
Smiting gets INT and the +1. "Any weapon" templates (Weapon, +1) are still
text; the DM makes the concrete homebrew copy (KNOWN_ISSUES, "Magic
templates and armour are text").

### Spell class lists left out the Artificer (noted 2026-11-06, resolved 2026-11-07 by 149 and 152)

138-147 left 'Artificer' out of every spell's `classes` array, because the
catalogue had no such class. 149 seeds the class, and 152 adds it to the 95
spells on its TCoE list in 147's shape. Battle Smith's always-prepared
spells stay in its feature text, as no domain or oath list was ever written
into `classes`.

### XGtE and TCoE subclasses had no features (noted 2026-10-20, resolved 2026-11-05 by 097-120)

The 57 Xanathar's and Tasha's subclasses could be picked, but the sheet
showed only their description. 097-120 seed their 308 feature rows, one
file per book per class in 084's shape, each asserting its per-subclass
counts and its option links. College of Swords' Fighting Style (099) is the
one new picker, linked to Dueling and Two-Weapon Fighting.

### Champion's second fighting style had nowhere to go (noted 2026-10-11, resolved 2026-11-05 by 095)

`character_classes.fighting_style` held one style per class entry, so Additional
Fighting Style (Champion 10) was text with no picker. 095 moved every pick
into `character_feature_choices`, one row per feature, and linked Additional
Fighting Style to the Fighter's eleven. The sheet gathers styles from every
pick, so Defense or Archery taken second counts too, and a style can't be
taken twice. The general many-picks case is still open, above.

096 dropped the old columns, the `choice` flag and the `fighting_style`
domain on 2026-11-05, once the new client was live. Verification blocks in
079-095 that name those columns no longer run, by design (096's header).

### 029 was never applied, so `added_by` was client-supplied (noted 2026-08-31, resolved 2026-11-05 by 029)

The trigger that stamps `character_inventory.added_by` from the JWT on insert
and pins it on update had never run. It was worse than the entry first said:
030's `add_character_inventory_item` names no `added_by` and relies on this
trigger, so every stack added through the app since then has a null byline.
Those rows stay null, because the true adder was never recorded.

The ledger had claimed 029 all along. 036's backfill guard checked for
`character_inventory.added_by`, which is 028's column, not 029's trigger. 029
now corrects its row's `applied_at` instead of inserting one. Its BLOCK 1
runs the header's four cases, plus the RPC's `on conflict` increment, through
RLS as a real player and DM.

### The fighting-style list wasn't filtered by class (noted 2026-10-11, resolved 2026-10-20 by 083)

The picker offered all eleven styles to any Fighting Style feature. 083 gave
each feature row a `fighting_style_options` array (typed by a new
`fighting_style` domain, which replaced 079's CHECK), and the sheet offers
only that row's list. The Fighter keeps its eleven; 089 and 090 seed the
Paladin's and Ranger's seven each, including Tasha's Blessed Warrior and
Druidic Warrior.

### No portraits existed (noted 2026-08-14, resolved by 048–050)

`src/assets/portraits/` was not in the repo, so every NPC card rendered without
an image. It now holds three: Rose and Thorn (set in 048's seed INSERT), Strahd
(049, seeded and backfilled into every campaign) and Lancelot (050/051). The
recipe and its traps (file before key, `pin_npc_row` on UPDATE, restarting Vite
for the eager glob) now live in CLAUDE.md under "Campaign seeding and NPC
portraits".

### 050's backfill matched zero rows and committed (noted and resolved 2026-09-18, by 051)

050 named its campaign in three statements and guarded only the first, so fixing
a misspelling in the guard left both inserts matching nothing. They committed,
the ledger recorded 050, and the live campaign had no Lancelot. 051 redid the
backfill with the name in one variable and an end-state assertion. The lesson is
in CLAUDE.md's migration conventions ("A literal that must agree across
statements appears once").

### Nothing recorded which migrations had been applied (noted 2026-08-14, resolved by 036)

`db/` was declared ground truth while the database held no record of which files
in it had run. The two were compared only by accident — by someone regenerating
`database.types.ts` and noticing the diff, or by a feature failing in front of a
player. The 2026-08-13 episode was the illustration: three inventory RPCs came
back `PGRST202`, were read as "030 and 032 never ran", and re-running them fixed
it — which is also exactly what a stale PostgREST schema cache would have looked
like, since `create or replace function` emits a DDL event and forces a reload.

`036_schema_migrations.sql` creates the ledger and backfills 000–036 behind a
guard that raises if any migration's durable objects are missing, so the backfill
cannot record a claim the catalog contradicts. From 037 on, every migration ends
with a bare `insert into schema_migrations (version) values ('0NN');` inside its
own transaction — no `on conflict`, so a re-run fails on the primary key and a
half-run leaves no entry.

**What is still assumed rather than proven:** data-only migrations (002 003 005
017 023 024 026 034 035) have no object to check for and were recorded on the
word of whoever ran the file. And the original 030/032 question — stale cache or
never ran — was never settled; it is now simply answerable, which was the point.

Worth keeping: `PGRST202` means _not found in the schema cache_, not _does not
exist_. `notify pgrst, 'reload schema';` first, `pg_proc` before touching a
migration file.

### The decrement path was the last read-modify-write in the app (resolved by 032)

030 and 031 made adds insert-or-increment through an RPC, and left decrement
reading `currentQuantity` in the client and shipping back `quantity - 1` — so two
concurrent decrements lost one. 030 also made it _more_ reachable: stacks used to
fragment across rows, so two people spending arrows were often editing different
rows; afterwards every copy funnels into one row that both the owner and the DM
can decrement mid-session.

032 moved the branch into plpgsql behind a `select ... for update`. The lock is
the part that matters — the lock-free `update ... where quantity > 1` then
delete-if-no-rows is correct against a concurrent decrement but loses both copies
against a concurrent _add_ that bumps a stack of 1 to 2 in the window. Both
functions are `security invoker`, so RLS remains the boundary.

032 also dropped `character_inventory_character_id_idx`, which 030's unique
constraint had made redundant and which 030 deliberately deferred.

### A blank NPC description could reach the database from a second caller (resolved 2026-08-14)

`updateNpcDescription` normalised blank-to-`null`; `updateNpc` — the function the
editor actually calls — did not. The rule was written down in exactly one place
and enforced on a path nothing used.

Never a live bug: `NpcEditor` converted blank to `null` locally from its first
commit, and `git log -S` shows `updateNpcDescription` was never called by
anything. It was correct-today code that would have stopped being correct at the
second caller — which was going to be NPC creation.

Fixed by moving normalisation into `updateNpc` as `blankDescriptionToNull` and
deleting the per-field function. Guarded on `=== undefined` rather than on
falsiness, which is load-bearing: `toggleVisibility` sends `{ is_revealed }`
alone, and a falsiness check there would have blanked the description on every
eye click.

### The write half of the NPC reveal boundary was untested (resolved 2026-08-14)

`033_npcs_verification.sql` tested SELECT from four angles and no writes from an
unauthorised role at all, leaving the two policies with the most consequence
proven only by reading them.

Two blocks added. Block 7: a player sends an unscoped `update npcs set
is_revealed = true` — expect no error, since USING excludes every row before
WITH CHECK is consulted, so the proof is `rows_changed = 0` against an
owner-taken baseline in a temp table, plus `hidden_before` to show there was
something to steal. Block 8: a player attempts an INSERT into `npc_dm_notes`
naming a _revealed_ NPC, the case where they clear the outer half of the EXISTS
join and only `is_campaign_dm` stops them. The target is resolved as the player
before the attempt and travels in by uuid — a null `npc_id` fails the same EXISTS
with the same 42501, so without that the block would pass identically whether or
not the interesting gate was ever reached.

The same shape was carried into `037_character_spells.sql`: block 2 proves the
campaign DM may write to a player's sheet, block 3 proves another _member_ may
not, and block 3's subject is deliberately made a plain member first — as a
non-member they'd be stopped by the outer half of the check and the block would
prove the weaker thing.

### NPCs were filtered client-side (resolved by 033/034)

`NPC.tsx` held a hardcoded `NPCS` array and rendered `NPCS.filter(n =>
n.is_revealed)` — the exact anti-pattern the reveal-gating principle bans, not
leaking only because the data was static and identical for everyone. 033 gave
NPCs the locations treatment: `campaign_id` NOT NULL, an `npc_dm_notes` sibling
reached by a fail-closed join, and a SELECT policy of
`is_campaign_dm(campaign_id) or (is_revealed and is_campaign_member(campaign_id))`.
034 moved the roster into it. The page has no reveal filter now; `isDm` survives
only to render the editors and style the hidden rows a DM still receives.

### Cross-campaign homebrew visible in every campaign's catalogue (resolved 2026-08-12)

`getItems`/`getSpells` selected with no campaign filter and cached under bare
`["items"]`/`["spells"]` keys, on the theory that RLS scoped the result. RLS
answers "may this viewer see this row" — a member of two campaigns passes that
check for both campaigns' homebrew, so both would appear in either campaign's
Shop/Grimoire. Latent until 025 added the items INSERT policy (nothing could
create homebrew before that; spells still can't). Verified against the live DB
by impersonating a dual-member under RLS in a rolled-back transaction: the
unfiltered select returned both campaigns' probe items. Fixed by scoping both
services to `campaign_id is null or campaign_id = <viewed campaign>` and keying
the caches by campaign — the filter is scoping, not a second permission check;
RLS remains the boundary.

### Same-campaign duplicate invite after a double navigation (noted 2026-08-02, resolved 2026-08-11)

`addInvite` in `useInvites` used to prepend the minted row into local state,
guarded by a `shownCampaignId` ref against cross-campaign paints; a
same-campaign reload landing between the mint's two round trips could briefly
duplicate the row. Resolved by the move to TanStack Query: the mint invalidates
and the list comes back from the server, so there is no local prepend to race.

# Wanted features

New things the app doesn't do yet and might. This is not a bug list: what is
_wrong_ lives in `KNOWN_ISSUES.md`. An entry here says what the feature is, why
it would matter at the table, and the design questions to answer before any
code gets written. When one is built, delete its entry. The reasoning moves into
the migration headers and CLAUDE.md, the way every other feature's does.

**Last updated 2026-11-09.**

---

## Live updates, phase 2 (noted 2026-11-09)

Phase 1 (170) publishes the seven tables that change at the table. Everything
else still updates only on refocus or a refetch. Each table added here needs a
case in `keysForChange` and a test, plus the table's keys in
`keysAfterReconnect`.

- **The rest of the sheet:** `character_classes`, `character_proficiencies`,
  `character_feature_choices`, `character_spells`, `character_feats`. These are
  mostly owner-edited, so live matters only when the DM levels someone up.
  Publishing `character_spells` also closes the remaining half of KNOWN_ISSUES'
  party-cache entry.
- **Reveal-gated tables:** `locations`, `campaign_fortunes`,
  `campaign_map_reveals`, `npcs`. This is the interesting part, and why it
  waited.

**Questions to answer first:**

- **What happens on an un-reveal?** Realtime checks the *new* row against each
  subscriber's SELECT policy. A reveal passes, so the player hears it. An
  un-reveal makes the row fail `locations`' two-branch read, so the player hears
  nothing, and the pin stays on their map until a refetch. Options: accept it
  (un-reveals are rare and usually DM corrections), or invalidate the
  reveal-gated keys when any event on a table the player *can* see arrives.
  `campaign_map_reveals` doesn't have the problem: its read is plain membership
  (CLAUDE.md, Reveal gating), so both directions arrive.
- **Do deletes leak anything that matters?** A DELETE goes to every subscriber
  with only its primary key. A uuid of a hidden NPC is not a spoiler, but check
  each table's key before publishing it. A DM-only table (`*_dm_notes`) should
  never be published.

## Initiative and encounter tracker (noted 2026-11-09)

A DM page for running combat: turn order, whose turn it is, rounds, and
conditions. It would be the first page built for _using_ the app at the table
rather than looking things up in it.

**What it would hold:**

- **PCs**, with HP read from `character_stats` and damage applied through
  `adjust_character_hp`, so the tracker and the sheet are the same number.
- **The steel defender**, through `adjust_companion_hp`, found by its effect key
  as the sheet finds it.
- **Ad-hoc monsters**: a name, initiative, HP and AC typed in on the spot. No
  monster catalogue, which would be a project of its own.
- **Conditions** per combatant (poisoned, frightened, concentrating), ideally
  with a round count.

**Decided (2026-11-09):**

- **Stored, one live fight per campaign.** `encounters` is unique on
  `campaign_id` and holds `round` plus `turn_combatant_id` (an id, not an
  index, so adding or removing a monster mid-fight doesn't shift the turn).
  Ending the fight deletes it, and the combatants cascade with it.
  `encounters` and `encounter_combatants` are published to Realtime.
- **One "Combat" page for everyone.** The DM gets the controls, players get
  the order read-only, and the page shows an empty state when no fight is
  running.
- **Players see a monster's Bloodied/Down state, never its numbers.** HP, AC
  and the initiative bonus live in `encounter_monster_stats`, which is
  DM-only and never published. A trigger on it writes `status` onto the
  combatant row. That is a stored derived column on purpose: a definer RPC
  would hide the HP just as well, but players would never hear the status
  change, because the DM-only table can't be published. The combatant pin
  trigger refuses direct writes to `status`, DM included, unless
  `pg_trigger_depth() > 1`.
- **The DM can roll for everyone, and a player can enter their own PC's
  initiative.** `encounter_combatants` UPDATE is `can_edit_character` for a
  PC row, plus an allowlist pin trigger (095's shape) that leaves a non-DM
  only `initiative`. A roll is d20 plus the sheet's `initiative()`; advantage
  on initiative is not modelled.
- **Order:** initiative, then the higher DEX score, then name A-Z. The DM has
  no manual override. A PC's DEX is read from `character_stats` and a
  monster's is a public column on its combatant row, because players compute
  the order too. Alphabetical rather than random, because a random tiebreak
  would have to be stored, or each client would sort the tie differently.
  The steel defender has no initiative: it always sits directly after its
  Artificer.
- **Down combatants keep their turn** (death saves), dimmed. The DM removes
  them.
- **No conditions in v1.**
- **Left open:** a DM of two campaigns can attach a PC of the other campaign
  by hand (041 BLOCK 6's shape). Goes in ACCEPTED_ISSUES.

**Build order (one commit each):** 171 schema, policies, pins, status trigger
and verification blocks, then `gen:types` · 172 publication + `keysForChange`
cases and tests · `turnOrder`, `nextTurn` and `rollInitiative` in `rules.ts`
with tests · services and hooks (PC HP through `adjust_character_hp`, the
defender's through `adjust_companion_hp`) · page, route and nav · docs.

## Curse of Strahd campaign state (noted 2026-11-09)

The app is currently a general 5e manager with CoS seed data. The book's own
mechanics have nowhere to live:

- **Dark Gifts** (Amber Temple). Each gift is a benefit plus a flaw, and
  several change derived numbers. They fit the `effect` key system as a fourth
  source beside class features, races and feats (159's shape: an `effect`
  column on a catalogue table, read at total level).
- **Madness** (DMG short/long/indefinite tables), which comes up repeatedly in
  Barovia. Owner-or-DM, per character, with a duration.
- **Standing with factions and NPCs**: the Keepers of the Feather, the Vistani,
  Wizard of Wines, and Strahd's interest in each PC. Probably DM-only to read,
  which makes it a `*_dm_notes`-style sibling table.

**Questions to answer first:**

- **Which of these would you actually use at the table?** Each is small alone.
  Building all three before one is used is the over-engineering trap.
- **What do players see?** A player should know their own Dark Gift's
  benefit. Whether they see its flaw's full text is a DM call. Strahd's interest
  is presumably DM-only.
- **Catalogue or free text?** Dark Gifts are a fixed list of ten, so a seeded
  catalogue fits. Madness entries are rolled from tables, so free text with a
  duration may be enough.

## Campaign calendar and time of day (noted 2026-11-09)

The in-world date, day or night, and the days since the party entered Barovia.
CoS is time-sensitive (the Feast of St. Andral, Strahd's pursuit of Ireena,
night being worse than day), and recaps currently know only the session number.

**What it would hold:** one row per campaign with the current in-world date and
time (the `party_currency` shape: one row, member-read, DM-write). Optionally,
an in-world date on each `session_recaps` row, so recaps can show "Day 4, night"
beside "Session 7".

**Questions to answer first:**

- **What calendar?** Barovia has no canonical calendar, so the options are the
  Forgotten Realms' Harptos calendar or a plain day count from arrival. A day
  count is far simpler and probably enough.
- **How fine-grained?** Day plus a day/night flag, or hours? Hours suggest
  tracking rests, which overlaps the Long Rest button.
- **Store inputs, derive the rest.** Store the day number and time, and derive
  the moon phase and "days in Barovia" in code, per CLAUDE.md's character-sheet
  rule.
- **Who advances time?** The DM only, almost certainly.

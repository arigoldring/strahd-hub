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

## Conditions in the initiative tracker (noted 2026-11-09)

The tracker (171-172) shipped without conditions, by decision: turn order and
HP first, conditions once it has been used at the table. Wanted: poisoned,
frightened, concentrating and the rest on a combatant, ideally with a round
count that ticks down at the start of that combatant's turn.

**Questions to answer first:**

- **On the combatant or on the character?** A condition outlives a fight now
  and then (poisoned until a long rest), which argues for the character, and
  the sheet would show it. Most don't, and a monster has no character, so a
  character table still leaves monsters needing their own. Two places to look
  is the cost of putting it on the character.
- **Do players see monsters' conditions?** Probably yes (they can see a
  zombie is prone), which would make it a public column or table, unlike HP.
- **Free text or a closed list?** The 2014 PHB's fifteen conditions plus
  exhaustion's six levels are a closed list, which is a CHECK and a tuple
  (one list in two places). Concentration isn't a condition but belongs here.

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

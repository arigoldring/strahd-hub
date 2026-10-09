# Strahd Hub

A campaign hub for a *Curse of Strahd* D&D group: shared party inventory,
spellbooks, character sheets, maps with DM-controlled reveals, NPC records and
session recaps. Players see only what the DM has revealed to their campaign.
That rule is enforced in Postgres, not in the UI.

**Live demo:** <https://dnd-cos.pages.dev/#/demo> signs you into a shared demo
account. No sign-up is needed.

<!-- ![Strahd Hub](docs/screenshot.png) -->

## Stack

- **Frontend:** React 19, TypeScript, React Router, TanStack Query, Vite
- **Backend:** Supabase (Postgres, Auth, auto-generated REST API)
- **Hosting:** Cloudflare Pages

There is no custom server. The browser talks to Postgres through Supabase's
REST layer using the public anon key, so **the database is the only security
boundary**. Every rule about who can read or change what has to live there.

## How authorization works

**Row-level security on every table.** Policies scope each row to the campaigns
the caller belongs to, and answer "is this user the DM?" per campaign rather
than globally.

- [`db/016_campaign_rls.sql`](db/016_campaign_rls.sql) scopes reads by
  campaign membership. Locations also need the DM's reveal flag, so hidden
  content never leaves the server.
- [`db/018_campaign_dm_rls.sql`](db/018_campaign_dm_rls.sql) makes write
  access a per-campaign DM check. Before this, a DM in one campaign could edit
  another campaign's content.

**Security-definer functions for privileged writes.** Anything that has to
cross an RLS boundary (accepting an invite, creating a campaign, setting a
display name) goes through a `security definer` function. The function checks
the caller itself and does exactly one thing. Clients never get direct write
access to the protected columns.

- [`db/009_profile_role_lock.sql`](db/009_profile_role_lock.sql) closes a
  privilege-escalation path. The original insert policy checked whose profile
  row it was but not what was in it, so a new user could create their own
  profile with `role = 'dm'`.
- [`db/008_function_grants.sql`](db/008_function_grants.sql) revokes
  `EXECUTE` from `anon`. A security-definer function bypasses RLS, so its grant
  is the only gate it has.

**Multi-step writes are single transactions.** Moving a stack between the
party hoard and a character, or decrementing a shared quantity, happens in one
database function. Two players acting at once can't lose or duplicate an item.
See [`db/032_atomic_decrement.sql`](db/032_atomic_decrement.sql) and
[`db/038_inventory_transfer.sql`](db/038_inventory_transfer.sql).

Every migration opens with a header comment explaining the problem it solves
and the alternatives it rejected.

## Schema and migrations

[`db/`](db/) is the source of truth for the schema: numbered, hand-written SQL
migrations, applied in order. `public.schema_migrations` records which ones
have actually run against a database. [`db/fixtures/`](db/fixtures/) holds the
demo-campaign reset script and test-campaign seed/teardown.

TypeScript types are generated from the live schema
(`src/types/database.types.ts`), so a migration that didn't land shows up as a
type diff.

## Running locally

Requires Node 20.19+ and a Supabase project.

```sh
npm install
cp .env.example .env   # then fill in the values
```

`.env`:

```
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=...
# Optional: only needed for the /demo sign-in
VITE_DEMO_EMAIL=...
VITE_DEMO_PASSWORD=...
VITE_DEMO_CAMPAIGN_ID=...
```

Apply `db/*.sql` to the project in numeric order (in the Supabase SQL editor or
with `psql`), then:

```sh
npm run dev         # dev server
npm run typecheck   # tsc --noEmit
npm run lint
npm run gen:types   # regenerate DB types (needs `supabase link`)
```

## Known issues

Open bugs and deliberate trade-offs are tracked in
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).

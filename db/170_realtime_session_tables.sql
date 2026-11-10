-- db/170_realtime_session_tables.sql
--
-- Live updates, phase 1: the tables that change at the table during a session
-- start emitting change events to Supabase Realtime, so a player's sheet shows
-- the DM's damage, loot and rests without a refocus or refetch.
--
-- HOW THIS WORKS. Every committed change is written to Postgres's WAL. A
-- publication is the list of tables whose changes logical replication sends
-- out, and Supabase's Realtime server reads the one called
-- `supabase_realtime`. Until this file it listed nothing, so no table emitted
-- anything. Adding a table here is all the database side needs.
--
-- RLS STILL DECIDES WHO HEARS WHAT. For each INSERT or UPDATE, Realtime runs
-- the table's SELECT policy as each subscriber and sends the event only to
-- those it passes. No policy changes, and no subscriber learns a row it could
-- not already read. The exception is DELETE: there is no row left to check, so
-- a delete goes to every subscriber of the table, carrying only the primary
-- key (replica identity is left at DEFAULT on purpose, so `old` holds the id
-- and nothing else). A bare uuid is what leaks, and the client can't tell
-- which character it belonged to, so it invalidates deletes by key prefix
-- (src/lib/realtimeKeys.ts).
--
-- WHY THESE SEVEN. They are what changes mid-session: HP (character_stats),
-- loot (character_inventory, party_inventory), spent counters
-- (character_resource_uses), the steel defender (character_companions), and
-- coin (characters' purse columns, party_currency). Reveal-gated tables
-- (locations, campaign_map_reveals, campaign_fortunes) wait for phase 2
-- (decided 2026-11-09), because an un-reveal fails the player's policy and so
-- never reaches them. That is a design question of its own.
--
-- The client invalidates query keys on each event rather than writing the
-- payload into the cache; CLAUDE.md "Realtime" has the reasoning.
--
-- Run by Claude via `npx supabase db query --linked`. In the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."
-- Not idempotent: `add table` refuses a table already in the publication, and
-- the ledger insert refuses a second run anyway.

begin;

alter publication supabase_realtime add table
  public.characters,
  public.character_stats,
  public.character_inventory,
  public.character_resource_uses,
  public.character_companions,
  public.party_inventory,
  public.party_currency;

-- Assert the end state: all seven are published.
do $$
declare
  c_tables constant text[] := array[
    'characters', 'character_stats', 'character_inventory',
    'character_resource_uses', 'character_companions',
    'party_inventory', 'party_currency'
  ];
  v_missing text[];
begin
  select array_agg(t) into v_missing
    from unnest(c_tables) t
   where not exists (
     select 1 from pg_publication_tables p
      where p.pubname = 'supabase_realtime'
        and p.schemaname = 'public'
        and p.tablename = t
   );
  if v_missing is not null then
    raise exception 'Not in supabase_realtime: %. Rolled back.', v_missing;
  end if;
end $$;

insert into public.schema_migrations (version) values ('170');

commit;


-- ===========================================================================
-- VERIFICATION (run each block on its own; each ends in rollback)
-- ===========================================================================

-- BLOCK 1: what the publication holds.
-- PASS: exactly the seven tables above, nothing else. A DM-only table here
-- (npc_dm_notes, location_dm_notes) would be a mistake: RLS would still filter
-- its updates, but its deletes would announce ids to every member.
begin;
select schemaname, tablename
  from pg_publication_tables
 where pubname = 'supabase_realtime'
 order by tablename;
rollback;

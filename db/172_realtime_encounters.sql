-- db/172_realtime_encounters.sql
--
-- The initiative tracker's public tables join the Realtime publication, so
-- the DM's "Next turn", a player's typed initiative and a monster turning
-- Bloodied reach every member's screen without a refetch. 170's header
-- explains the mechanism; nothing about it changes here.
--
-- TWO OF 171'S THREE TABLES, AND THE THIRD IS NEVER TO BE ADDED.
--
--   encounters             round and whose turn it is.
--   encounter_combatants   the order, initiative, and the Bloodied/Down
--                          status. 171 stores status on this row precisely
--                          so that this publication carries it.
--   encounter_monster_stats  NOT PUBLISHED. RLS would still filter its
--                          INSERT and UPDATE events, but a DELETE reaches
--                          every subscriber with its key, and the DM is its
--                          only reader anyway: their own writes invalidate
--                          their own cache.
--
-- WHAT A DELETE ANNOUNCES. Replica identity stays DEFAULT (170), so a
-- removed combatant or an ended fight sends its bare uuid to every member of
-- every campaign subscribed to the table. A uuid names nothing: not the
-- monster, not the campaign. The client can't tell which fight it belonged to
-- either, so it invalidates by prefix (src/lib/realtimeKeys.ts).
--
-- NO SERVER-SIDE FILTER, as in 170: encounter_combatants has no campaign_id
-- (171, the sibling-table rule), so a filter couldn't name the campaign.
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
  public.encounters,
  public.encounter_combatants;

-- Assert the end state: both published, the DM-only table not.
do $$
declare
  c_published constant text[] := array['encounters', 'encounter_combatants'];
  c_private   constant text   := 'encounter_monster_stats';
  v_missing text[];
begin
  select array_agg(t) into v_missing
    from unnest(c_published) t
   where not exists (
     select 1 from pg_publication_tables p
      where p.pubname = 'supabase_realtime'
        and p.schemaname = 'public'
        and p.tablename = t
   );
  if v_missing is not null then
    raise exception 'Not in supabase_realtime: %. Rolled back.', v_missing;
  end if;

  if exists (
    select 1 from pg_publication_tables p
     where p.pubname = 'supabase_realtime'
       and p.schemaname = 'public'
       and p.tablename = c_private
  ) then
    raise exception '% is published. Rolled back.', c_private;
  end if;
end $$;

insert into public.schema_migrations (version) values ('172');

commit;


-- ===========================================================================
-- VERIFICATION (run each block on its own; each ends in rollback)
-- ===========================================================================

-- BLOCK 1: what the publication holds.
-- PASS: 170's seven tables plus encounters and encounter_combatants, nine
-- rows, and no *_dm_notes or encounter_monster_stats among them.
begin;
select schemaname, tablename
  from pg_publication_tables
 where pubname = 'supabase_realtime'
 order by tablename;
rollback;

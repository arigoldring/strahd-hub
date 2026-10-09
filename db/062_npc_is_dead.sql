-- db/062_npc_is_dead.sql
--
-- NPCs can die. One boolean column on npcs, set by the DM from the NPC editor;
-- the card turns blood-red and shows "Deceased" where the home would be.
--
-- A COLUMN, NOT A LOCATION. The first idea was a "Dead" entry in the editor's
-- location dropdown. location_id is half of a composite FK into locations
-- (033), so "Dead" would have had to be a real locations row -- seeded into
-- every campaign, sitting on some map, revealable -- and choosing it would
-- overwrite where the NPC lived. Dead and home are two facts; the card shows
-- "Deceased" in place of the home, but location_id is kept, so un-ticking
-- brings the home back.
--
-- EVERY CAMPAIGN, NO SEED CHANGE. `not null default false` fills the column on
-- every existing row in every campaign as it is added, and every row the seed
-- writes later gets the default. seed_campaign_npcs() is untouched and stays at
-- 061's body; there is no backfill because there is nothing to backfill.
--
-- NOT PINNED, ON PURPOSE. pin_npc_row (033) is a blocklist, so a new column is
-- writable unless someone pins it. This one should be: it is DM-edited like
-- is_revealed, and "dms update npcs" already makes the whole row DM-only. Left
-- out of the trigger deliberately, not forgotten -- BLOCK 2 proves an update
-- sticks.
--
-- PUBLIC, ON PURPOSE. A plain column, so anyone who can see the NPC sees that
-- they are dead. The party killed them or watched it happen. A death the party
-- does not know about would need npc_dm_notes' shape (a DM-only sibling table),
-- because RLS hides rows, not columns.

begin;

alter table public.npcs
  add column is_dead boolean not null default false;

insert into public.schema_migrations (version) values ('062');

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION -- run one block at a time (the SQL editor renders only the
-- last result set). No ledger rows; each block ends in rollback.
-- ---------------------------------------------------------------------------

-- BLOCK 1 -- every existing NPC in every campaign got the column, alive.
-- Expect one row per campaign, dead = 0 (until you kill someone).
begin;
  select c.name as campaign,
         count(*)                         as npcs,
         count(*) filter (where n.is_dead) as dead
  from npcs n
  join campaigns c on c.id = n.campaign_id
  group by c.name
  order by c.name;
rollback;

-- BLOCK 2 -- pin_npc_row does not reset it. Expect one row, is_dead true.
-- A false here means someone pinned the column in the trigger.
begin;
  update npcs n
  set is_dead = true
  from campaigns c
  where c.id = n.campaign_id
    and c.name = 'Not Curse of Strahd'
    and n.name = 'Little Timmy'
  returning n.name, n.is_dead;
rollback;

-- BLOCK 3 -- a new campaign's seeded roster arrives alive. Expect one row,
-- dead = 0 and npcs > 0.
--
-- Two statements, not 060's single WITH ... INSERT: a data-modifying CTE's rows
-- -- and the rows its triggers write -- are invisible to the rest of the same
-- statement, so the one-statement shape counts zero NPCs whatever the seed did.
-- npcs > 0 is the check that the seed was actually observed.
begin;
  insert into campaigns (name) values ('062 verification');

  select count(*)                         as npcs,
         count(*) filter (where n.is_dead) as dead
  from npcs n
  join campaigns c on c.id = n.campaign_id
  where c.name = '062 verification';
rollback;

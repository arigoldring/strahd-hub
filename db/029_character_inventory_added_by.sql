-- character_inventory.added_by was client-supplied. This makes it JWT-derived.
--
-- 028 shipped the column as provenance -- "the difference between what a player
-- picked up and what the DM handed them", per the sheet's byline -- but nothing
-- constrained who could claim to be the adder:
--
--   INSERT   with check (can_edit_character(character_id)) gates WHICH character
--            you may write to, and says nothing about added_by. A player who can
--            edit their own sheet could insert a Sunsword stamped with the DM's
--            id.
--
--   UPDATE   worse, because it is retroactive: no column pinning at all, so any
--            row already on the sheet could have its byline rewritten after the
--            fact by anyone can_edit_character admits.
--
-- The client was passing an honest value (useCharacterInventory read user.id
-- from AuthContext), but honesty was the client's choice to make, and the whole
-- point of the column is that it is not. This is the same fix 007 already made
-- for session_recaps.last_edited_by -- identity from the JWT, never the payload
-- -- and it restores the invariant characters' own INSERT policy states as
-- `user_id = auth.uid()`.
--
-- A `with check (added_by = auth.uid())` on the INSERT policy would close the
-- forge and leave the retroactive edit open, so the policies are left alone and
-- the trigger does both. After this migration that clause would be dead weight
-- anyway: BEFORE triggers run before WITH CHECK is evaluated, so the policy
-- would only ever re-test a value the trigger just assigned.
--
-- Rows written before this migration keep whatever added_by the client sent.
-- There is nothing to backfill them from -- the true adder was never recorded
-- anywhere else -- so they are trusted as-is rather than nulled.
--
-- APPLIED LATE, 2026-11-05. This file was written in August and never run
-- (KNOWN_ISSUES, noted 2026-08-31). It is applied as written, with two things
-- added: a correction to its ledger row, and real verification blocks in place
-- of the comment that described them.
--
-- THE LEDGER ROW ALREADY EXISTED, AND IT WAS FALSE. 036 backfilled 000-035 and
-- guarded each version by checking for an object it should have created. For
-- 029 the guard looked for `character_inventory.added_by`, but that is 028's
-- column, so the guard passed on a database where 029 had never run. A plain
-- insert here therefore fails on the primary key. The file corrects the
-- existing row to the date 029 actually landed instead, and raises unless
-- exactly one row changed. A re-run still fails, on `create trigger`, so the
-- unguarded-ledger property holds.
--
-- The general lesson for a backfill guard: check for the one object the
-- migration itself creates, never for something it only depends on.
--
-- Not running it had become worse than the original problem. 030 made adds an
-- RPC (`add_character_inventory_item`) that names no added_by at all, on the
-- assumption that this trigger would fill it in. So every stack added since
-- then has a null byline, from the player and the DM alike, and the sheet's
-- "from <name>" line has quietly stopped appearing. Rows added in that gap stay
-- null. The true adder was never recorded, so there is nothing to backfill.
--
-- THE SQL EDITOR MAY OFFER "Run and enable RLS". Decline it: this file creates
-- no table.

begin;

-- INSERT stamps, UPDATE pins, and the difference is the point: added_by means
-- "who added this", not "who last touched it". decrementCharacterInventoryItem
-- issues an UPDATE for every quantity change, so stamping auth.uid() on both
-- branches would rewrite the byline of a player's own find to the DM's name the
-- first time the DM decremented it -- corrupting the field this migration exists
-- to protect, through the app's most ordinary write.
--
-- old.added_by rather than a `new.added_by := old.added_by` guarded by an
-- is-distinct-from check: an UPDATE that does not mention the column already
-- carries the old value into new, so the assignment is a no-op in the honest
-- case and an override in the forged one.
--
-- Not pinned here: id and created_at, which remain freely writable on UPDATE the
-- way 028 left them. Out of scope for this migration, and worth a look if a
-- later one revisits this trigger.
create or replace function public.stamp_character_inventory_added_by()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
begin
  if tg_op = 'INSERT' then
    -- Identity from the JWT, never the payload.
    new.added_by := auth.uid();
  else
    new.added_by := old.added_by;
  end if;
  return new;
end;
$function$
;

create trigger stamp_character_inventory_added_by
  before insert or update on public.character_inventory
  for each row execute function public.stamp_character_inventory_added_by();

-- 036's backfill row, corrected to the day this actually ran (see header).
do $$
declare
  v_updated int;
begin
  update public.schema_migrations
     set applied_at = now()
   where version = '029';
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'Corrected % ledger rows for 029 (expected 1). Rolled back.', v_updated;
  end if;
end
$$;

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.
--
-- The uuids are 037's, so a block cannot quietly test nothing by picking a
-- `limit 1` row that does not exist:
--
--   campaign A   d721b412-2750-492e-bddd-7387fc464bba   The cool kids
--   player of A  1313672b-6990-45a6-8a28-c448ca116d2d   Nat
--   DM of A      ea74d56b-8f45-4e4c-80f8-90a6d29b5adf   Dlizard72


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 1 from pg_proc
    where proname = 'stamp_character_inventory_added_by'
      and pronamespace = 'public'::regnamespace
      and not prosecdef)                                            as function_invoker,
  (select count(*) = 1 from pg_trigger
    where tgrelid = 'public.character_inventory'::regclass
      and tgname = 'stamp_character_inventory_added_by'
      and tgenabled = 'O')                                          as trigger_enabled,
  (select count(*) = 1 from public.schema_migrations
    where version = '029')                                          as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the four cases from the header, plus the RPC's increment
-- ---------------------------------------------------------------------------
--
-- Every write goes through RLS as a real member of campaign A, the way the
-- app makes it. Two shared items not already on Nat's sheet are picked, so
-- the block never touches a real stack.
--
--   case 1  Nat inserts a stack of 2, claiming added_by = the DM
--   case 2  the DM adds a different item through add_character_inventory_item,
--           which names no added_by at all
--   case 3  Nat rewrites the DM's stack to his own id
--   case 4  the DM decrements Nat's stack of 2. It must become an UPDATE, not
--           a DELETE, which is why case 1 inserts 2
--   case 5  the DM adds one more of Nat's item through the RPC, which takes
--           its `on conflict do update` branch
--
-- Cases 4 and 5 are the regression the header warns about. A trigger that
-- stamps auth.uid() on both branches passes cases 1-3 and fails these two, so
-- they read added_by back rather than checking that the write was allowed.
--
-- CORRECT OUTPUT: seven rows.
--   target_found   true
--   case_1         player        (not dm: the forged id was overwritten)
--   case_2         dm
--   case_3         dm            (not player: the rewrite was pinned)
--   case_4         player qty 1
--   case_5         player qty 2
--   errors         none

begin;

select set_config('verification.character',
  (select id::text from public.characters
    where campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
      and user_id = '1313672b-6990-45a6-8a28-c448ca116d2d'
    order by created_at limit 1), true);

select set_config('verification.items',
  (select string_agg(id::text, ',') from (
     select i.id from public.items i
      where i.campaign_id is null
        and not exists (
          select 1 from public.character_inventory ci
           where ci.character_id = nullif(current_setting('verification.character'), '')::uuid
             and ci.item_id = i.id)
      order by i.name limit 2) two), true);

set local role authenticated;

do $$
declare
  c_player constant uuid := '1313672b-6990-45a6-8a28-c448ca116d2d';
  c_dm     constant uuid := 'ea74d56b-8f45-4e4c-80f8-90a6d29b5adf';
  v_char   uuid := nullif(current_setting('verification.character'), '')::uuid;
  v_item1  uuid := split_part(current_setting('verification.items'), ',', 1)::uuid;
  v_item2  uuid := split_part(current_setting('verification.items'), ',', 2)::uuid;
  v_row1   uuid;
  v_row2   uuid;
begin
  if v_char is null then return; end if;

  -- case 1: the player forges the DM's id
  perform set_config('request.jwt.claims',
    format('{"sub":"%s","role":"authenticated"}', c_player), true);
  insert into character_inventory (character_id, item_id, quantity, added_by)
  values (v_char, v_item1, 2, c_dm)
  returning id into v_row1;

  -- case 2: the DM adds through the RPC, naming no added_by
  perform set_config('request.jwt.claims',
    format('{"sub":"%s","role":"authenticated"}', c_dm), true);
  v_row2 := add_character_inventory_item(v_char, v_item2);

  perform set_config('verification.case_1',
    (select case added_by when c_player then 'player' when c_dm then 'dm'
                          else coalesce(added_by::text, 'null') end
       from character_inventory where id = v_row1), true);
  perform set_config('verification.case_2',
    (select case added_by when c_player then 'player' when c_dm then 'dm'
                          else coalesce(added_by::text, 'null') end
       from character_inventory where id = v_row2), true);

  -- case 3: the player rewrites the DM's byline to his own
  perform set_config('request.jwt.claims',
    format('{"sub":"%s","role":"authenticated"}', c_player), true);
  update character_inventory set added_by = c_player where id = v_row2;
  perform set_config('verification.case_3',
    (select case added_by when c_player then 'player' when c_dm then 'dm'
                          else coalesce(added_by::text, 'null') end
       from character_inventory where id = v_row2), true);

  -- case 4: the DM decrements the player's stack of 2
  perform set_config('request.jwt.claims',
    format('{"sub":"%s","role":"authenticated"}', c_dm), true);
  perform decrement_character_inventory_item(v_row1);
  perform set_config('verification.case_4',
    (select case added_by when c_player then 'player' when c_dm then 'dm'
                          else coalesce(added_by::text, 'null') end
            || ' qty ' || quantity
       from character_inventory where id = v_row1), true);

  -- case 5: the DM adds one more of the player's item, hitting on conflict
  perform add_character_inventory_item(v_char, v_item1);
  perform set_config('verification.case_5',
    (select case added_by when c_player then 'player' when c_dm then 'dm'
                          else coalesce(added_by::text, 'null') end
            || ' qty ' || quantity
       from character_inventory where id = v_row1), true);

  perform set_config('verification.errors', 'none', true);
exception when others then
  perform set_config('verification.errors', sqlstate || ': ' || sqlerrm, true);
end
$$;

reset role;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'target_found', nullif(current_setting('verification.character', true), '') is not null,
         'case_1',       current_setting('verification.case_1', true),
         'case_2',       current_setting('verification.case_2', true),
         'case_3',       current_setting('verification.case_3', true),
         'case_4',       current_setting('verification.case_4', true),
         'case_5',       current_setting('verification.case_5', true),
         'errors',       current_setting('verification.errors', true)
       ));

rollback;

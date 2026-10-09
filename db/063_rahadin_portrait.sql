-- db/063_rahadin_portrait.sql
--
-- Rahadin gets a portrait. 049's recipe, because this is 049's case: Rahadin
-- has been in the seeded roster since 048 with a null key, so every campaign
-- already has a copy of him, and one bundled file is right for all of them.
--
--   1. src/assets/portraits/rahadin.webp, committed alongside
--   2. portrait_key = 'rahadin', matching the filename exactly
--
-- THE SOURCE WAS RE-EXPORTED. It arrived as `Rahadin.webp`, 819x1000 and 64 KB.
-- Renamed to lowercase -- import.meta.glob matches the path as a string, so
-- 'rahadin' would never have found `Rahadin.webp` (and a Windows checkout
-- would hide the mismatch until it deployed). Scaled to 420x513 (15 KB). Head
-- and shoulders on white, framed like Strahd's, so npc.css's shared
-- `object-position: 50% 22%` keeps forehead through collar on the card and
-- loses only the top of his hair. No CSS change.
--
-- Two parts, one transaction:
--
--   1. seed_campaign_npcs() -- seventh version (048, 049, 050, 058, 059, 061,
--      this). Only Rahadin's portrait_key differs from 061; everything else
--      verbatim.
--   2. Every existing campaign's Rahadin is backfilled, including "Not Curse
--      of Strahd". Every campaign, not one, for 049's reason: the key names a
--      file that is correct for every copy of the same seeded NPC.
--
-- THE BACKFILL DISABLES pin_npc_row, AND HAS TO. portrait_key is pinned, so an
-- UPDATE with the trigger live reports success and changes nothing (049's
-- header has the long version). The ALTERs sit inside this file's
-- begin/commit, so a failure rolls the re-enable back with everything else.
--
-- `portrait_key is null` in the WHERE means a re-run updates nothing and a key
-- someone set by hand is left alone.

begin;

-- ---------------------------------------------------------------------------
-- 1. seed_campaign_npcs() -- seventh version. Edit from this one next time.
-- ---------------------------------------------------------------------------

create or replace function public.seed_campaign_npcs()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  with seeded as (
    insert into npcs (campaign_id, name, description, location_id, is_revealed, portrait_key)
    select NEW.id,
           v.name,
           v.description,
           (select l.id from locations l
            where l.campaign_id = NEW.id and l.name = v.location_name),
           v.is_revealed,
           v.portrait_key
    from (values
      (
        'Strahd von Zarovich',
        'The vampire lord who rules Barovia, ancient and cursed to relive his tragic love story forever.',
        'Castle Ravenloft',
        true,
        'strahd-von-zarovich'
      ),
      -- changed in 063. Names src/assets/portraits/rahadin.webp.
      (
        'Rahadin',
        'Strahd''s Dusk Elf chamberlain and executioner, fiercely loyal and centuries old.',
        'Castle Ravenloft',
        false,
        'rahadin'
      ),
      (
        'Rose and Thorn',
        'A young girl and her little brother.',
        'Death House',
        false,
        'rose-and-thorn'
      ),
      (
        'Lancelot',
        'A dog.',
        'Death House',
        false,
        'lancelot'
      ),
      (
        'Ismark Kolyanovich',
        'Son of the late burgomaster and the village''s acting leader, sworn to protect his sister Ireena.',
        'Burgomaster''s Mansion',
        false,
        'ismark-kolyanovich'
      ),
      (
        'Ireena Kolyanovich',
        'Portrait credit to www.patreon.com/calebisdrawing' || chr(10) ||
        'Daughter of the late burgomaster and sister to Ismark -- red-haired, sword in hand, and the object of Strahd''s attention.',
        'Village of Barovia',
        false,
        'ireena-kolyanovich'
      )
    ) as v(name, description, location_name, is_revealed, portrait_key)
    returning id, name
  )
  insert into npc_dm_notes (npc_id, notes)
  select id, notes
  from seeded
  join (values
    ('Rose and Thorn', 'Ghosts. Illusions when outside the house -- do not appear on Sense Undead or similar abilities out there.')
  ) as dm_notes(name, notes) using (name);

  return NEW;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 2. Backfill every existing Rahadin. Without the two ALTERs the UPDATE is a
--    silent no-op that still reports a row count.
-- ---------------------------------------------------------------------------

alter table public.npcs disable trigger pin_npc_row;

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_npc      constant text := 'Rahadin';
  c_key      constant text := 'rahadin';
  c_campaign constant text := 'Not Curse of Strahd';

  v_missing int;
begin
  update public.npcs
  set portrait_key = c_key
  where name = c_npc
    and portrait_key is null;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  -- No Rahadin anywhere is still keyless...
  select count(*) into v_missing
  from public.npcs
  where name = c_npc and portrait_key is null;

  if v_missing > 0 then
    raise exception
      '% "%" row(s) still have a null portrait_key after the update. Rolled back.',
      v_missing, c_npc;
  end if;

  -- ...and the ongoing campaign has one to show. A "where" matching nothing is
  -- a success, so without this a renamed or deleted Rahadin there would pass.
  if not exists (
    select 1
    from public.npcs n
    join public.campaigns c on c.id = n.campaign_id
    where c.name = c_campaign
      and n.name = c_npc
      and n.portrait_key = c_key
  ) then
    raise exception
      'Campaign "%" has no "%" with portrait_key "%". Check the NPC''s name on the NPC page, or the campaign name: select id, name from campaigns order by name;',
      c_campaign, c_npc, c_key;
  end if;
end
$$;

alter table public.npcs enable trigger pin_npc_row;

insert into public.schema_migrations (version) values ('063');

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION -- run one block at a time (the SQL editor renders only the
-- last result set). No ledger rows; each block ends in rollback.
-- ---------------------------------------------------------------------------

-- BLOCK 1 -- the backfill landed, and pin_npc_row came back on. Expect one row
-- per campaign, every one portrait_key = 'rahadin' and pin_enabled = true.
begin;
  select c.name as campaign,
         n.portrait_key,
         (select t.tgenabled = 'O'
          from pg_trigger t
          where t.tgrelid = 'public.npcs'::regclass
            and t.tgname = 'pin_npc_row') as pin_enabled
  from npcs n
  join campaigns c on c.id = n.campaign_id
  where n.name = 'Rahadin'
  order by c.name;
rollback;

-- BLOCK 2 -- a new campaign gets the key from the seed, not the backfill.
-- Expect 6 rows, every one has_home = true; Rahadin's portrait_key 'rahadin',
-- and every other key as 061 left it.
--
-- Two statements, not 049's WITH ... INSERT: rows written by the insert's
-- triggers are invisible to the rest of the same statement (062 BLOCK 3).
begin;
  insert into campaigns (name) values ('063 verification');

  select n.name,
         n.portrait_key,
         n.location_id is not null as has_home
  from npcs n
  join campaigns c on c.id = n.campaign_id
  where c.name = '063 verification'
  order by n.name;
rollback;

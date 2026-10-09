-- db/058_ismark.sql
--
-- Ismark Kolyanovich joins the roster with a portrait. Fourth portrait, same
-- recipe as 049 and 050:
--
--   1. src/assets/portraits/ismark-kolyanovich.webp, committed alongside
--   2. portrait_key = 'ismark-kolyanovich', matching the filename exactly
--
-- THE SOURCE WAS RE-EXPORTED. It arrived as `IsmarK_the_lesser.webp`: a 375x375
-- square with an orange frame (plus a dark outline) baked into its outer ~13px.
-- `object-fit: cover` on the 1.6:1 card band crops top and bottom only, so the
-- frame's left and right edges would have run down both sides of the card. Now
-- 347x347 (10 KB) with the frame cut off, and renamed to the lowercase slug the
-- glob in NPC.tsx looks up -- `IsmarK_the_lesser` would never have matched any
-- key, and a key that matches no file renders an empty band without an error.
--
-- It stays square rather than being cut down to the others' ~0.65 tall ratio,
-- which would have meant losing his shoulders to gain nothing on the card.
-- Checked against npc.css's shared `object-position: 50% 22%`: a square covering
-- a 360x240 band shows rows 7%-74%, hairline to chest, face in the upper half.
-- No CSS change.
--
-- The NPC is named "Ismark Kolyanovich" rather than "Ismark the Lesser" to match
-- how the rest of the repo already refers to him (playerView.ts, the demo
-- fixture). The epithet is an insult from the villagers, which a DM can type into
-- the description at the table; the name is editable, only the key is pinned.
--
-- Two things, in one transaction:
--
--   1. seed_campaign_npcs() is re-created with a fifth row, so every NEW
--      campaign gets Ismark. Fourth version (048, 049, 050, this). The other
--      four rows and the DM-notes join are 050's, verbatim -- edit from this
--      file next time, not an older one. Trigger binding untouched.
--
--   2. "Not Curse of Strahd" gets Ismark, because the trigger only fires on
--      INSERT into campaigns. 051's shape: the name appears once, resolved once
--      with `into strict`, end state asserted.
--
-- HOME IS THE BURGOMASTER'S MANSION, which 048's locations seed already gives
-- every campaign (43.3/88.6, real coordinates -- not a placeholder like Death
-- House's). 051 confirmed the ongoing campaign was created after 048, so it has
-- it. Unlike 051's Death House, a missing mansion RAISES here rather than being
-- inserted: inventing a location is out of scope for a portrait migration, and
-- a homeless Ismark committing silently is exactly what the assertion is for.
--
-- is_revealed: false, the convention for every seeded NPC but Strahd. Flip it
-- from the NPC page's visibility panel when the party knocks on the door.
--
-- portrait_key is set in the INSERT. pin_npc_row is BEFORE UPDATE and pins
-- portrait_key, so insert-then-update would report "UPDATE 1" and change nothing.

begin;

-- ---------------------------------------------------------------------------
-- 1. seed_campaign_npcs() -- fourth version. Only the Ismark row is new.
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
      (
        'Rahadin',
        'Strahd''s Dusk Elf chamberlain and executioner, fiercely loyal and centuries old.',
        'Castle Ravenloft',
        false,
        null::text
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
      -- new in 058. Names src/assets/portraits/ismark-kolyanovich.webp.
      (
        'Ismark Kolyanovich',
        'Son of the late burgomaster and the village''s acting leader, sworn to protect his sister Ireena.',
        'Burgomaster''s Mansion',
        false,
        'ismark-kolyanovich'
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
-- 2. Backfill the ongoing campaign. 051's shape; one literal, one lookup.
-- ---------------------------------------------------------------------------

do $$
declare
  -- The one place this campaign is named. Nothing below repeats it.
  c_name constant text := 'Not Curse of Strahd';

  v_campaign uuid;
  v_location uuid;
  v_npc      uuid;

  v_npc_home uuid;
  v_npc_key  text;
begin
  select id into strict v_campaign
  from public.campaigns
  where name = c_name;

  -- Plain `into`: a miss is reported by the check below, not by no_data_found,
  -- which the handler at the foot would misreport as a missing campaign.
  select id into v_location
  from public.locations
  where campaign_id = v_campaign
    and name = 'Burgomaster''s Mansion'
    and map_key = 'village-of-barovia';

  if v_location is null then
    raise exception
      'Campaign "%" has no Burgomaster''s Mansion on the village map. 048 seeds it; this campaign predates that or it was deleted. Restore it first.',
      c_name;
  end if;

  select id into v_npc
  from public.npcs
  where campaign_id = v_campaign and name = 'Ismark Kolyanovich';

  if v_npc is null then
    insert into public.npcs
      (campaign_id, name, description, location_id, is_revealed, portrait_key)
    values
      (v_campaign,
       'Ismark Kolyanovich',
       'Son of the late burgomaster and the village''s acting leader, sworn to protect his sister Ireena.',
       v_location, false, 'ismark-kolyanovich')
    returning id into v_npc;

    raise notice 'Ismark inserted.';
  else
    raise notice 'Ismark already present; nothing inserted.';
  end if;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select location_id, portrait_key into v_npc_home, v_npc_key
  from public.npcs
  where id = v_npc;

  if v_npc_home is distinct from v_location or v_npc_key is distinct from 'ismark-kolyanovich' then
    raise exception
      'Ismark is wrong in campaign "%": home = %, expected %; portrait_key = %, expected ''ismark-kolyanovich''. Rolled back -- if he was added by hand, pin_npc_row blocks fixing portrait_key by UPDATE; delete the row and re-run.',
      c_name, v_npc_home, v_location, coalesce(v_npc_key, 'null');
  end if;
exception
  when no_data_found then
    raise exception
      'No campaign is named "%". Run: select id, name from campaigns order by name; then correct c_name -- it is the only occurrence.',
      c_name;
  when too_many_rows then
    raise exception
      'More than one campaign is named "%". Replace the c_name lookup with the campaign''s uuid.',
      c_name;
end
$$;

insert into public.schema_migrations (version) values ('058');

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION -- run one block at a time (the SQL editor renders only the
-- last result set). No ledger rows; each block ends in rollback.
-- ---------------------------------------------------------------------------

-- BLOCK 1 -- the ongoing campaign's roster. Expect 5 rows, all with a home:
-- Ismark Kolyanovich at Burgomaster's Mansion with 'ismark-kolyanovich',
-- Lancelot, Rahadin and Rose and Thorn hidden, Strahd revealed, a portrait on
-- everyone but Rahadin.
begin;
  select n.name,
         n.is_revealed,
         n.portrait_key,
         l.name as home
  from npcs n
  join campaigns c on c.id = n.campaign_id
  left join locations l on l.id = n.location_id
  where c.name = 'Not Curse of Strahd'
  order by n.name;
rollback;

-- BLOCK 2 -- a new campaign gets Ismark from the seed function. Expect 5 rows,
-- all has_home = true. has_home = false on anyone means the two campaign
-- triggers fired out of order (see 048 on trigger-name sort order).
begin;
  with new_campaign as (
    insert into campaigns (name) values ('058 verification')
    returning id
  )
  select n.name,
         n.is_revealed,
         n.portrait_key,
         n.location_id is not null as has_home
  from npcs n
  join new_campaign c on c.id = n.campaign_id
  order by n.name;
rollback;

-- db/059_ireena.sql
--
-- Ireena Kolyanovich joins the roster with a portrait. Same recipe as 058:
--
--   1. src/assets/portraits/ireena-kolyanovich.webp, committed alongside
--   2. portrait_key = 'ireena-kolyanovich', matching the filename exactly
--
-- RUN 058 FIRST. The seed function below is 058's body plus one row; run this
-- without 058 and new campaigns still get Ismark (he is in this body), but the
-- ongoing campaign would not, and 058 would then be the one out of order.
--
-- THE SOURCE WAS RE-EXPORTED. It arrived as `Ireenaredlores.jpeg`, a 710x1000
-- full-length figure with the artist's credit (patreon.com/calebisdrawing)
-- lettered across the top. The credit was asked to stay visible, and that
-- decided the crop: npc.css's shared `object-position: 50% 22%` on a tall image
-- shows a band starting ~12% down, which would cut the credit off the card while
-- keeping it only in the lightbox. So this one is cropped LANDSCAPE instead --
-- source (8, 0) to (568, 430), the credit through her belt -- and scaled to
-- 460x353 (12 KB). At that ratio the card band starts 8px from the top: the
-- credit, her face and her shoulders are all on the card, and the lightbox shows
-- the same. The cost is that she is smaller in the band than the head-and-
-- shoulders portraits, and sits right of centre because the credit fills the
-- left. No CSS change.
--
-- Two homes, on purpose:
--
--   - NEW campaigns: 'Village of Barovia', the region-map pin, where the
--     adventure finds her.
--   - "Not Curse of Strahd": 'Vallaki', where she is in the ongoing game.
--
-- Both are region-map ('barovia') locations every campaign gets from 048's
-- locations seed. The seed function resolves homes by name alone, the way every
-- prior row does; the backfill scopes by map_key as well, as 058's does.
--
-- is_revealed: false, the convention for every seeded NPC but Strahd.
--
-- portrait_key is set in the INSERT; pin_npc_row is BEFORE UPDATE and pins it.

begin;

-- ---------------------------------------------------------------------------
-- 1. seed_campaign_npcs() -- fifth version (048, 049, 050, 058, this). Only the
--    Ireena row is new; everything else is 058's, verbatim.
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
      (
        'Ismark Kolyanovich',
        'Son of the late burgomaster and the village''s acting leader, sworn to protect his sister Ireena.',
        'Burgomaster''s Mansion',
        false,
        'ismark-kolyanovich'
      ),
      -- new in 059. Names src/assets/portraits/ireena-kolyanovich.webp.
      (
        'Ireena Kolyanovich',
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
-- 2. Backfill the ongoing campaign -- at Vallaki, not the seed's home.
-- ---------------------------------------------------------------------------

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_name constant text := 'Not Curse of Strahd';
  c_home constant text := 'Vallaki';

  v_campaign uuid;
  v_location uuid;
  v_npc      uuid;

  v_npc_home uuid;
  v_npc_key  text;
begin
  select id into strict v_campaign
  from public.campaigns
  where name = c_name;

  -- Plain `into`: a miss is reported below, not by no_data_found, which the
  -- handler at the foot would misreport as a missing campaign.
  select id into v_location
  from public.locations
  where campaign_id = v_campaign
    and name = c_home
    and map_key = 'barovia';

  if v_location is null then
    raise exception
      'Campaign "%" has no "%" on the region map. 048 seeds it; restore it first.',
      c_name, c_home;
  end if;

  select id into v_npc
  from public.npcs
  where campaign_id = v_campaign and name = 'Ireena Kolyanovich';

  if v_npc is null then
    insert into public.npcs
      (campaign_id, name, description, location_id, is_revealed, portrait_key)
    values
      (v_campaign,
       'Ireena Kolyanovich',
       'Daughter of the late burgomaster and sister to Ismark -- red-haired, sword in hand, and the object of Strahd''s attention.',
       v_location, false, 'ireena-kolyanovich')
    returning id into v_npc;

    raise notice 'Ireena inserted.';
  else
    raise notice 'Ireena already present; nothing inserted.';
  end if;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  --
  -- Note what this catches here specifically: an Ireena already present at
  -- some OTHER location (say, added by hand at the mansion) fails the home
  -- check and rolls back, rather than being reported as "already present".
  -- Move her in the DM editor (location is editable) and re-run.
  select location_id, portrait_key into v_npc_home, v_npc_key
  from public.npcs
  where id = v_npc;

  if v_npc_home is distinct from v_location or v_npc_key is distinct from 'ireena-kolyanovich' then
    raise exception
      'Ireena is wrong in campaign "%": home = %, expected % (%); portrait_key = %, expected ''ireena-kolyanovich''. Rolled back -- if she was added by hand, pin_npc_row blocks fixing portrait_key by UPDATE; delete the row and re-run.',
      c_name, v_npc_home, v_location, c_home, coalesce(v_npc_key, 'null');
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

insert into public.schema_migrations (version) values ('059');

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION -- run one block at a time (the SQL editor renders only the
-- last result set). No ledger rows; each block ends in rollback.
-- ---------------------------------------------------------------------------

-- BLOCK 1 -- the ongoing campaign's roster. Expect 6 rows, all with a home:
-- Ireena Kolyanovich at Vallaki with 'ireena-kolyanovich', Ismark at
-- Burgomaster's Mansion, Lancelot, Rahadin and Rose and Thorn hidden, Strahd
-- revealed, a portrait on everyone but Rahadin.
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

-- BLOCK 2 -- a new campaign gets Ireena from the seed function, at Village of
-- Barovia. Expect 6 rows, all with a home. A null home on anyone means the two
-- campaign triggers fired out of order (see 048 on trigger-name sort order).
begin;
  with new_campaign as (
    insert into campaigns (name) values ('059 verification')
    returning id
  )
  select n.name,
         n.is_revealed,
         n.portrait_key,
         l.name as home
  from npcs n
  join new_campaign c on c.id = n.campaign_id
  left join locations l on l.id = n.location_id
  order by n.name;
rollback;

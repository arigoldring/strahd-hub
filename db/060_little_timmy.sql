-- db/060_little_timmy.sql
--
-- Little Timmy joins ONE campaign's roster with a portrait. Same recipe as
-- 058/059, minus the seed function: he is this table's character, not the
-- adventure's, so new campaigns do not get him. seed_campaign_npcs() is
-- untouched and stays at 059's body.
--
--   1. src/assets/portraits/little-timmy.webp, committed alongside
--   2. portrait_key = 'little-timmy', matching the filename exactly
--
-- THE SOURCE WAS RE-EXPORTED. It arrived as `sad_child.webp`: 556x554, the
-- painting inside a round dark-gold frame with transparent corners. The card's
-- `object-fit: cover` band is 1.6:1, so the ring and the corners would have
-- shown on both sides. Cropped to a rectangle inside the circle's inner edge
-- (centre ~278,277, radius ~256): source (76, 168) to (480, 424), 404x256
-- (5 KB), flattened onto black so no transparency survives.
--
-- It is landscape and set low in the circle on purpose. A square crop meeting
-- npc.css's `object-position: 50% 22%` showed hair down to the nose and cut the
-- mouth -- and the tears and the mouth are the whole picture. At 1.58:1 the
-- band shows the full height, forehead through chin, and trims a sliver off
-- each side instead. The price is the top of his hair, in the lightbox too. No
-- CSS change.
--
-- Home: Vallaki (region map). is_revealed: false, the seeded-NPC convention --
-- the party has met him, so flip it from the NPC page whenever you want players
-- to see his card.
--
-- portrait_key is set in the INSERT; pin_npc_row is BEFORE UPDATE and pins it.
--
-- Independent of 058 and 059 -- no shared function body -- so order among the
-- three does not matter, though the ledger will read best run in order.

begin;

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
  where campaign_id = v_campaign and name = 'Little Timmy';

  if v_npc is null then
    insert into public.npcs
      (campaign_id, name, description, location_id, is_revealed, portrait_key)
    values
      (v_campaign,
       'Little Timmy',
       'Boy the party "saved" from the old lady.',
       v_location, false, 'little-timmy')
    returning id into v_npc;

    raise notice 'Little Timmy inserted.';
  else
    raise notice 'Little Timmy already present; nothing inserted.';
  end if;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  --
  -- A Timmy added by hand elsewhere, or without the portrait, fails here and
  -- rolls back instead of being reported as "already present".
  select location_id, portrait_key into v_npc_home, v_npc_key
  from public.npcs
  where id = v_npc;

  if v_npc_home is distinct from v_location or v_npc_key is distinct from 'little-timmy' then
    raise exception
      'Little Timmy is wrong in campaign "%": home = %, expected % (%); portrait_key = %, expected ''little-timmy''. Rolled back -- if he was added by hand, pin_npc_row blocks fixing portrait_key by UPDATE; delete the row and re-run.',
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

insert into public.schema_migrations (version) values ('060');

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION -- run one block at a time (the SQL editor renders only the
-- last result set). No ledger rows; each block ends in rollback.
-- ---------------------------------------------------------------------------

-- BLOCK 1 -- he is in the ongoing campaign and nowhere else. Expect exactly one
-- row: 'Not Curse of Strahd', home 'Vallaki', portrait_key 'little-timmy',
-- is_revealed false. A second row in another campaign means someone added him
-- by hand there; this file only ever touches one.
begin;
  select c.name as campaign,
         n.name,
         n.description,
         l.name as home,
         n.is_revealed,
         n.portrait_key
  from npcs n
  join campaigns c on c.id = n.campaign_id
  left join locations l on l.id = n.location_id
  where n.name = 'Little Timmy'
  order by c.name;
rollback;

-- BLOCK 2 -- a new campaign does NOT get him. Expect zero rows.
begin;
  with new_campaign as (
    insert into campaigns (name) values ('060 verification')
    returning id
  )
  select n.name
  from npcs n
  join new_campaign c on c.id = n.campaign_id
  where n.name = 'Little Timmy';
rollback;

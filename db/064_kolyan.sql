-- db/064_kolyan.sql
--
-- Kolyan Indirovich, burgomaster of the Village of Barovia, joins the roster
-- with a portrait. First time he is an NPC at all; until now he existed only
-- in the Burgomaster's Mansion's text (043/048). Same recipe as 058/059:
--
--   1. src/assets/portraits/kolyan-indirovich.webp, committed alongside
--   2. portrait_key = 'kolyan-indirovich', matching the filename exactly
--
-- Name spelled as 048's mansion description already spells it.
--
-- THE SOURCE WAS RE-EXPORTED. It arrived as `Kolyan_Indirovich.jpeg`, 1000x800,
-- by the same artist as Ireena, with the credit (www.patreon.com/calebisdrawing)
-- lettered across the top-left. Following 061, the credit moves out of the
-- picture and onto the description's first line. Unlike Ireena's, it sits on
-- plain white clear of the figure, so it was painted over (white, 0,0 to
-- 448x54) rather than cropped off -- the framing is untouched. The artist's
-- signature, bottom right, stays: npc.css's `object-position: 50% 22%` crops
-- it off the card, and the lightbox keeps it. Scaled to 450x360 (18 KB).
-- Landscape, like Little Timmy's, so the 1.6:1 band keeps nearly the whole
-- height -- bandage through the gold clasps. No CSS change.
--
-- ALIVE, ON PURPOSE. The module has him dead the night the party arrives; this
-- table runs him alive (CoS Reloaded and the base game, mixed). is_dead (062)
-- keeps its default of false, so neither part below mentions it -- tick it in
-- the NPC editor when he dies. Note that 048's seeded mansion text still says
-- "the late Burgomaster" and its DM note says he died; this file leaves both
-- alone.
--
-- HOME: 'Village of Barovia', the region-map pin ('barovia'), in both new
-- campaigns and the ongoing one -- Ireena's seed home, not Ismark's mansion.
--
-- is_revealed: false, the convention for every seeded NPC but Strahd.
--
-- Two parts, one transaction:
--
--   1. seed_campaign_npcs() -- eighth version (048, 049, 050, 058, 059, 061,
--      063, this). Only the Kolyan row is new; everything else is 063's,
--      verbatim.
--   2. "Not Curse of Strahd" gets Kolyan, because the trigger only fires on
--      INSERT into campaigns. One campaign, not every one: 058/059's shape.
--
-- portrait_key is set in the INSERT; pin_npc_row is BEFORE UPDATE and pins it,
-- so no trigger needs disabling here (contrast 063).
--
-- RUN 063 FIRST. The seed body below includes Rahadin's key; run this alone
-- and new campaigns get it anyway, but 063's backfill would then be the one
-- out of order.

begin;

-- ---------------------------------------------------------------------------
-- 1. seed_campaign_npcs() -- eighth version. Edit from this one next time.
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
      ),
      -- new in 064. Names src/assets/portraits/kolyan-indirovich.webp.
      (
        'Kolyan Indirovich',
        'Portrait credit to www.patreon.com/calebisdrawing' || chr(10) ||
        'Burgomaster of the Village of Barovia, and father of Ismark and Ireena.',
        'Village of Barovia',
        false,
        'kolyan-indirovich'
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
-- 2. Backfill the ongoing campaign. 059's shape; each literal named once.
-- ---------------------------------------------------------------------------

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_name constant text := 'Not Curse of Strahd';
  c_home constant text := 'Village of Barovia';
  c_npc  constant text := 'Kolyan Indirovich';
  c_key  constant text := 'kolyan-indirovich';
  c_desc constant text :=
    'Portrait credit to www.patreon.com/calebisdrawing' || chr(10) ||
    'Burgomaster of the Village of Barovia, and father of Ismark and Ireena.';

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
  where campaign_id = v_campaign and name = c_npc;

  if v_npc is null then
    insert into public.npcs
      (campaign_id, name, description, location_id, is_revealed, portrait_key)
    values
      (v_campaign, c_npc, c_desc, v_location, false, c_key)
    returning id into v_npc;

    raise notice '% inserted.', c_npc;
  else
    raise notice '% already present; nothing inserted.', c_npc;
  end if;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  -- A Kolyan already present somewhere else (added by hand at the mansion,
  -- say) fails the home check and rolls back rather than passing as "already
  -- present". Move him in the DM editor and re-run.
  select location_id, portrait_key into v_npc_home, v_npc_key
  from public.npcs
  where id = v_npc;

  if v_npc_home is distinct from v_location or v_npc_key is distinct from c_key then
    raise exception
      '% is wrong in campaign "%": home = %, expected % (%); portrait_key = %, expected %. Rolled back -- if he was added by hand, pin_npc_row blocks fixing portrait_key by UPDATE; delete the row and re-run.',
      c_npc, c_name, v_npc_home, v_location, c_home, coalesce(v_npc_key, 'null'), c_key;
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

insert into public.schema_migrations (version) values ('064');

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION -- run one block at a time (the SQL editor renders only the
-- last result set). No ledger rows; each block ends in rollback.
-- ---------------------------------------------------------------------------

-- BLOCK 1 -- the ongoing campaign's Kolyan. Expect one row: home 'Village of
-- Barovia', portrait_key 'kolyan-indirovich', is_revealed false, is_dead
-- false, first_line the credit.
begin;
  select n.name,
         l.name as home,
         n.portrait_key,
         n.is_revealed,
         n.is_dead,
         split_part(n.description, chr(10), 1) as first_line
  from npcs n
  join campaigns c on c.id = n.campaign_id
  left join locations l on l.id = n.location_id
  where c.name = 'Not Curse of Strahd'
    and n.name = 'Kolyan Indirovich';
rollback;

-- BLOCK 2 -- a new campaign gets Kolyan from the seed. Expect 7 rows, every
-- home non-null, Kolyan at 'Village of Barovia' with 'kolyan-indirovich' and
-- is_dead false. A null home on anyone means the two campaign triggers fired
-- out of order (see 048 on trigger-name sort order).
--
-- Two statements, not 059's WITH ... INSERT: rows written by the insert's
-- triggers are invisible to the rest of the same statement (062 BLOCK 3).
begin;
  insert into campaigns (name) values ('064 verification');

  select n.name,
         l.name as home,
         n.portrait_key,
         n.is_revealed,
         n.is_dead
  from npcs n
  join campaigns c on c.id = n.campaign_id
  left join locations l on l.id = n.location_id
  where c.name = '064 verification'
  order by n.name;
rollback;

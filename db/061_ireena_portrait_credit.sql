-- db/061_ireena_portrait_credit.sql
--
-- Ireena's portrait credit moves out of the picture and into her description:
-- in the seed for NEW campaigns, and prepended to the existing row in "Not
-- Curse of Strahd". The portrait itself needs no SQL anywhere -- every Ireena
-- row names the same file by key, so the re-export below reaches every campaign
-- the moment it deploys.
--
-- WHY. 059 kept the artist's credit (www.patreon.com/calebisdrawing) visible by
-- cropping the portrait landscape, credit through belt -- which cut her off at
-- the waist and lost the whole figure. The portrait is now re-exported from the
-- full 710x1000 source: the credit's strip (top 52px) cut off, the same 52px
-- added back as plain white, scaled to 420x592 (17 KB). The padding is not
-- decoration -- without it her head moves up into the ~11% that npc.css's
-- `object-position: 50% 22%` discards on a tall image, and the card band
-- started at her eyebrows. With it, the band runs from the top of her head to
-- her hips. Same file, same key, so no portrait_key change anywhere.
--
-- The credit goes on the description's FIRST LINE, separated by a newline
-- (chr(10)). That only renders as a line break because .npc-card__desc gained
-- `white-space: pre-line` in the same commit; before that the newline collapsed
-- to a space. It is plain text, not a link -- the card does not linkify.
--
-- Two parts, one transaction:
--
--   1. seed_campaign_npcs() -- sixth version (048, 049, 050, 058, 059, this).
--      Only Ireena's description differs from 059; everything else verbatim.
--   2. The ongoing campaign's Ireena gets the credit as a new first line.
--
-- RUN 059 FIRST: part 2 raises if the campaign has no Ireena to update.

begin;

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
      -- changed in 061: credit line first.
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
-- 2. The ongoing campaign's Ireena gets the same credit line, PREPENDED to
--    whatever her description says now -- not replaced, since that row has
--    059's text or whatever the DM has typed since, and neither should be lost.
--
--    A plain UPDATE works here, unlike 049's portrait backfill: pin_npc_row
--    pins id, campaign_id, created_at and portrait_key, and description is not
--    among them. Guarded on the credit already being line one, so a re-run (or
--    the DM having pasted it in by hand first) does not stack two credits.
-- ---------------------------------------------------------------------------

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_name   constant text := 'Not Curse of Strahd';
  c_credit constant text := 'Portrait credit to www.patreon.com/calebisdrawing';

  v_campaign uuid;
  v_npc      uuid;
  v_desc     text;
begin
  select id into strict v_campaign
  from public.campaigns
  where name = c_name;

  -- Plain `into`: a miss is reported below, not by no_data_found, which the
  -- handler at the foot would misreport as a missing campaign.
  select id into v_npc
  from public.npcs
  where campaign_id = v_campaign and name = 'Ireena Kolyanovich';

  if v_npc is null then
    raise exception
      'Campaign "%" has no NPC named "Ireena Kolyanovich". Run 059 first, or check the name on the NPC page.',
      c_name;
  end if;

  update public.npcs
  set description = case
        when nullif(btrim(description), '') is null then c_credit
        else c_credit || chr(10) || description
      end
  where id = v_npc
    and split_part(coalesce(description, ''), chr(10), 1) is distinct from c_credit;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select description into v_desc
  from public.npcs
  where id = v_npc;

  if split_part(coalesce(v_desc, ''), chr(10), 1) is distinct from c_credit then
    raise exception
      'Ireena''s description in "%" does not start with the credit line after the update. Rolled back. Description is: %',
      c_name, coalesce(v_desc, 'null');
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

insert into public.schema_migrations (version) values ('061');

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION -- run one block at a time (the SQL editor renders only the
-- last result set). No ledger rows; each block ends in rollback.
-- ---------------------------------------------------------------------------

-- BLOCK 1 -- a new campaign's Ireena carries the credit on line one. Expect one
-- row: first_line 'Portrait credit to www.patreon.com/calebisdrawing',
-- has_newline true, home 'Village of Barovia', portrait_key
-- 'ireena-kolyanovich'.
begin;
  with new_campaign as (
    insert into campaigns (name) values ('061 verification')
    returning id
  )
  select split_part(n.description, chr(10), 1) as first_line,
         position(chr(10) in n.description) > 0 as has_newline,
         l.name as home,
         n.portrait_key
  from npcs n
  join new_campaign c on c.id = n.campaign_id
  left join locations l on l.id = n.location_id
  where n.name = 'Ireena Kolyanovich';
rollback;

-- BLOCK 2 -- the ongoing campaign's Ireena. Expect one row: first_line the
-- credit, rest the description she had before (059's text unless edited),
-- home 'Vallaki'.
begin;
  select split_part(n.description, chr(10), 1) as first_line,
         substr(n.description, position(chr(10) in n.description) + 1) as rest,
         l.name as home
  from npcs n
  join campaigns c on c.id = n.campaign_id
  left join locations l on l.id = n.location_id
  where c.name = 'Not Curse of Strahd'
    and n.name = 'Ireena Kolyanovich';
rollback;

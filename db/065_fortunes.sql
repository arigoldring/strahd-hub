-- db/065_fortunes.sql
--
-- Madam Eva's reading. Three fortunes per campaign -- the Tome of Strahd, the
-- Holy Symbol of Ravenkind, the Sunsword -- behind a Fortunes page whose nav
-- link stays hidden from players until the DM reveals the reading.
--
-- THE TEXT LIVES HERE, NOT IN src/data. Maps (042) put their definitions in
-- code and only the reveal state in the database, and CLAUDE.md records that
-- as an exception: anything in src/ ships in the bundle every player
-- downloads. A fortune is nothing BUT its text, and the text says where the
-- Sunsword is. So the rows carry the text and RLS withholds them, and a player
-- in devtools gets an empty array until the reading -- locations' shape, not
-- maps'.
--
-- THE SAME THREE FORTUNES IN EVERY CAMPAIGN. The DM fixes where the artifacts
-- are, so the text is not per-campaign content. It is still per-campaign
-- ROWS, because the reveal and the found marker are per-campaign state, and
-- one row per card keeps RLS a plain row filter.
--
-- The text is written once, in insert_campaign_fortunes() below. Both the
-- seed trigger and the backfill call it, so there is no second copy to drift
-- (CLAUDE.md: a literal that must agree across statements appears once).
--
-- ---------------------------------------------------------------------------
-- campaign_fortunes -- the decisions
-- ---------------------------------------------------------------------------
--
--   card                1, 2, 3 in reading order (tome, symbol, sword). It is
--                        the row's identity within a campaign, the conflict
--                        target for the backfill, and the sort order -- one
--                        column, three jobs, no slot/position pair to disagree.
--
--   lines text[]        one element per spoken line, rendered as separate
--                        paragraphs. feats.benefits' shape (039). The one
--                        column the DM edits from the app. No default, and a
--                        CHECK refuses an empty array or a blank line: a
--                        fortune with no text isn't a state anything renders.
--
--   is_revealed         one per row, but the client only ever flips all three
--                        together ("Madam Eva has read"). A column on
--                        campaigns was the alternative: one flag, no way for
--                        three rows to disagree. Rejected because the read
--                        policy would then need a join to campaigns, and
--                        campaigns' UPDATE policy is the DM's rename path --
--                        this keeps the feature out of that table entirely.
--                        Per-row also leaves per-card reveals open later at no
--                        schema cost.
--
--   is_found            DM-set, public once revealed. The party knows when
--                        they have the Sunsword.
--
-- RLS. The read is 018's locations shape:
--   is_campaign_dm(campaign_id) or (is_revealed and is_campaign_member(...))
-- and here, unlike 042, that is correct: the client has no fallback when a
-- row is missing. Absence means "not read yet" -- see Reveal gating in
-- CLAUDE.md for why that is the question to ask before copying this.
--
-- UPDATE is DM-only, USING and WITH CHECK both. No INSERT or DELETE policy:
-- rows only ever come from the seed, which runs as the table owner. A fourth
-- policy on this table is a bug; BLOCK 0 counts them.
--
-- pin_fortune_row pins id, campaign_id, card, created_at and title. A DM of
-- two campaigns passes is_campaign_dm on both, so without it an update could
-- move a card between them (053's reasoning for pin_item_row). title is
-- pinned because the app edits the text only, and RLS can't restrict columns,
-- so the trigger is where "only the text" is actually enforced. Writable, by
-- design: lines, is_revealed, is_found.
--
-- ---------------------------------------------------------------------------
-- seeding
-- ---------------------------------------------------------------------------
--
-- seed_fortunes_on_campaign_create is a third AFTER INSERT trigger on
-- campaigns. It sorts FIRST ('seed_f' < 'seed_l' < 'seed_n'), and that is fine
-- because it reads no locations or NPCs. If a later version ever looks up a
-- location by name, it has to be renamed to sort after the locations seed.
--
-- BACKFILL: EVERY CAMPAIGN, like 049 and unlike 051. The text is identical in
-- every copy, and every backfilled row starts hidden, so a campaign that gets
-- fortunes it never uses shows them to no one. on conflict (campaign_id, card)
-- do nothing makes the helper idempotent, which is safe here because the
-- unique constraint exists (npcs has none, which is why 051 needs `not
-- exists`).
--
-- THE TOME AND HOLY SYMBOL TEXTS ARE DRAFTS. The Sunsword's four lines are
-- the DM's own, verbatim. The function body is the text NEW campaigns start
-- with; the Edit button on each card rewrites one campaign's copy and nothing
-- else. So edit the body here before running this if the wording should be
-- every campaign's, and use the app for one campaign's. Changing a title after
-- this has run means disabling pin_fortune_row inside the fixing migration.

begin;

create table public.campaign_fortunes (
  id          uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  card        smallint not null,
  title       text not null,
  lines       text[] not null,
  is_revealed boolean not null default false,
  is_found    boolean not null default false,
  created_at  timestamptz not null default now(),

  constraint campaign_fortunes_card_check check (card between 1 and 3),
  constraint campaign_fortunes_title_check
    check (title = trim(title) and title <> '' and length(title) <= 80),
  -- Editable from the app, so bounded: 1-8 lines, none blank, ~2000 chars.
  -- updateFortuneLines trims and drops blank lines first, so this is the
  -- backstop, not what a DM normally meets.
  constraint campaign_fortunes_lines_check
    check (cardinality(lines) between 1 and 8
           and not ('' = any(lines))
           and length(array_to_string(lines, '')) <= 2000),
  -- Leads on campaign_id, so it is also the only index getFortunes needs.
  constraint campaign_fortunes_campaign_card_key unique (campaign_id, card)
);

alter table public.campaign_fortunes enable row level security;

create policy "read fortunes once revealed"
  on public.campaign_fortunes for select to authenticated
  using (
    public.is_campaign_dm(campaign_id)
    or (is_revealed and public.is_campaign_member(campaign_id))
  );

create policy "dms update fortunes"
  on public.campaign_fortunes for update to authenticated
  using (public.is_campaign_dm(campaign_id))
  with check (public.is_campaign_dm(campaign_id));

-- No INSERT, no DELETE -- see the header.

create or replace function public.pin_fortune_row()
returns trigger
language plpgsql
security invoker
set search_path to 'public'
as $function$
begin
  new.id          := old.id;
  new.campaign_id := old.campaign_id;
  new.card        := old.card;
  new.created_at  := old.created_at;
  new.title       := old.title;
  return new;
end;
$function$;

create trigger pin_fortune_row
  before update on public.campaign_fortunes
  for each row execute function public.pin_fortune_row();

-- The one place the fortunes are written. Invoker: it only ever runs as the
-- table owner (from the seed trigger, or this migration), and a client calling
-- it would be refused by the missing INSERT policy anyway. Revoked regardless,
-- so it is not part of the RPC surface.
create or replace function public.insert_campaign_fortunes(p_campaign_id uuid)
returns void
language plpgsql
security invoker
set search_path to 'public'
as $function$
begin
  insert into campaign_fortunes (campaign_id, card, title, lines)
  values
    -- DRAFT. The Tome of Strahd, in the Amber Temple.
    (p_campaign_id, 1, 'A Forgotten History', array[
      'I see a book of secrets, bound in leather and regret -- the confession of a lord who traded his soul, and wrote down the price.',
      'It lies where the snow never melts, in a temple sealed in amber, where dead gods whisper from behind golden walls.',
      'Seek not the vaults where the dark powers sleep, but the room where the wizards kept their learning -- knowledge hoarded, never shared.',
      'Among frozen pages, beneath the cold gaze of those who came for power and stayed forever, his story waits to be read aloud.'
    ]),
    -- DRAFT. The Holy Symbol of Ravenkind, in the Abbey of Saint Markovia.
    (p_campaign_id, 2, 'A Light of Faith', array[
      'I see a sun upon a chain -- a relic cold and pale, that once burned the night away in the hands of the faithful.',
      'It rests above the village that guards the western pass, in the house of a saint who healed the sick and was slain for it.',
      'Climb past the gate and the blessed pool, to where the abbot tends his broken flock and stitches together a perfect bride.',
      'Where madness sings in the cells and the bells no longer ring, the light waits for a hand that still believes.'
    ]),
    -- The DM's own text, verbatim.
    (p_campaign_id, 3, 'A Powerful Weapon', array[
      'I see a weapon of pure dawn -- a sword without a blade, a promise without a hand to wield it. Its light is not forged in fire, but in sacrifice.',
      'It waits in the house of the devil, where war once dressed itself in steel and still stands watch without breath or heartbeat.',
      'Look not to the throne room, nor the crypt, but to the chamber of command -- where he planned his conquests and keeps the trophies of victory.',
      'Beside the silent knight that never sleeps, there lies the broken sun -- hidden, waiting, remembering what it was made to kill.'
    ])
  on conflict (campaign_id, card) do nothing;
end;
$function$;

revoke execute on function public.insert_campaign_fortunes(uuid)
  from public, anon, authenticated;

create or replace function public.seed_campaign_fortunes()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  perform insert_campaign_fortunes(NEW.id);
  return NEW;
end;
$function$;

revoke execute on function public.seed_campaign_fortunes()
  from public, anon, authenticated;

create trigger seed_fortunes_on_campaign_create
  after insert on public.campaigns
  for each row execute function public.seed_campaign_fortunes();

-- Backfill every existing campaign, then assert the end state: every campaign
-- has exactly cards 1-3. Do not demote to a notice.
do $$
declare
  v_short int;
begin
  perform public.insert_campaign_fortunes(c.id) from public.campaigns c;

  select count(*) into v_short
  from public.campaigns c
  where (select count(*) from public.campaign_fortunes f
         where f.campaign_id = c.id) <> 3;

  if v_short > 0 then
    raise exception '% campaign(s) do not have exactly three fortunes. Rolled back.', v_short;
  end if;
end
$$;

insert into public.schema_migrations (version) values ('065');

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION -- run one block at a time (the SQL editor renders only the
-- last result set). No ledger rows; each block ends in rollback.
-- ---------------------------------------------------------------------------

-- BLOCK 0 -- table, RLS, ledger, policies. Expect three rows:
--   0a  all true.
--   0b  exactly two policies, cmd 'r' and 'w'. An 'a' or 'd' is a bug.
--   0c  three triggers on campaigns: seed_fortunes_, seed_locations_,
--       seed_npcs_on_campaign_create.
begin;
  select '0a: table and ledger' as check,
         jsonb_build_object(
           'table_exists', to_regclass('public.campaign_fortunes') is not null,
           'rls_enabled',  (select relrowsecurity from pg_class
                            where oid = to_regclass('public.campaign_fortunes')),
           'ledger_row',   exists (select 1 from public.schema_migrations
                                   where version = '065')
         ) as result
  union all
  select '0b: policies',
         (select jsonb_agg(jsonb_build_object('name', polname, 'cmd', polcmd)
                           order by polname)
          from pg_policy
          where polrelid = to_regclass('public.campaign_fortunes'))
  union all
  select '0c: campaign triggers',
         (select jsonb_agg(tgname order by tgname)
          from pg_trigger
          where tgrelid = to_regclass('public.campaigns') and not tgisinternal);
rollback;

-- BLOCK 1 -- the backfill. Expect one row per campaign: fortunes 3,
-- revealed 0, found 0.
begin;
  select c.name as campaign,
         count(f.id)                              as fortunes,
         count(*) filter (where f.is_revealed)    as revealed,
         count(*) filter (where f.is_found)       as found
  from campaigns c
  left join campaign_fortunes f on f.campaign_id = c.id
  group by c.name
  order by c.name;
rollback;

-- BLOCK 2 -- a new campaign gets three, hidden. Expect three rows, cards 1-3,
-- is_revealed false, four lines each. Two statements, for 062 BLOCK 3's
-- reason: rows written by the insert's triggers are invisible to the rest of
-- a single WITH ... INSERT statement.
begin;
  insert into campaigns (name) values ('065 verification');

  select f.card, f.title, f.is_revealed, cardinality(f.lines) as lines
  from campaign_fortunes f
  join campaigns c on c.id = f.campaign_id
  where c.name = '065 verification'
  order by f.card;
rollback;

-- BLOCK 3 -- the gate, as a player of 'Not Curse of Strahd'. Expect one row:
-- player non-empty, before_reveal 0, update_refused 0, after_reveal 3.
--
-- 041's impersonation idiom. Picks the campaign's first player member, so an
-- empty `player` means the campaign has none and the counts prove nothing.
-- The reveal in the middle runs as the owner (reset role), standing in for
-- the DM's write, then switches back.
begin;
  select set_config('verification.campaign',
                    (select id::text from campaigns
                     where name = 'Not Curse of Strahd'),
                    true),
         set_config('verification.player',
                    (select m.user_id::text from campaign_members m
                     join campaigns c on c.id = m.campaign_id
                     where c.name = 'Not Curse of Strahd' and m.role = 'player'
                     order by m.user_id limit 1),
                    true);

  select set_config('request.jwt.claims',
                    json_build_object('sub', current_setting('verification.player'),
                                      'role', 'authenticated')::text,
                    true);
  set local role authenticated;

  select set_config('verification.before',
                    (select count(*)::text from campaign_fortunes
                     where campaign_id = current_setting('verification.campaign')::uuid),
                    true);

  -- The player revealing it themselves: USING excludes every row, so this is
  -- a clean zero-row update, not an error.
  with u as (
    update campaign_fortunes set is_revealed = true
    where campaign_id = current_setting('verification.campaign')::uuid
    returning 1
  )
  select set_config('verification.refused', (select count(*)::text from u), true);

  reset role;
  update campaign_fortunes set is_revealed = true
  where campaign_id = current_setting('verification.campaign')::uuid;
  set local role authenticated;

  select current_setting('verification.player')  as player,
         current_setting('verification.before')  as before_reveal,
         current_setting('verification.refused') as update_refused,
         (select count(*) from campaign_fortunes
          where campaign_id = current_setting('verification.campaign')::uuid)
                                                 as after_reveal;
rollback;

-- BLOCK 4 -- pin_fortune_row: what an edit may and may not change. Expect one
-- row: card 1, same_campaign true, title 'A Forgotten History' (pinned), and
-- lines {Edited.} (writable -- the Edit button depends on it). An edited
-- title means title isn't pinned; old lines mean lines is.
begin;
  update campaign_fortunes f
  set card = 2,
      campaign_id = gen_random_uuid(),
      title = 'Renamed',
      lines = array['Edited.']
  from campaigns c
  where c.id = f.campaign_id
    and c.name = 'Not Curse of Strahd'
    and f.card = 1
  returning f.card, f.campaign_id = c.id as same_campaign, f.title, f.lines;
rollback;

-- BLOCK 5 -- the lines CHECK refuses blank text. Expect one row, refused =
-- 'yes (23514)'. Caught and reported as a row (039's shape), not left red.
begin;
  do $$
  begin
    update campaign_fortunes f
    set lines = array['']
    from campaigns c
    where c.id = f.campaign_id
      and c.name = 'Not Curse of Strahd'
      and f.card = 1;
    perform set_config('verification.refused', 'NO -- blank lines accepted', true);
  exception when check_violation then
    perform set_config('verification.refused', 'yes (23514)', true);
  end
  $$;
  select current_setting('verification.refused') as refused;
rollback;

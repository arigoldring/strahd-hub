-- db/127_fortunes_five.sql
--
-- Madam Eva's real reading replaces 065's drafts: five cards, not three.
-- Three artifacts (the Sunsword, the Tome of Strahd, the Holy Symbol of
-- Ravenkind) in the order the verse itself gives them ("First, a sword ...
-- Next, a book ... And last ..."), then two fortunes about the party's
-- companions, Lancelot and Timmy. The text is the DM's own, verbatim, with the
-- narration (the vision of the hilt, "She looks at the bag, staff") left out:
-- the page is a record of what she said.
--
-- AN ELEMENT OF lines IS NOW A STANZA, NOT A SENTENCE. The new text is verse.
-- Each array element holds one stanza, its lines joined by a newline, and the
-- page renders it with white-space: pre-line. 065's CHECK (1-8 elements, none
-- blank, 2000 chars) still fits -- the longest card is three stanzas -- so it
-- is unchanged. The column keeps its name: renaming it would need the 095/096
-- expand-then-contract dance for one word. The client calls the field
-- `stanzas`, which is what the FortuneRow/Fortune split is for.
--
-- STANZAS ARE BUILT WITH concat_ws(E'\n', ...), NOT MULTI-LINE LITERALS. The
-- repo's .sql files are CRLF, and a dollar-quoted literal spanning lines would
-- carry the \r into the data. Building each stanza from one literal per line
-- means the file's line endings can't reach the table. The end-state assertion
-- checks for \r anyway.
--
-- is_artifact. "Found" means something for a sword and nothing for a boy, so
-- the DM's checkbox and the players' badge appear only on artifact cards. A
-- boolean rather than a kind text column: Found is the only behaviour that
-- hangs off it, and a boolean has no client tuple to keep in step with a CHECK.
-- No default once the column exists, so every insert says which it is. A CHECK
-- makes a found companion unrepresentable. Pinned in pin_fortune_row, because
-- that trigger is a blocklist and a new column is client-writable until named
-- there (CLAUDE.md, Gotchas).
--
-- DELETE AND RESEED, NOT UPDATE. Checked 2026-11-05: every campaign held 065's
-- three cards, none revealed, none found, none edited in the app. So the
-- existing rows are deleted and insert_campaign_fortunes() runs again for
-- every campaign. That keeps the text in one place (the function body), and
-- changes the titles without disabling pin_fortune_row. Nothing references
-- campaign_fortunes, so the delete cascades nowhere. A guard refuses to run if
-- any card has been revealed or marked found: that is state a delete would
-- destroy, and a re-run after the reading has started must fail, not wipe it.
-- Text edited in the app before the reveal is NOT guarded, and would be lost.
--
-- Lancelot's last line, "lasts though the end", is the DM's wording as given.
-- Fix it in the app for one campaign, or here for new ones.

begin;

alter table public.campaign_fortunes
  drop constraint campaign_fortunes_card_check,
  add constraint campaign_fortunes_card_check check (card between 1 and 5);

alter table public.campaign_fortunes
  add column is_artifact boolean not null default true;
alter table public.campaign_fortunes
  alter column is_artifact drop default;
alter table public.campaign_fortunes
  add constraint campaign_fortunes_found_artifact_check
    check (is_artifact or not is_found);

-- 065's body, plus is_artifact.
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
  new.is_artifact := old.is_artifact;
  return new;
end;
$function$;

-- Still the one place the fortunes are written. 065's grants stand: create or
-- replace keeps the revoke.
create or replace function public.insert_campaign_fortunes(p_campaign_id uuid)
returns void
language plpgsql
security invoker
set search_path to 'public'
as $function$
begin
  insert into campaign_fortunes (campaign_id, card, title, is_artifact, lines)
  values
    -- The Sunsword, in Castle Ravenloft.
    (p_campaign_id, 1, 'The Sword of Light', true, array[
      concat_ws(E'\n',
        $$First, a sword. Not steel, but light,$$,
        $$a blade of sun to burn the night,$$,
        $$the one thing the devil truly fears.$$,
        $$So he’s kept it locked away for years,$$,
        $$inside his castle, close at hand.$$,
        $$You’ve sat at his table, yes? Then understand:$$,
        $$you walked much nearer than you knew$$,
        $$to the very thing he hides from you.$$),
      concat_ws(E'\n',
        $$It’s hidden well, and guarded deep$$,
        $$by a watcher who will never sleep.$$,
        $$And why should it rest? It has no need.$$,
        $$There’s no one inside to sleep… or bleed$$)
    ]),
    -- The Tome of Strahd.
    (p_campaign_id, 2, 'The Devil’s Own Words', true, array[
      concat_ws(E'\n',
        $$Next, a book. Not prayers, no.$$,
        $$Confessions, from so long ago,$$,
        $$the devil’s tale in his own hand,$$,
        $$from before the curse fell on this land:$$,
        $$what he wanted, what he took,$$,
        $$what it cost him. Read that book.$$,
        $$For knowing him, I tell you true,$$,
        $$shows where a blade might cut him through.$$)
    ]),
    -- The Holy Symbol of Ravenkind.
    (p_campaign_id, 3, 'The Sun in the Hand', true, array[
      concat_ws(E'\n',
        $$And last, a different kind of light:$$,
        $$a sun you can hold against the night.$$,
        $$Long before churches, so it’s said,$$,
        $$a great raven brought it, wings outspread:$$,
        $$a sun of white metal, a crystal heart$$,
        $$that burns like dawn when the shadows part.$$,
        $$The devil’s children, the ones who drink,$$,
        $$cannot bear it. Watch them shrink.$$),
      concat_ws(E'\n',
        $$Go west, past where the forest ends,$$,
        $$to gates that won’t open for strangers or friends$$,
        $$unless the village says they may.$$,
        $$In a house of the faithful, where still they pray$$,
        $$for a dawn that never comes. It’s there.$$,
        $$Say your prayers. But have a care.$$,
        $$Don’t linger. Don’t you dare$$),
      concat_ws(E'\n',
        $$And those pretty gifts from the devil’s hand?$$,
        $$So kind. So generous. Understand:$$,
        $$what the devil gives, he never lets go.$$,
        $$Use it against him… and then you’ll know.$$)
    ]),
    -- Lancelot.
    (p_campaign_id, 4, 'A Faithful Friend', false, array[
      concat_ws(E'\n',
        $$And this one. What a faithful friend.$$,
        $$For his master he would break, would bend,$$,
        $$would bleed and break and fall down dead.$$,
        $$But dry your eyes. Don’t fill with dread.$$,
        $$For loyalty like his, lasts though the end$$)
    ]),
    -- Timmy.
    (p_campaign_id, 5, 'The Little One', false, array[
      concat_ws(E'\n',
        $$And the little one… Timmy. Yes.$$,
        $$Seven summers. No more, no less.$$,
        $$Already he’s felt the witches’ fire.$$,
        $$You pulled him free. Brave. Good. But dire$$,
        $$is the debt when a meal is snatched away.$$,
        $$The hungry ones don’t forget. And they$$,
        $$are not the only ones who feed.$$,
        $$The dark has other mouths. Take heed.$$,
        $$A storm is gathering over his head.$$,
        $$Love him now, while he’s not yet…$$)
    ])
  on conflict (campaign_id, card) do nothing;
end;
$function$;

-- Guard, replace, then assert the end state: every campaign has exactly cards
-- 1-5, artifacts on 1-3 only, nothing revealed, no \r. Do not demote to a
-- notice.
do $$
declare
  v_started int;
  v_bad     int;
begin
  select count(*) into v_started
  from public.campaign_fortunes
  where is_revealed or is_found;

  if v_started > 0 then
    raise exception '% fortune(s) already revealed or found; refusing to replace them. Rolled back.', v_started;
  end if;

  delete from public.campaign_fortunes;
  perform public.insert_campaign_fortunes(c.id) from public.campaigns c;

  select count(*) into v_bad
  from public.campaigns c
  where (select array_agg(f.card order by f.card)
         from public.campaign_fortunes f
         where f.campaign_id = c.id) is distinct from array[1,2,3,4,5]::smallint[]
     or exists (select 1 from public.campaign_fortunes f
                where f.campaign_id = c.id
                  and (f.is_artifact <> (f.card <= 3)
                       or f.is_revealed
                       or array_to_string(f.lines, '') like '%' || chr(13) || '%'));

  if v_bad > 0 then
    raise exception '% campaign(s) do not have the five fortunes as written. Rolled back.', v_bad;
  end if;
end
$$;

insert into public.schema_migrations (version) values ('127');

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION -- run one block at a time (the SQL editor renders only the
-- last result set). No ledger rows; each block ends in rollback.
-- ---------------------------------------------------------------------------

-- BLOCK 0 -- schema. Expect one row:
--   card_check 'CHECK (((card >= 1) AND (card <= 5)))', found_check non-null,
--   is_artifact_default null, policies 2, ledger true.
begin;
  select
    (select pg_get_constraintdef(oid) from pg_constraint
     where conname = 'campaign_fortunes_card_check')           as card_check,
    (select pg_get_constraintdef(oid) from pg_constraint
     where conname = 'campaign_fortunes_found_artifact_check')  as found_check,
    (select column_default from information_schema.columns
     where table_schema = 'public' and table_name = 'campaign_fortunes'
       and column_name = 'is_artifact')                         as is_artifact_default,
    (select count(*) from pg_policy
     where polrelid = to_regclass('public.campaign_fortunes'))  as policies,
    exists (select 1 from public.schema_migrations
            where version = '127')                              as ledger;
rollback;

-- BLOCK 1 -- the reseed. Expect one row per campaign: fortunes 5, artifacts 3,
-- revealed 0, stanzas 8 (2 + 1 + 3 + 1 + 1).
begin;
  select c.name as campaign,
         count(f.id)                              as fortunes,
         count(*) filter (where f.is_artifact)    as artifacts,
         count(*) filter (where f.is_revealed)    as revealed,
         sum(cardinality(f.lines))                as stanzas
  from campaigns c
  left join campaign_fortunes f on f.campaign_id = c.id
  group by c.name
  order by c.name;
rollback;

-- BLOCK 2 -- a new campaign gets five, hidden. Expect five rows, cards 1-5,
-- is_artifact true on 1-3, is_revealed false. Two statements, for 062 BLOCK
-- 3's reason.
begin;
  insert into campaigns (name) values ('127 verification');

  select f.card, f.title, f.is_artifact, f.is_revealed,
         cardinality(f.lines) as stanzas
  from campaign_fortunes f
  join campaigns c on c.id = f.campaign_id
  where c.name = '127 verification'
  order by f.card;
rollback;

-- BLOCK 3 -- pin_fortune_row. Expect one row: card 4, title 'A Faithful
-- Friend', is_artifact false (all pinned), lines {Edited.} (writable).
begin;
  update campaign_fortunes f
  set card = 1,
      title = 'Renamed',
      is_artifact = true,
      lines = array['Edited.']
  from campaigns c
  where c.id = f.campaign_id
    and c.name = 'Not Curse of Strahd'
    and f.card = 4
  returning f.card, f.title, f.is_artifact, f.lines;
rollback;

-- BLOCK 4 -- a companion can't be found. Expect one row, refused =
-- 'yes (23514)'. Caught and reported as a row (039's shape).
begin;
  do $$
  begin
    update campaign_fortunes f
    set is_found = true
    from campaigns c
    where c.id = f.campaign_id
      and c.name = 'Not Curse of Strahd'
      and f.card = 4;
    perform set_config('verification.refused', 'NO -- found companion accepted', true);
  exception when check_violation then
    perform set_config('verification.refused', 'yes (23514)', true);
  end
  $$;
  select current_setting('verification.refused') as refused;
rollback;

-- db/128_fortune_visions.sql
--
-- The DM's final text for the reading, and a short note on each artifact card
-- saying where its vision pointed.
--
-- WHAT CHANGED SINCE 127. The Tome gains its second stanza ("High where the
-- snows will never thaw ..."). Lancelot's last two lines are rewritten ("For
-- loyalty like his, I've found, / does not stay long beneath the ground."). The
-- Sunsword's last line gains its full stop. Each artifact gets one vision note
-- after its first stanza, which is where the vision falls in the reading. The
-- notes are a one-sentence summary in our own words, not the read-aloud
-- passage, so the card is a reminder of where to go rather than the whole
-- scene.
--
-- A VISION NOTE IS A STANZA IN [SQUARE BRACKETS]. The page renders a stanza
-- that starts with "[" and ends with "]" as plain narration, brackets removed,
-- and everything else as italic verse. A marker in the text, not a column,
-- for two reasons:
--   - Placement. The note belongs between two specific stanzas. A `vision`
--     column would need a rule in code for where it goes.
--   - Editing. The DM writes one in the app's existing textarea with no new
--     field, and it round-trips as typed.
-- The cost is a convention someone has to know. The editor's label states it,
-- and `visionText` in services/fortunes.ts is the one place that reads it.
-- No schema change: the lines CHECK (065) still fits, since the longest card is
-- four elements and well under 2000 chars.
--
-- DELETE AND RESEED, 127's shape and for 127's reasons. Checked 2026-11-05:
-- 25 rows, none revealed, none found, five distinct texts (127's seed,
-- unedited). The guard refuses if any card has been revealed or found since.
-- Stanzas use concat_ws(E'\n', ...) for the CRLF reason in 127's header.

begin;

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
      $$[The vision: a bladeless hilt before the upper towers of Castle Ravenloft, and a gauntlet of dark, dented steel closing around it.]$$,
      concat_ws(E'\n',
        $$It’s hidden well, and guarded deep$$,
        $$by a watcher who will never sleep.$$,
        $$And why should it rest? It has no need.$$,
        $$There’s no one inside to sleep… or bleed.$$)
    ]),
    -- The Tome of Strahd, in the Amber Temple.
    (p_campaign_id, 2, 'The Devil’s Own Words', true, array[
      concat_ws(E'\n',
        $$Next, a book. Not prayers, no.$$,
        $$Confessions, from so long ago,$$,
        $$the devil’s tale in his own hand,$$,
        $$from before the curse fell on this land:$$,
        $$what he wanted, what he took,$$,
        $$what it cost him. Read that book.$$,
        $$For knowing him, I tell you true,$$,
        $$shows where a blade might cut him through.$$),
      $$[The vision: a frozen mountain pass, a hall of glowing amber with shapes waiting inside, and an old clasped book on a stone shelf among them.]$$,
      concat_ws(E'\n',
        $$High where the snows will never thaw,$$,
        $$where the wind has teeth and the cold has claw,$$,
        $$there stands a temple older than sin.$$,
        $$Things that should have died wait within,$$,
        $$sealed in amber, never dead.$$,
        $$They do not sleep. They whisper instead.$$,
        $$They bargain, they promise, and then they take.$$,
        $$The book lies among those who made that mistake.$$,
        $$Take it and go. Don’t stay the hour.$$,
        $$And do not trade. Not for any power.$$)
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
      $$[The vision: a walled hillside village under rose vines, a weathered holy house at the top of the road, and the white-metal sun on its altar.]$$,
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
        $$For loyalty like his, I’ve found,$$,
        $$does not stay long beneath the ground.$$)
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

-- Guard, replace, then assert the end state: every campaign has cards 1-5,
-- artifacts on 1-3 only, exactly one vision note on each artifact and none on
-- a companion, nothing revealed, no \r. Do not demote to a notice.
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
                       or (select count(*) from unnest(f.lines) s
                           where s like '[%]')
                          <> case when f.is_artifact then 1 else 0 end
                       or array_to_string(f.lines, '') like '%' || chr(13) || '%'));

  if v_bad > 0 then
    raise exception '% campaign(s) do not have the five fortunes as written. Rolled back.', v_bad;
  end if;
end
$$;

insert into public.schema_migrations (version) values ('128');

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION -- run one block at a time. No ledger rows; each block ends in
-- rollback.
-- ---------------------------------------------------------------------------

-- BLOCK 1 -- the reseed. Expect one row per campaign: fortunes 5, visions 3,
-- revealed 0, elements 12 (3 + 3 + 4 + 1 + 1), ledger true.
begin;
  select c.name as campaign,
         count(f.id)                                        as fortunes,
         sum((select count(*) from unnest(f.lines) s
              where s like '[%]'))                          as visions,
         count(*) filter (where f.is_revealed)              as revealed,
         sum(cardinality(f.lines))                          as elements,
         exists (select 1 from schema_migrations
                 where version = '128')                     as ledger
  from campaigns c
  left join campaign_fortunes f on f.campaign_id = c.id
  group by c.name
  order by c.name;
rollback;

-- BLOCK 2 -- a new campaign gets the same five. Expect five rows: element
-- counts 3, 3, 4, 1, 1; the vision at position 2 on cards 1-3, null on 4-5.
begin;
  insert into campaigns (name) values ('128 verification');

  select f.card, f.title, cardinality(f.lines) as elements,
         (select i from unnest(f.lines) with ordinality u(s, i)
          where s like '[%]')                    as vision_at
  from campaign_fortunes f
  join campaigns c on c.id = f.campaign_id
  where c.name = '128 verification'
  order by f.card;
rollback;

-- db/171_resources_feats_tcoe_xgte.sql
--
-- Use counters for 170's feats, in 157's shape. RUN 170 FIRST. Of the
-- thirty, eleven have a use that recharges on a rest, fifteen counters in
-- all, since a feat that grants two once-a-day spells gets one counter per
-- spell, as the book counts them:
--
--   Artificer Initiate     1st-level Spell                  long   1
--   Fey Touched            Misty Step, 1st-level Spell      long   1 each
--   Shadow Touched         Invisibility, 1st-level Spell    long   1 each
--   Telepathic             Detect Thoughts                  long   1
--   Metamagic Adept        Sorcery Points                   long   2
--   Drow High Magic        Levitate, Dispel Magic           long   1 each
--   Wood Elf Magic         Longstrider, Pass without Trace  long   1 each
--   Fey Teleportation      Misty Step                       short  1
--   Fade Away              Fade Away                        short  1
--   Orcish Fury            Orcish Fury                      short  1
--   Second Chance          Second Chance                    short  1
--
-- All flat, so a single step at level 1 does (157).
--
-- Not counters:
--   * Dragon Fear spends a use of the Dragonborn's Breath Weapon, so it
--     shares that counter rather than having its own.
--   * Chef's treats belong to whoever eats them, and the short-rest meal has
--     no limit beyond the rest itself. Same reasoning as 157's Healer.
--   * Second Chance also comes back when you roll initiative. The counter
--     only knows rests, so the player resets it by hand.
--
-- With 157's three, that makes eighteen counters on shared feats.
--
-- AFTERWARDS: nothing. No schema changes, so no reload or gen:types.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  c_expected constant int := 18;
  r         record;
  v_seeking text;
  v_feat    uuid;
  v_count   int;
begin
  for r in
    select * from (values
      ('Artificer Initiate', '1st-level Spell',   'long',  1),
      ('Fey Touched',        'Misty Step',        'long',  1),
      ('Fey Touched',        '1st-level Spell',   'long',  1),
      ('Shadow Touched',     'Invisibility',      'long',  1),
      ('Shadow Touched',     '1st-level Spell',   'long',  1),
      ('Telepathic',         'Detect Thoughts',   'long',  1),
      ('Metamagic Adept',    'Sorcery Points',    'long',  2),
      ('Drow High Magic',    'Levitate',          'long',  1),
      ('Drow High Magic',    'Dispel Magic',      'long',  1),
      ('Wood Elf Magic',     'Longstrider',       'long',  1),
      ('Wood Elf Magic',     'Pass without Trace','long',  1),
      ('Fey Teleportation',  'Misty Step',        'short', 1),
      ('Fade Away',          'Fade Away',         'short', 1),
      ('Orcish Fury',        'Orcish Fury',       'short', 1),
      ('Second Chance',      'Second Chance',     'short', 1)
    ) as v(feat, counter, recharge, total)
  loop
    v_seeking := format('shared feat "%s"', r.feat);
    select id into strict v_feat
      from public.feats
     where name = r.feat and campaign_id is null;

    insert into public.feature_resources
      (feat_id, name, recharge, formula, step_levels, step_totals)
    values
      (v_feat, r.counter, r.recharge, 'steps', '{1}', array[r.total]::smallint[]);
  end loop;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
    from public.feature_resources fr
    join public.feats t on t.id = fr.feat_id
   where t.campaign_id is null;
  if v_count <> c_expected then
    raise exception '% feat counters (expected %). Rolled back.', v_count, c_expected;
  end if;
exception
  when no_data_found then
    raise exception 'Found no %. 170 seeds it. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('171');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the counters and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;
select
  (select step_totals = '{2}' from public.feature_resources fr
     join public.feats t on t.id = fr.feat_id
    where t.name = 'Metamagic Adept' and t.campaign_id is null)  as metamagic_2,
  (select count(*) = 2 from public.feature_resources fr
     join public.feats t on t.id = fr.feat_id
    where t.name = 'Fey Touched' and t.campaign_id is null)      as fey_touched_2,
  (select count(*) = 18 from public.feature_resources fr
     join public.feats t on t.id = fr.feat_id
    where t.campaign_id is null)                                 as shared_counters_18,
  (select count(*) = 1 from public.schema_migrations
    where version = '171')                                       as ledger_row;
rollback;

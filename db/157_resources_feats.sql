-- db/157_resources_feats.sql
--
-- Use counters for feats, 153's feat_id half. RUN 153 FIRST. Of the 42
-- shared feats (040, 052), three have a use that recharges on a rest:
--
--   Lucky           3 luck points per long rest
--   Martial Adept   1 superiority die per short rest
--   Magic Initiate  its 1st-level spell, once per long rest without a slot
--
-- A feat's 'steps' and 'level' formulas read the character's total level
-- (153's header). All three are flat, so a single step at level 1 does.
--
-- Not counters: Healer's and Inspiring Leader's limits are per creature
-- ("can't regain hit points this way again until it finishes a rest"), so
-- they belong to the creature healed, not to the feat's owner.
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
  c_expected constant int := 3;
  r         record;
  v_seeking text;
  v_feat    uuid;
  v_count   int;
begin
  for r in
    select * from (values
      ('Lucky', 'Luck Points', 'long', 3),
      ('Martial Adept', 'Superiority Die', 'short', 1),
      ('Magic Initiate', '1st-level Spell', 'long', 1)
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
    raise exception 'Found no %. 040 seeds it. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('157');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the counters and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

select
  (select step_totals = '{3}' from public.feature_resources fr
     join public.feats t on t.id = fr.feat_id
    where t.name = 'Lucky' and t.campaign_id is null)          as lucky_3,
  (select count(*) = 3 from public.feature_resources
    where feat_id is not null)                                 as feat_counters_3,
  (select count(*) = 1 from public.schema_migrations
    where version = '157')                                     as ledger_row;

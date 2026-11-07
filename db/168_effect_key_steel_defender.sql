-- db/168_effect_key_steel_defender.sql
--
-- Puts 167's `steel_defender` effect key on 150's Steel Defender row, which
-- is what makes the sheet show the defender's stat block (Sheet.tsx reads
-- the key, never the feature's name).
--
-- ⚠ RUN ONLY AFTER THE CLIENT FROM THE SAME CHANGE IS DEPLOYED. The client
-- before it parses class_features.effect strictly and doesn't know the key,
-- so this file would blank the sheet of every character in every campaign
-- (the feature catalogue is loaded whole). 160 and 166 carry the same
-- warning.
--
-- Resolved with `into strict` through class and subclass (167's shape): a
-- typo or a duplicate is a rollback, not a zero-row success.
--
-- No schema change, so no reload and no gen:types.
--
-- Run by Claude via `npx supabase db query --linked`. In the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  -- The one place the row is named.
  c_class    constant text := 'Artificer';
  c_subclass constant text := 'Battle Smith';
  c_feature  constant text := 'Steel Defender';
  c_effect   constant text := 'steel_defender';

  v_feature uuid;
  v_count   int;
begin
  select f.id into strict v_feature
    from public.class_features f
    join public.classes k on k.id = f.class_id
    join public.subclasses s on s.id = f.subclass_id
   where k.name = c_class and k.campaign_id is null
     and s.name = c_subclass
     and f.campaign_id is null
     and f.name = c_feature;

  update public.class_features set effect = c_effect where id = v_feature;

  -- Assert the end state: exactly this row carries the key.
  select count(*) into v_count
    from public.class_features where effect = c_effect;
  if v_count <> 1 or not exists (
    select 1 from public.class_features where id = v_feature and effect = c_effect
  ) then
    raise exception '% rows carry % (expected only %). Rolled back.',
      v_count, c_effect, c_feature;
  end if;
end
$$;

insert into public.schema_migrations (version) values ('168');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the key and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 1 from public.class_features
    where name = 'Steel Defender' and effect = 'steel_defender'
      and campaign_id is null)                                   as keyed,
  (select count(*) = 1 from public.schema_migrations
    where version = '168')                                       as ledger_row;

rollback;

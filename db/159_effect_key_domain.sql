-- db/159_effect_key_domain.sql
--
-- Races and feats can now change a number the sheet derives, the way class
-- features have since 121. Warforged's Integrated Protection (+1 AC) was the
-- prompt: 148's header had to tell players to type it into the AC bonus box,
-- because races had nowhere to say it. Feats were the same (Alert's +5
-- initiative is in KNOWN_ISSUES).
--
-- SCHEMA ONLY. This file adds the columns and widens the key list; 160 puts
-- the keys on rows. The split is about the deployed client, not the
-- database: a client from before this change parses class_features.effect
-- strictly (toClassFeature throws on an unknown key), so 160's
-- brutal_critical row would blank every sheet until the new client is live.
-- This file is harmless to that client: it ignores the two new columns, and
-- every existing key is still valid. RUN THIS ANY TIME; RUN 160 AFTER DEPLOY.
--
-- ONE LIST OF KEYS, NOT THREE: a domain. 121 put an inline CHECK on
-- class_features.effect and 150 rebuilt it to add a key. Copying that CHECK
-- onto races and feats would make three lists in the database plus
-- FEATURE_EFFECTS in src/data/rules.ts, and a key added to one CHECK but not
-- another would be refused in exactly one table. A domain is one named type
-- with the CHECK attached, so all three columns share it, and adding a key is
-- one `alter domain` (drop and re-add its constraint). FEATURE_EFFECTS stays
-- the other half of the list, as before.
--
-- WHY A COLUMN PER TABLE AND NOT ONE LINK TABLE (decided 2026-11-07):
-- a link table (granted_effects with class_feature_id / feat_id / race_id,
-- 153's feature_resources shape) would let a row carry several keys. Nothing
-- needs that yet: keys name the trait, not the number (`observant` is +5 to
-- two passives), and subraces aren't rows (055), so no race has two numeric
-- traits to carry. The column keeps 121's model and needs no data moved. If a
-- race or feat ever needs two keys, that's when to build the link table.
--
-- NEW KEYS (their rows are 160's):
--   brutal_critical       Barbarian 9th: extra crit dice, 2 at 13th, 3 at 17th
--   integrated_protection Warforged: +1 AC
--   alert                 Alert: +5 initiative
--   observant             Observant: +5 passive Perception and Investigation
--   mobile                Mobile: +10 ft speed
--   tough                 Tough: +2 max HP per level (shown in the average
--                         HP hint only, as Draconic Resilience is: max HP is
--                         a number the player types)
--   medium_armor_master   Medium Armor Master: DEX cap +3 in medium armour
--
-- No pin triggers to worry about: races and feats have no UPDATE policy, so
-- no client can change an effect after insert. A DM's homebrew race or feat
-- could carry a key on INSERT (054/039's policies), which is the point: that
-- is how homebrew opts in. No form offers it yet.
--
-- Run by Claude via `npx supabase db query --linked`. In the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): this file creates no table.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

create domain public.effect_key as text
  constraint effect_key_check check (value in (
    -- 121 and 150
    'extra_attack', 'extra_attack_fighter', 'improved_critical',
    'superior_critical', 'sneak_attack', 'martial_arts',
    'jack_of_all_trades', 'remarkable_athlete', 'dread_ambusher',
    'tactical_wit', 'rakish_audacity', 'aura_of_protection',
    'fast_movement', 'unarmored_movement', 'draconic_resilience',
    'battle_ready',
    -- 159
    'brutal_critical', 'integrated_protection', 'alert', 'observant',
    'mobile', 'tough', 'medium_armor_master'
  ));

-- The old CHECK goes; the domain's replaces it. Every stored key is in the
-- domain's list, so the type change validates without a rewrite failing.
alter table public.class_features drop constraint class_features_effect_check;
alter table public.class_features alter column effect type public.effect_key;

alter table public.races add column effect public.effect_key;
alter table public.feats add column effect public.effect_key;

-- ---- Assert the end state. -------------------------------------------------
do $$
declare
  v_count int;
begin
  select count(*) into v_count
    from information_schema.columns
   where table_schema = 'public'
     and table_name in ('class_features', 'races', 'feats')
     and column_name = 'effect'
     and domain_name = 'effect_key';
  if v_count <> 3 then
    raise exception '% of 3 effect columns use effect_key. Rolled back.', v_count;
  end if;

  -- 121/150's 23 keyed rows survived the type change.
  select count(*) into v_count
    from public.class_features where effect is not null;
  if v_count <> 23 then
    raise exception '% keyed class features (expected 23). Rolled back.', v_count;
  end if;
end
$$;

insert into public.schema_migrations (version) values ('159');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the columns, the old CHECK gone, and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 3 from information_schema.columns
    where table_schema = 'public' and column_name = 'effect'
      and domain_name = 'effect_key')                                 as three_columns,
  (select count(*) = 0 from pg_constraint
    where conname = 'class_features_effect_check')                    as old_check_gone,
  (select count(*) = 23 from public.class_features
    where effect is not null)                                         as keys_kept,
  (select count(*) = 1 from public.schema_migrations
    where version = '159')                                            as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the domain refuses an unknown key in every table
-- ---------------------------------------------------------------------------
--
-- 039's shape: each refusal is caught and reported as a row. 'rage' is the
-- plausible wrong answer (121's BLOCK 1): a real feature whose number the
-- sheet doesn't compute.
-- CORRECT OUTPUT: three rows, every result 'refused (23514)'.

begin;

do $$
begin
  begin
    update public.class_features set effect = 'rage'
     where id = (select id from public.class_features limit 1);
    perform set_config('verification.cf', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.cf', 'refused (23514)', true);
  end;
  begin
    update public.races set effect = 'rage'
     where id = (select id from public.races limit 1);
    perform set_config('verification.races', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.races', 'refused (23514)', true);
  end;
  begin
    update public.feats set effect = 'rage'
     where id = (select id from public.feats limit 1);
    perform set_config('verification.feats', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.feats', 'refused (23514)', true);
  end;
end
$$;

select 'class_features' as "table", current_setting('verification.cf') as result
union all
select 'races', current_setting('verification.races')
union all
select 'feats', current_setting('verification.feats');

rollback;

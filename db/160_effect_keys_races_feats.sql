-- db/160_effect_keys_races_feats.sql
--
-- Puts 159's new effect keys on their rows: one class feature, one race and
-- five feats. RUN 159 FIRST.
--
-- ⚠ RUN ONLY AFTER THE CLIENT FROM THE SAME CHANGE IS DEPLOYED. The client
-- before it parses class_features.effect strictly and doesn't know
-- brutal_critical, so this file would blank every sheet in a campaign that
-- loads the Barbarian's features (every sheet; the catalogue is loaded
-- whole). 150's header has the same warning for battle_ready.
--
--   Barbarian / Brutal Critical (9th)   brutal_critical
--   Warforged                           integrated_protection
--   Alert                               alert
--   Observant                           observant
--   Mobile                              mobile
--   Tough                               tough
--   Medium Armor Master                 medium_armor_master
--
-- Every row is a shared one, resolved by name with `into strict` (121's
-- shape). races and feats have no unique name, so strict is what turns "no
-- such row" or "two of them" into a rollback instead of an update that
-- touches nothing and succeeds.
--
-- NOT DONE HERE: zeroing ac_bonus on Warforged characters whose player
-- already typed Integrated Protection in by hand. Decided 2026-11-07 to tell
-- the players instead; until they clear the box, their AC reads 1 high.
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
  -- The one place each row is named. Nothing below repeats them.
  c_feature constant text[] := array['Barbarian', 'Brutal Critical', 'brutal_critical'];
  c_race    constant text[] := array['Warforged', 'integrated_protection'];
  c_feats   constant text[][] := array[
    ['Alert',               'alert'],
    ['Observant',           'observant'],
    ['Mobile',              'mobile'],
    ['Tough',               'tough'],
    ['Medium Armor Master', 'medium_armor_master']
  ];

  v_seeking text;
  v_id      uuid;
  v_count   int;
  i         int;
begin
  -- ---- The class feature (a base-class row: subclass_id is null) --------
  v_seeking := format('class feature %s / %s', c_feature[1], c_feature[2]);
  select f.id into strict v_id
    from public.class_features f
    join public.classes k on k.id = f.class_id
   where k.name = c_feature[1] and k.campaign_id is null
     and f.campaign_id is null and f.subclass_id is null
     and f.name = c_feature[2];
  update public.class_features set effect = c_feature[3] where id = v_id;

  -- ---- The race --------------------------------------------------------
  v_seeking := format('race %s', c_race[1]);
  select r.id into strict v_id
    from public.races r
   where r.name = c_race[1] and r.campaign_id is null;
  update public.races set effect = c_race[2] where id = v_id;

  -- ---- The feats -------------------------------------------------------
  for i in 1 .. array_length(c_feats, 1) loop
    v_seeking := format('feat %s', c_feats[i][1]);
    select t.id into strict v_id
      from public.feats t
     where t.name = c_feats[i][1] and t.campaign_id is null;
    update public.feats set effect = c_feats[i][2] where id = v_id;
  end loop;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  -- 121/150's 23 class keys plus this file's one, and no other.
  select count(*) into v_count
    from public.class_features where effect is not null;
  if v_count <> 24 then
    raise exception '% keyed class features (expected 24). Rolled back.', v_count;
  end if;

  select count(*) into v_count
    from public.races where effect is not null;
  if v_count <> 1 then
    raise exception '% keyed races (expected 1). Rolled back.', v_count;
  end if;

  for i in 1 .. array_length(c_feats, 1) loop
    select count(*) into v_count
      from public.feats t
     where t.name = c_feats[i][1] and t.campaign_id is null
       and t.effect = c_feats[i][2];
    if v_count <> 1 then
      raise exception 'Feat % does not carry %. Rolled back.', c_feats[i][1], c_feats[i][2];
    end if;
  end loop;

  select count(*) into v_count
    from public.feats where effect is not null;
  if v_count <> array_length(c_feats, 1) then
    raise exception '% keyed feats (expected %). Rolled back.',
      v_count, array_length(c_feats, 1);
  end if;
exception
  when no_data_found then
    raise exception 'Found no shared %. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one shared %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('160');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: every key where the header says, and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select effect::text = 'brutal_critical'
     from public.class_features f
     join public.classes k on k.id = f.class_id
    where k.name = 'Barbarian' and k.campaign_id is null
      and f.name = 'Brutal Critical' and f.campaign_id is null)         as brutal_critical,
  (select effect::text = 'integrated_protection'
     from public.races where name = 'Warforged' and campaign_id is null) as warforged,
  (select array_agg(name || ':' || effect order by name)
          = array['Alert:alert', 'Medium Armor Master:medium_armor_master',
                  'Mobile:mobile', 'Observant:observant', 'Tough:tough']
     from public.feats where effect is not null)                        as feats,
  (select count(*) = 1 from public.schema_migrations
    where version = '160')                                              as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: Warforged characters whose players may have typed the +1 by hand
-- ---------------------------------------------------------------------------
--
-- Not a pass/fail check: the list of players to tell (see the header). A
-- row with ac_bonus = 1 is very likely double-counting now.
-- CORRECT OUTPUT: zero or more rows; none is an error.

begin;

select c.name as character, p.display_name as player, s.ac_bonus
  from public.character_stats s
  join public.characters c on c.id = s.character_id
  join public.races r on r.id = s.race_id
  left join public.profiles p on p.id = c.user_id
 where r.name = 'Warforged' and s.ac_bonus <> 0;

rollback;

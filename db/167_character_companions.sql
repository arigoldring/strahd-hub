-- db/167_character_companions.sql
--
-- The Battle Smith's steel defender gets a stat block on the sheet that
-- tracks its own hit points and can be renamed. Until now it was one text row
-- (150), and KNOWN_ISSUES said so ("The steel defender has no stat block on
-- the sheet").
--
-- SCHEMA ONLY, plus Repair's counter. 168 puts the `steel_defender` effect
-- key on 150's Steel Defender row, and it must wait for the client from the
-- same change to be deployed: the client before it parses
-- class_features.effect strictly and would blank every sheet (159's header).
-- Everything in this file is invisible to that client: a new table, a new
-- function, a wider domain, and a feature_resources row, which the old client
-- already renders generically. RUN THIS ANY TIME; RUN 168 AFTER DEPLOY.
--
-- ONLY WHAT CHANGES IN PLAY IS STORED (decided 2026-11-07):
--
--   name     null means "Steel Defender", the kind's own name. A blank name
--            would be a second spelling of that (042's argument against a
--            defaulted row), so a CHECK refuses it and the service turns a
--            blank draft into null.
--   damage   hit points lost, not hit points left. The maximum is derived
--            (2 + INT modifier + 5 x artificer level, rules.ts), so storing
--            the damage means: no row is a full-health defender, a level-up
--            raises current HP along with the maximum, and a long rest is
--            `damage = 0`. 153 stores spent uses rather than uses left for
--            the same reason.
--   hp_temp  temporary hit points, absorbed before damage (056's rule).
--
-- AC, saves, skills, attacks and the rest are derived in rules.ts
-- (steelDefender), like a character's own numbers (054-057).
--
-- A COMPANIONS TABLE, NOT A STEEL DEFENDER TABLE: `kind` names the stat
-- block, and its CHECK is one list in two places with COMPANION_KINDS in
-- services/companions.ts. A Beast Master's companion or a homunculus would
-- be a new kind and a new block in rules.ts, not a new table. Keyed on
-- (character_id, kind): one companion of each kind per character, which the
-- book's rule for the defender is ("the old one perishes"). A kind that
-- allowed two would need a surrogate key.
--
-- NO ROW IS THE DEFAULT, so the table has no trigger creating one. The first
-- rename or the first hit creates it, through an upsert. That makes the
-- write side 046's shape: four policies, because an upsert's second write is
-- an UPDATE (the upsert gotcha in CLAUDE.md, the opposite of 037's three).
--
-- The policies are 056's for character_stats: anyone who can see the
-- character reads it, the owner or the campaign's DM writes it, the line HP
-- and gear already use.
--
-- THE PIN TRIGGER IS AN ALLOWLIST (095's shape, as CLAUDE.md asks of a new
-- table): `new := old`, then restore the three writable columns. A DM passes
-- can_edit_character on every sheet, so without it a DM could move a
-- defender between characters by updating character_id.
--
-- adjust_companion_hp(character, kind, delta, cap) is one upsert, 153's
-- use_resource and 056's adjust_character_hp in one: damage drains temp HP
-- first, healing never takes damage below 0, and damage never exceeds `cap`,
-- the maximum the client derived. A caller lying about cap misreports only a
-- companion they can already set to anything. SECURITY INVOKER: RLS is the
-- boundary.
--
-- REPAIR (3/day) is a counter on 150's Steel Defender row, in 156's shape:
-- a step of 3 from Battle Smith 3rd, recharging on a long rest.
--
-- Run by Claude via `npx supabase db query --linked`. In the SQL editor the
-- "Run and enable RLS" offer is safe to decline: this file enables RLS on its
-- own table.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- ---------- 1. effect key ----------

alter domain public.effect_key drop constraint effect_key_check;
alter domain public.effect_key add constraint effect_key_check check (value in (
  -- 121 and 150
  'extra_attack', 'extra_attack_fighter', 'improved_critical',
  'superior_critical', 'sneak_attack', 'martial_arts',
  'jack_of_all_trades', 'remarkable_athlete', 'dread_ambusher',
  'tactical_wit', 'rakish_audacity', 'aura_of_protection',
  'fast_movement', 'unarmored_movement', 'draconic_resilience',
  'battle_ready',
  -- 159
  'brutal_critical', 'integrated_protection', 'alert', 'observant',
  'mobile', 'tough', 'medium_armor_master',
  -- 164
  'dwarven_toughness', 'savage_attacks', 'heavy_armor_speed',
  -- 167
  'steel_defender'
));

-- ---------- 2. character_companions ----------

create table public.character_companions (
  character_id uuid not null references public.characters(id) on delete cascade,
  kind text not null check (kind in ('steel_defender')),
  name text check (name is null or length(btrim(name)) between 1 and 40),
  damage smallint not null default 0 check (damage between 0 and 999),
  hp_temp smallint not null default 0 check (hp_temp between 0 and 999),
  updated_at timestamptz not null default now(),
  primary key (character_id, kind)
);

alter table public.character_companions enable row level security;

create policy "character viewers read companions"
  on public.character_companions for select to authenticated
  using (
    exists (
      select 1 from characters c
      where c.id = character_companions.character_id
    )
  );

create policy "owner or dm creates companions"
  on public.character_companions for insert to authenticated
  with check (public.can_edit_character(character_id));

create policy "owner or dm edits companions"
  on public.character_companions for update to authenticated
  using (public.can_edit_character(character_id))
  with check (public.can_edit_character(character_id));

create policy "owner or dm deletes companions"
  on public.character_companions for delete to authenticated
  using (public.can_edit_character(character_id));

create or replace function public.pin_character_companion_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
declare
  v_name    text     := new.name;
  v_damage  smallint := new.damage;
  v_hp_temp smallint := new.hp_temp;
begin
  new := old;
  new.name       := v_name;
  new.damage     := v_damage;
  new.hp_temp    := v_hp_temp;
  new.updated_at := now();
  return new;
end;
$function$
;

create trigger pin_character_companion_row
  before update on public.character_companions
  for each row execute function public.pin_character_companion_row();

-- ---------- 3. adjust_companion_hp ----------

-- delta < 0 is damage, delta > 0 healing. Every right-hand side of the
-- update reads the OLD row, so damage's branch sees the temp HP from before
-- this write (adjust_character_hp's shape). Returns the row after the write.
create or replace function public.adjust_companion_hp(
  target_character uuid,
  target_kind text,
  delta int,
  cap int
)
 returns public.character_companions
 language sql
 security invoker
 set search_path to 'public'
as $function$
  insert into character_companions as c (character_id, kind, damage)
  values (
    target_character,
    target_kind,
    least(greatest(cap, 0), 999, greatest(0, -delta))
  )
  on conflict (character_id, kind) do update
    set hp_temp = case
          when delta < 0 then greatest(0, c.hp_temp + delta)
          else c.hp_temp
        end,
        damage = case
          when delta < 0 then
            least(greatest(cap, 0), 999, c.damage + greatest(0, -(c.hp_temp + delta)))
          else greatest(0, c.damage - delta)
        end
  returning *;
$function$
;

-- ---------- 4. Repair's counter ----------

do $$
declare
  -- The one place the feature is named.
  c_class    constant text := 'Artificer';
  c_subclass constant text := 'Battle Smith';
  c_feature  constant text := 'Steel Defender';
  c_counter  constant text := 'Repair';

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

  insert into public.feature_resources
    (feature_id, name, recharge, formula, step_levels, step_totals)
  values (v_feature, c_counter, 'long', 'steps', '{3}', '{3}');

  -- Assert the end state, not the work.
  select count(*) into v_count
    from public.feature_resources
   where feature_id = v_feature and name = c_counter
     and recharge = 'long' and formula = 'steps'
     and step_levels = '{3}' and step_totals = '{3}';
  if v_count <> 1 then
    raise exception '% % counters on % (expected 1). Rolled back.',
      v_count, c_counter, c_feature;
  end if;
end
$$;

-- ---------- 5. assert the schema ----------

do $$
declare
  v_count int;
begin
  select count(*) into v_count
    from pg_policies
   where schemaname = 'public' and tablename = 'character_companions';
  if v_count <> 4 then
    raise exception '% policies on character_companions (expected 4). Rolled back.', v_count;
  end if;

  if (select prosecdef from pg_proc
       where oid = 'public.adjust_companion_hp(uuid, text, int, int)'::regprocedure) then
    raise exception 'adjust_companion_hp is security definer. Rolled back.';
  end if;
end
$$;

insert into public.schema_migrations (version) values ('167');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the table, the function, the counter and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select relrowsecurity from pg_class
    where oid = 'public.character_companions'::regclass)              as rls_on,
  (select count(*) = 4 from pg_policies
    where schemaname = 'public' and tablename = 'character_companions') as four_policies,
  (select not prosecdef from pg_proc
    where oid = 'public.adjust_companion_hp(uuid, text, int, int)'::regprocedure)
                                                                      as invoker,
  (select count(*) = 1 from public.feature_resources r
     join public.class_features f on f.id = r.feature_id
    where f.name = 'Steel Defender' and r.name = 'Repair')            as repair_counter,
  (select pg_get_constraintdef(oid) like '%steel_defender%' from pg_constraint
    where conname = 'effect_key_check')                               as key_in_domain,
  (select count(*) = 1 from public.schema_migrations
    where version = '167')                                            as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: adjust_companion_hp, temp HP first, clamped both ways
-- ---------------------------------------------------------------------------
--
-- Run as the table owner (the SQL editor), so this tests the maths only.
-- Max HP 20 throughout.
--
-- CORRECT OUTPUT: one row, every column `t`.
--   first_hit      7 damage on no row: a new row, damage 7
--   temp_first     5 temp, then 8 damage: temp 0, damage 7 + 3 = 10
--   capped         50 damage: damage stops at 20
--   healed         heal 100: damage back to 0
--   name_kept      a rename survives the HP writes

begin;

create temp table t_c on commit drop as
  select id from public.characters limit 1;

create temp table t_r (step text, damage int, hp_temp int, name text) on commit drop;

insert into t_r select 'first_hit', damage, hp_temp, name
  from t_c, public.adjust_companion_hp(t_c.id, 'steel_defender', -7, 20);
update public.character_companions set hp_temp = 5, name = 'Clank'
 where character_id = (select id from t_c);
insert into t_r select 'temp_first', damage, hp_temp, name
  from t_c, public.adjust_companion_hp(t_c.id, 'steel_defender', -8, 20);
insert into t_r select 'capped', damage, hp_temp, name
  from t_c, public.adjust_companion_hp(t_c.id, 'steel_defender', -50, 20);
insert into t_r select 'healed', damage, hp_temp, name
  from t_c, public.adjust_companion_hp(t_c.id, 'steel_defender', 100, 20);

select
  (select damage = 7 from t_r where step = 'first_hit')                    as first_hit,
  (select damage = 10 and hp_temp = 0 from t_r where step = 'temp_first')  as temp_first,
  (select damage = 20 from t_r where step = 'capped')                      as capped,
  (select damage = 0 from t_r where step = 'healed')                       as healed,
  (select name = 'Clank' from t_r where step = 'healed')                   as name_kept;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: the pin trigger keeps a companion on its character
-- ---------------------------------------------------------------------------
--
-- Needs two characters. Moves the row's character_id and kind; the trigger
-- puts both back.
--
-- CORRECT OUTPUT: one row, `t`.

begin;

create temp table t_c on commit drop as
  select id, row_number() over (order by id) as n
    from public.characters limit 2;

insert into public.character_companions (character_id, kind)
  select id, 'steel_defender' from t_c where n = 1;
update public.character_companions
   set character_id = (select id from t_c where n = 2)
 where character_id = (select id from t_c where n = 1);

select exists (
  select 1 from public.character_companions
   where character_id = (select id from t_c where n = 1)
) as stayed_put;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 3: a blank name and an unknown kind are refused
-- ---------------------------------------------------------------------------
--
-- 039's shape: each refusal is caught and reported as a row.
--
-- CORRECT OUTPUT: two rows, each outcome starting 'rejected by'.

begin;

create temp table t_out (check_name text, outcome text) on commit drop;

do $$
declare
  v_character uuid;
  v_constraint text;
begin
  select id into v_character from public.characters limit 1;
  if v_character is null then
    raise exception 'no character to test with: this block would prove nothing';
  end if;

  begin
    insert into public.character_companions (character_id, kind, name)
      values (v_character, 'steel_defender', '   ');
    insert into t_out values ('blank name', 'INSERT SUCCEEDED -- CHECK MISSING');
  exception when check_violation then
    get stacked diagnostics v_constraint = constraint_name;
    insert into t_out values ('blank name', 'rejected by ' || v_constraint);
  end;

  begin
    insert into public.character_companions (character_id, kind)
      values (v_character, 'homunculus');
    insert into t_out values ('unknown kind', 'INSERT SUCCEEDED -- CHECK MISSING');
  exception when check_violation then
    get stacked diagnostics v_constraint = constraint_name;
    insert into t_out values ('unknown kind', 'rejected by ' || v_constraint);
  end;
end
$$;

select * from t_out;

rollback;

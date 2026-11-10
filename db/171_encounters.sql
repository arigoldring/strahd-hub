-- db/171_encounters.sql
--
-- The initiative tracker (WANTED_FEATURES, decided 2026-11-09): one live
-- fight per campaign, a turn order every member can watch, and monsters
-- whose numbers only the DM can read.
--
-- SCHEMA ONLY. 172 publishes the two public tables to Realtime, and the
-- client comes after that. Nothing here is visible to the deployed client:
-- three new tables and two new functions. RUN THIS ANY TIME.
--
-- THREE TABLES, SPLIT BY WHO MAY READ WHAT.
--
--   encounters                one row per campaign (unique campaign_id), so
--                             "one live fight" is a constraint, not a
--                             convention. Ending the fight is a DELETE, and
--                             everything below cascades with it. Members
--                             read, the DM writes.
--   encounter_combatants      the turn order. Members read; the DM writes,
--                             and a player may write one column of their own
--                             PC's row (below).
--   encounter_monster_stats   a monster's HP, AC and initiative bonus.
--                             DM-only for all four operations, and never to
--                             be published. A separate table rather than
--                             hidden columns, because RLS hides rows, not
--                             columns (CLAUDE.md, Reveal gating).
--
-- THE TURN IS A COMBATANT ID, NOT AN INDEX. An index into the sorted order
-- would point at someone else the moment a monster is added or removed
-- mid-fight. turn_combatant_id names the row instead, through a composite FK
-- to encounter_combatants (id, encounter_id), so "it is the turn of a
-- combatant in another fight" is unrepresentable (npcs' composite FK to
-- locations, 027). Removing the combatant whose turn it is sets the turn to
-- null, via the column list on `on delete set null (turn_combatant_id)`;
-- the client advances the turn before removing that row.
--
-- WHAT A COMBATANT IS. `kind` is one of three, and combatant_shape spells
-- out which columns each one has:
--
--   pc          a character. HP lives on character_stats as it always has,
--               so the tracker and the sheet show one number.
--   companion   the character's steel defender. No initiative of its own:
--               it acts right after its Artificer, so it is sorted there and
--               never rolled. HP lives on character_companions (167). A
--               second companion kind would need a column naming it; today
--               there is only one.
--   monster     typed in at the table. It has a name, a DEX score and a
--               stats row.
--
-- ORDER (decided 2026-11-09): initiative, then the higher DEX score, then
-- name A-Z. Computed in rules.ts, by players' clients too. That is why a
-- monster's DEX is a public column here and not in the DM-only stats:
-- players can't sort by a number they can't read. A PC's DEX comes from
-- character_stats. Alphabetical rather than random, because a random
-- tiebreak would have to be stored, or each client would sort the tie its own
-- way.
--
-- PLAYERS SEE BLOODIED / DOWN, NOT NUMBERS. `status` on the combatant row is
-- derived from the DM-only HP and stored on purpose. This breaks "only store
-- inputs" (056), and here is why: a security-definer RPC deriving the status
-- on demand would hide the HP just as well, but players would never be told
-- the status changed, because the table whose rows change (the stats) can
-- never be published. A stored column on a published table is the event.
-- So:
--   - monster_status() is the rule, in one place. Bloodied is at or below
--     half the maximum; down is 0. Temporary HP is ignored.
--   - sync_monster_status, an AFTER trigger on the stats, writes it.
--   - the combatant pin trigger refuses `status` from any direct UPDATE,
--     DM and table owner included, and accepts it only when
--     pg_trigger_depth() > 1, which here means "written by the status
--     trigger". The column can't drift from the HP it summarises. If another
--     trigger ever writes encounter_combatants, it inherits that pass:
--     check this pin first.
--
-- A PLAYER MAY ENTER THEIR OWN INITIATIVE, AND THAT IS THE ONE NEW LINE.
-- The UPDATE policy admits the campaign's DM on every row, and
-- can_edit_character on a `pc` row (the owner, or the DM again). RLS can't
-- say which columns, so the pin trigger does, as an allowlist (095's shape):
-- `new := old`, then restore initiative for anyone who got past RLS, and name
-- and DEX only for the DM. Every other column, including any added later, is
-- pinned for everyone. The same shape on the other two tables:
-- encounters keeps round and turn_combatant_id writable; the stats keep the
-- numbers and pin the key.
--
-- MONSTER HP: adjust_monster_hp(combatant, delta) is adjust_character_hp
-- (056) pointed at the stats: one UPDATE, temp HP absorbs damage first,
-- healing caps at the maximum. Only the DM writes, but two DM tabs are two
-- writers. A monster's maximum is typed in, not derived, so current HP is
-- stored, unlike the steel defender's damage (167): there the maximum moves
-- on a level-up.
--
-- The stats row can only hang off a monster: it carries kind = 'monster'
-- and a composite FK to encounter_combatants (id, kind).
--
-- LEFT OPEN (ACCEPTED_ISSUES): combatants have no campaign_id, by the
-- sibling-table rule (CLAUDE.md, Multi-campaign), so nothing stops a DM of
-- two campaigns attaching a PC from one to the other's fight by hand. 041
-- BLOCK 6's argument: the client only offers this campaign's roster, and the
-- fix (a redundant campaign_id or a trigger) costs more than the exposure.
--
-- Run by Claude via `npx supabase db query --linked`. In the SQL editor the
-- "Run and enable RLS" offer is safe to decline: this file enables RLS on its
-- own tables.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- ---------- 1. the tables ----------

create table public.encounters (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null unique
    references public.campaigns(id) on delete cascade,
  round smallint not null default 1 check (round between 1 and 999),
  turn_combatant_id uuid,
  created_at timestamptz not null default now()
);

create table public.encounter_combatants (
  id uuid primary key default gen_random_uuid(),
  encounter_id uuid not null
    references public.encounters(id) on delete cascade,
  kind text not null check (kind in ('pc', 'companion', 'monster')),
  character_id uuid references public.characters(id) on delete cascade,
  name text check (name is null or length(btrim(name)) between 1 and 40),
  dex smallint check (dex between 1 and 30),
  initiative smallint check (initiative between -10 and 99),
  status text check (status in ('bloodied', 'down')),
  created_at timestamptz not null default now(),
  -- Targets for the two composite FKs.
  unique (id, encounter_id),
  unique (id, kind),
  -- A character joins a fight once, and so does their defender.
  unique (encounter_id, kind, character_id),
  constraint combatant_shape check (
    (kind = 'monster'
      and character_id is null and name is not null and dex is not null)
    or (kind = 'pc'
      and character_id is not null and name is null and dex is null
      and status is null)
    or (kind = 'companion'
      and character_id is not null and name is null and dex is null
      and initiative is null and status is null)
  )
);

alter table public.encounters
  add constraint encounters_turn_fkey
  foreign key (turn_combatant_id, id)
  references public.encounter_combatants (id, encounter_id)
  on delete set null (turn_combatant_id);

create table public.encounter_monster_stats (
  combatant_id uuid primary key,
  kind text not null default 'monster' check (kind = 'monster'),
  hp_max smallint not null check (hp_max between 1 and 9999),
  hp_current smallint not null check (hp_current >= 0),
  hp_temp smallint not null default 0 check (hp_temp between 0 and 999),
  ac smallint check (ac between 0 and 40),
  init_bonus smallint not null default 0 check (init_bonus between -10 and 20),
  check (hp_current <= hp_max),
  foreign key (combatant_id, kind)
    references public.encounter_combatants (id, kind) on delete cascade
);

alter table public.encounters enable row level security;
alter table public.encounter_combatants enable row level security;
alter table public.encounter_monster_stats enable row level security;

-- ---------- 2. policies ----------

-- encounters: members read, the DM writes.
create policy "members read encounters"
  on public.encounters for select to authenticated
  using (public.is_campaign_member(campaign_id));

create policy "dm starts encounters"
  on public.encounters for insert to authenticated
  with check (public.is_campaign_dm(campaign_id));

create policy "dm runs encounters"
  on public.encounters for update to authenticated
  using (public.is_campaign_dm(campaign_id))
  with check (public.is_campaign_dm(campaign_id));

create policy "dm ends encounters"
  on public.encounters for delete to authenticated
  using (public.is_campaign_dm(campaign_id));

-- encounter_combatants: the EXISTS joins answer through encounters' own
-- SELECT policy, so they fail closed for a non-member.
create policy "members read combatants"
  on public.encounter_combatants for select to authenticated
  using (
    exists (
      select 1 from encounters e
       where e.id = encounter_combatants.encounter_id
    )
  );

create policy "dm adds combatants"
  on public.encounter_combatants for insert to authenticated
  with check (
    exists (
      select 1 from encounters e
       where e.id = encounter_combatants.encounter_id
         and public.is_campaign_dm(e.campaign_id)
    )
  );

-- The DM on any row; a player on their own PC's row. Which columns each may
-- change is pin_encounter_combatant_row's job.
create policy "dm or owner updates combatants"
  on public.encounter_combatants for update to authenticated
  using (
    exists (
      select 1 from encounters e
       where e.id = encounter_combatants.encounter_id
         and public.is_campaign_dm(e.campaign_id)
    )
    or (encounter_combatants.kind = 'pc'
        and public.can_edit_character(encounter_combatants.character_id))
  )
  with check (
    exists (
      select 1 from encounters e
       where e.id = encounter_combatants.encounter_id
         and public.is_campaign_dm(e.campaign_id)
    )
    or (encounter_combatants.kind = 'pc'
        and public.can_edit_character(encounter_combatants.character_id))
  );

create policy "dm removes combatants"
  on public.encounter_combatants for delete to authenticated
  using (
    exists (
      select 1 from encounters e
       where e.id = encounter_combatants.encounter_id
         and public.is_campaign_dm(e.campaign_id)
    )
  );

-- encounter_monster_stats: the DM, for everything. A player's join to
-- encounter_combatants succeeds, so the is_campaign_dm test is what stops
-- them, not the join.
create policy "dm reads monster stats"
  on public.encounter_monster_stats for select to authenticated
  using (
    exists (
      select 1 from encounter_combatants c
        join encounters e on e.id = c.encounter_id
       where c.id = encounter_monster_stats.combatant_id
         and public.is_campaign_dm(e.campaign_id)
    )
  );

create policy "dm creates monster stats"
  on public.encounter_monster_stats for insert to authenticated
  with check (
    exists (
      select 1 from encounter_combatants c
        join encounters e on e.id = c.encounter_id
       where c.id = encounter_monster_stats.combatant_id
         and public.is_campaign_dm(e.campaign_id)
    )
  );

create policy "dm edits monster stats"
  on public.encounter_monster_stats for update to authenticated
  using (
    exists (
      select 1 from encounter_combatants c
        join encounters e on e.id = c.encounter_id
       where c.id = encounter_monster_stats.combatant_id
         and public.is_campaign_dm(e.campaign_id)
    )
  )
  with check (
    exists (
      select 1 from encounter_combatants c
        join encounters e on e.id = c.encounter_id
       where c.id = encounter_monster_stats.combatant_id
         and public.is_campaign_dm(e.campaign_id)
    )
  );

create policy "dm deletes monster stats"
  on public.encounter_monster_stats for delete to authenticated
  using (
    exists (
      select 1 from encounter_combatants c
        join encounters e on e.id = c.encounter_id
       where c.id = encounter_monster_stats.combatant_id
         and public.is_campaign_dm(e.campaign_id)
    )
  );

-- ---------- 3. pin triggers (allowlists) ----------

create or replace function public.pin_encounter_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
declare
  v_round smallint := new.round;
  v_turn  uuid     := new.turn_combatant_id;
begin
  new := old;
  new.round             := v_round;
  new.turn_combatant_id := v_turn;
  return new;
end;
$function$
;

create trigger pin_encounter_row
  before update on public.encounters
  for each row execute function public.pin_encounter_row();

create or replace function public.pin_encounter_combatant_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
declare
  v_initiative smallint := new.initiative;
  v_name       text     := new.name;
  v_dex        smallint := new.dex;
  v_status     text     := new.status;
  v_dm         boolean;
begin
  select public.is_campaign_dm(e.campaign_id) into v_dm
    from encounters e
   where e.id = old.encounter_id;

  new := old;
  -- Anyone RLS let this far: the DM, or the PC's owner.
  new.initiative := v_initiative;
  if coalesce(v_dm, false) then
    new.name := v_name;
    new.dex  := v_dex;
  end if;
  -- Only sync_monster_status, never a client (header).
  if pg_trigger_depth() > 1 then
    new.status := v_status;
  end if;
  return new;
end;
$function$
;

create trigger pin_encounter_combatant_row
  before update on public.encounter_combatants
  for each row execute function public.pin_encounter_combatant_row();

create or replace function public.pin_encounter_monster_stats_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
declare
  v_hp_max     smallint := new.hp_max;
  v_hp_current smallint := new.hp_current;
  v_hp_temp    smallint := new.hp_temp;
  v_ac         smallint := new.ac;
  v_init_bonus smallint := new.init_bonus;
begin
  new := old;
  new.hp_max     := v_hp_max;
  new.hp_current := v_hp_current;
  new.hp_temp    := v_hp_temp;
  new.ac         := v_ac;
  new.init_bonus := v_init_bonus;
  return new;
end;
$function$
;

create trigger pin_encounter_monster_stats_row
  before update on public.encounter_monster_stats
  for each row execute function public.pin_encounter_monster_stats_row();

-- ---------- 4. status: the rule and the trigger that applies it ----------

create or replace function public.monster_status(hp_current int, hp_max int)
 returns text
 language sql
 immutable
 set search_path to 'public'
as $function$
  select case
    when hp_current <= 0 then 'down'
    when hp_current * 2 <= hp_max then 'bloodied'
    else null
  end;
$function$
;

-- SECURITY INVOKER: the writer is the DM (or the table owner in a
-- migration), who passes the combatants' UPDATE policy anyway.
create or replace function public.sync_monster_status()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
declare
  v_status text := public.monster_status(new.hp_current, new.hp_max);
begin
  update encounter_combatants
     set status = v_status
   where id = new.combatant_id
     and status is distinct from v_status;
  return null;
end;
$function$
;

create trigger sync_monster_status
  after insert or update of hp_current, hp_max on public.encounter_monster_stats
  for each row execute function public.sync_monster_status();

-- ---------- 5. adjust_monster_hp ----------

-- delta < 0 is damage, delta > 0 healing. Every right-hand side reads the OLD
-- row, so the damage branch sees the temp HP from before this write
-- (adjust_character_hp's shape). Healing never lowers HP above the maximum.
create or replace function public.adjust_monster_hp(
  target_combatant uuid,
  delta int
)
 returns setof public.encounter_monster_stats
 language sql
 security invoker
 set search_path to 'public'
as $function$
  update encounter_monster_stats set
    hp_temp = case
      when delta < 0 then greatest(0, hp_temp + delta)
      else hp_temp
    end,
    hp_current = case
      when delta < 0 then greatest(0, hp_current + least(0, hp_temp + delta))
      else greatest(hp_current, least(hp_max, hp_current + delta))
    end
  where combatant_id = target_combatant
  returning *;
$function$
;

-- ---------- 6. assert the schema ----------

do $$
declare
  c_tables constant text[] := array[
    'encounters', 'encounter_combatants', 'encounter_monster_stats'
  ];
  v_table text;
  v_count int;
begin
  foreach v_table in array c_tables loop
    select count(*) into v_count
      from pg_policies
     where schemaname = 'public' and tablename = v_table;
    if v_count <> 4 then
      raise exception '% policies on % (expected 4). Rolled back.', v_count, v_table;
    end if;
  end loop;

  select count(*) into v_count
    from pg_proc
   where oid in ('public.adjust_monster_hp(uuid, int)'::regprocedure,
                 'public.sync_monster_status()'::regprocedure)
     and prosecdef;
  if v_count <> 0 then
    raise exception 'a 171 function is security definer. Rolled back.';
  end if;
end
$$;

insert into public.schema_migrations (version) values ('171');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the tables, the policies, the functions and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select bool_and(relrowsecurity) from pg_class
    where oid in ('public.encounters'::regclass,
                  'public.encounter_combatants'::regclass,
                  'public.encounter_monster_stats'::regclass))         as rls_on,
  (select count(*) = 12 from pg_policies
    where schemaname = 'public'
      and tablename in ('encounters', 'encounter_combatants',
                        'encounter_monster_stats'))                    as twelve_policies,
  (select not prosecdef from pg_proc
    where oid = 'public.adjust_monster_hp(uuid, int)'::regprocedure)    as hp_invoker,
  (select not prosecdef from pg_proc
    where oid = 'public.sync_monster_status()'::regprocedure)          as sync_invoker,
  (select public.monster_status(20, 20) is null
      and public.monster_status(10, 20) = 'bloodied'
      and public.monster_status(11, 21) is null
      and public.monster_status(0, 20) = 'down')                       as status_rule,
  (select count(*) = 1 from public.schema_migrations
    where version = '171')                                             as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the mechanics, as the table owner
-- ---------------------------------------------------------------------------
--
-- Starts a fight in a campaign that has a character, adds the character and
-- a 20 HP monster, and walks it through damage. 039's shape: every check,
-- refusals included, comes back as a row.
--
-- CORRECT OUTPUT: every outcome reads as its expected column says.
--   second_fight      refused (23505)        one live fight per campaign
--   status_at_8_dmg   null                   12/20 is not bloodied
--   status_at_10_dmg  bloodied               10/20 is
--   temp_first        hp 5, temp 0           5 temp then 10 damage: 10 -> 5
--   status_at_0       down
--   healed            hp 20, status null     heal 100 caps at 20
--   direct_status     null                   a direct write is pinned back
--   stats_on_pc       refused (23503)        stats can't hang off a PC
--   companion_named   refused (23514)        combatant_shape
--   turn_removed      null                   removing the turn's combatant
--   fight_ended       0 combatants, 0 stats  the DELETE cascades

begin;

create temp table t_out (check_name text, outcome text) on commit drop;

do $$
declare
  v_campaign  uuid;
  v_character uuid;
  v_encounter uuid;
  v_pc        uuid;
  v_monster   uuid;
  v_hp        int;
  v_temp      int;
  v_status    text;
  v_turn      uuid;
  v_n1        int;
  v_n2        int;
begin
  select c.campaign_id, c.id into v_campaign, v_character
    from public.characters c
   where not exists (select 1 from public.encounters e
                      where e.campaign_id = c.campaign_id)
   limit 1;
  if v_character is null then
    raise exception 'no character to test with: this block would prove nothing';
  end if;

  insert into public.encounters (campaign_id) values (v_campaign)
    returning id into v_encounter;

  begin
    insert into public.encounters (campaign_id) values (v_campaign);
    insert into t_out values ('second_fight', 'ACCEPTED -- UNIQUE MISSING');
  exception when unique_violation then
    insert into t_out values ('second_fight', 'refused (23505)');
  end;

  insert into public.encounter_combatants (encounter_id, kind, character_id)
    values (v_encounter, 'pc', v_character) returning id into v_pc;
  insert into public.encounter_combatants (encounter_id, kind, name, dex)
    values (v_encounter, 'monster', 'Zombie 1', 6) returning id into v_monster;
  insert into public.encounter_monster_stats (combatant_id, hp_max, hp_current, ac)
    values (v_monster, 20, 20, 8);

  perform public.adjust_monster_hp(v_monster, -8);
  select coalesce(status, 'null') into v_status
    from public.encounter_combatants where id = v_monster;
  insert into t_out values ('status_at_8_dmg', v_status);

  perform public.adjust_monster_hp(v_monster, -2);
  select coalesce(status, 'null') into v_status
    from public.encounter_combatants where id = v_monster;
  insert into t_out values ('status_at_10_dmg', v_status);

  update public.encounter_monster_stats set hp_temp = 5 where combatant_id = v_monster;
  perform public.adjust_monster_hp(v_monster, -10);
  select hp_current, hp_temp into v_hp, v_temp
    from public.encounter_monster_stats where combatant_id = v_monster;
  insert into t_out values ('temp_first', format('hp %s, temp %s', v_hp, v_temp));

  perform public.adjust_monster_hp(v_monster, -50);
  select coalesce(status, 'null') into v_status
    from public.encounter_combatants where id = v_monster;
  insert into t_out values ('status_at_0', v_status);

  perform public.adjust_monster_hp(v_monster, 100);
  select s.hp_current, coalesce(c.status, 'null') into v_hp, v_status
    from public.encounter_monster_stats s
    join public.encounter_combatants c on c.id = s.combatant_id
   where s.combatant_id = v_monster;
  insert into t_out values ('healed', format('hp %s, status %s', v_hp, v_status));

  update public.encounter_combatants set status = 'down' where id = v_monster;
  select coalesce(status, 'null') into v_status
    from public.encounter_combatants where id = v_monster;
  insert into t_out values ('direct_status', v_status);

  begin
    insert into public.encounter_monster_stats (combatant_id, hp_max, hp_current)
      values (v_pc, 10, 10);
    insert into t_out values ('stats_on_pc', 'ACCEPTED -- FK MISSING');
  exception when foreign_key_violation then
    insert into t_out values ('stats_on_pc', 'refused (23503)');
  end;

  begin
    insert into public.encounter_combatants (encounter_id, kind, character_id, name)
      values (v_encounter, 'companion', v_character, 'Clank');
    insert into t_out values ('companion_named', 'ACCEPTED -- CHECK MISSING');
  exception when check_violation then
    insert into t_out values ('companion_named', 'refused (23514)');
  end;

  update public.encounters set turn_combatant_id = v_monster where id = v_encounter;
  delete from public.encounter_combatants where id = v_monster;
  select turn_combatant_id into v_turn from public.encounters where id = v_encounter;
  insert into t_out values ('turn_removed', coalesce(v_turn::text, 'null'));

  insert into public.encounter_combatants (encounter_id, kind, name, dex)
    values (v_encounter, 'monster', 'Zombie 2', 6) returning id into v_monster;
  insert into public.encounter_monster_stats (combatant_id, hp_max, hp_current)
    values (v_monster, 20, 20);
  update public.encounters set turn_combatant_id = v_monster where id = v_encounter;
  delete from public.encounters where id = v_encounter;
  select count(*) into v_n1 from public.encounter_combatants where encounter_id = v_encounter;
  select count(*) into v_n2 from public.encounter_monster_stats where combatant_id = v_monster;
  insert into t_out values ('fight_ended', format('%s combatants, %s stats', v_n1, v_n2));
end
$$;

select * from t_out;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: who may read and write what, as a player and as the DM
-- ---------------------------------------------------------------------------
--
-- Resolves a player's character and that campaign's DM from the data (no
-- hardcoded uuids), builds a fight as the owner, then acts as each through
-- `set local role authenticated` and request.jwt.claims (122's shape).
--
-- CORRECT OUTPUT: one row per check, each result as below.
--   fixture_found            true
--   player_reads_order       2           the PC and the monster
--   player_reads_stats       0           DM-only
--   player_sets_initiative   17
--   player_kind_pinned       pc          kind is not on the allowlist
--   player_monster_init      0 rows      not their row: a silent refusal
--   player_round             0 rows      encounters is DM-write
--   player_adds_combatant    refused (42501)
--   dm_reads_stats           1
--   dm_renames_monster       Ghoul
--   dm_sets_status           null        pinned even for the DM

begin;

select set_config(
  'verification.character',
  (select c.id::text
     from public.characters c
     join public.campaign_members m
       on m.campaign_id = c.campaign_id and m.user_id = c.user_id
    where m.role = 'player'
      and exists (select 1 from public.campaign_members d
                   where d.campaign_id = c.campaign_id and d.role = 'dm')
      and not exists (select 1 from public.encounters e
                       where e.campaign_id = c.campaign_id)
    limit 1),
  true
);

do $$
declare
  v_character uuid := nullif(current_setting('verification.character'), '')::uuid;
  v_campaign  uuid;
  v_player    uuid;
  v_dm        uuid;
  v_encounter uuid;
  v_pc        uuid;
  v_monster   uuid;
begin
  if v_character is null then return; end if;

  select campaign_id, user_id into v_campaign, v_player
    from public.characters where id = v_character;
  select user_id into v_dm
    from public.campaign_members
   where campaign_id = v_campaign and role = 'dm'
   limit 1;

  insert into public.encounters (campaign_id) values (v_campaign)
    returning id into v_encounter;
  insert into public.encounter_combatants (encounter_id, kind, character_id)
    values (v_encounter, 'pc', v_character) returning id into v_pc;
  insert into public.encounter_combatants (encounter_id, kind, name, dex)
    values (v_encounter, 'monster', 'Zombie', 6) returning id into v_monster;
  insert into public.encounter_monster_stats (combatant_id, hp_max, hp_current)
    values (v_monster, 20, 20);

  perform set_config('verification.player', v_player::text, true);
  perform set_config('verification.dm', v_dm::text, true);
  perform set_config('verification.encounter', v_encounter::text, true);
  perform set_config('verification.pc', v_pc::text, true);
  perform set_config('verification.monster', v_monster::text, true);
end
$$;

set local role authenticated;

do $$
declare
  v_encounter uuid := nullif(current_setting('verification.encounter', true), '')::uuid;
  v_pc        uuid := nullif(current_setting('verification.pc', true), '')::uuid;
  v_monster   uuid := nullif(current_setting('verification.monster', true), '')::uuid;
  v_n         int;
  v_text      text;
begin
  if v_encounter is null then return; end if;

  -- As the player.
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('verification.player'),
                      'role', 'authenticated')::text, true);

  select count(*) into v_n from encounter_combatants where encounter_id = v_encounter;
  perform set_config('verification.player_reads_order', v_n::text, true);

  select count(*) into v_n from encounter_monster_stats where combatant_id = v_monster;
  perform set_config('verification.player_reads_stats', v_n::text, true);

  update encounter_combatants set initiative = 17 where id = v_pc;
  select initiative::text into v_text from encounter_combatants where id = v_pc;
  perform set_config('verification.player_sets_initiative', coalesce(v_text, 'null'), true);

  update encounter_combatants set kind = 'companion', initiative = null where id = v_pc;
  select kind into v_text from encounter_combatants where id = v_pc;
  perform set_config('verification.player_kind_pinned', v_text, true);

  update encounter_combatants set initiative = 1 where id = v_monster;
  get diagnostics v_n = row_count;
  perform set_config('verification.player_monster_init', v_n || ' rows', true);

  update encounters set round = 5 where id = v_encounter;
  get diagnostics v_n = row_count;
  perform set_config('verification.player_round', v_n || ' rows', true);

  begin
    insert into encounter_combatants (encounter_id, kind, name, dex)
      values (v_encounter, 'monster', 'Imp', 17);
    perform set_config('verification.player_adds_combatant', 'ACCEPTED -- POLICY MISSING', true);
  exception when insufficient_privilege then
    perform set_config('verification.player_adds_combatant', 'refused (42501)', true);
  end;

  -- As the DM.
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('verification.dm'),
                      'role', 'authenticated')::text, true);

  select count(*) into v_n from encounter_monster_stats where combatant_id = v_monster;
  perform set_config('verification.dm_reads_stats', v_n::text, true);

  update encounter_combatants set name = 'Ghoul' where id = v_monster;
  select name into v_text from encounter_combatants where id = v_monster;
  perform set_config('verification.dm_renames_monster', coalesce(v_text, 'null'), true);

  update encounter_combatants set status = 'down' where id = v_monster;
  select coalesce(status, 'null') into v_text from encounter_combatants where id = v_monster;
  perform set_config('verification.dm_sets_status', v_text, true);
end
$$;

reset role;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'fixture_found',          nullif(current_setting('verification.character', true), '') is not null,
         'player_reads_order',     current_setting('verification.player_reads_order', true),
         'player_reads_stats',     current_setting('verification.player_reads_stats', true),
         'player_sets_initiative', current_setting('verification.player_sets_initiative', true),
         'player_kind_pinned',     current_setting('verification.player_kind_pinned', true),
         'player_monster_init',    current_setting('verification.player_monster_init', true),
         'player_round',           current_setting('verification.player_round', true),
         'player_adds_combatant',  current_setting('verification.player_adds_combatant', true),
         'dm_reads_stats',         current_setting('verification.dm_reads_stats', true),
         'dm_renames_monster',     current_setting('verification.dm_renames_monster', true),
         'dm_sets_status',         current_setting('verification.dm_sets_status', true)
       ));

rollback;

-- db/056_character_sheet.sql
--
-- The per-character half of the sheet: ability scores, HP, race, classes and
-- proficiencies, which the Sheet page has kept in localStorage since it was a
-- mock-up. Three sibling tables of `characters`, plus an HP function and a
-- trigger that gives every character its stats row.
--
--   character_stats          one row per character: scores, HP, race, speed
--                            override, AC bonus
--   character_classes        one row per class the character has levels in;
--                            total level is the SUM, never stored
--   character_proficiencies  saves, skills (and expertise), weapons, armour,
--                            tools, languages; one row per proficiency
--
-- WHY SIBLINGS AND NOT COLUMNS ON characters. The decision was that the DM can
-- edit a player's stats (fix HP mid-fight, level everyone up), the same line
-- 028 drew for gear, spells and feats. characters' own UPDATE policy is
-- owner-only, and can_edit_character must not be used in characters' own
-- policies (028's warning). So DM-editable data cannot be a column there. It
-- also keeps pin_character_row's blocklist from silently making ~20 new
-- columns client-writable (CLAUDE.md, "The pin triggers are blocklists").
--
-- ALL THREE USE 046's FOUR-POLICY SHAPE: SELECT is "can you see the
-- character" (the EXISTS that fails closed), INSERT/UPDATE/DELETE are
-- can_edit_character. Four, not 037's three, because each has a mutable column
-- that an update genuinely changes.
--
-- PIN TRIGGERS on all three, 047's reasoning: a DM passes can_edit_character on
-- every sheet in the campaign, so without a pin an UPDATE could move a stats
-- row or a proficiency from one character to another. Key columns are reset
-- silently, not raised.
--
-- NOTHING DERIVED IS STORED. Modifiers, proficiency bonus, AC, attacks, spell
-- DC, passive scores and hit dice are computed on the client from these
-- inputs, so the database cannot hold a number that disagrees with its own
-- inputs. speed_override is null to mean "use the race's speed".
--
-- character_classes:
--   * class_id has no ON DELETE action (NO ACTION, checked at end of
--     statement), not RESTRICT (checked immediately). Deleting a campaign
--     cascades to both its homebrew classes and its characters; NO ACTION
--     lets the whole cascade finish before checking, RESTRICT would refuse it.
--   * The subclass FK is composite, (subclass_id, class_id) -> subclasses(id,
--     class_id), so a subclass of the wrong class is unrepresentable. Its ON
--     DELETE SET NULL names its column, the npcs/locations shape, so deleting
--     a subclass nulls subclass_id and leaves class_id alone (Postgres 15+).
--   * is_starting marks the class the character began in; in 5e that class,
--     and only that class, grants saving throws. One per character, by a
--     partial unique index. Saves themselves are still proficiency rows the
--     client writes when the class is picked, so a feat like Resilient can
--     add one.
--
-- character_proficiencies:
--   * No row means untrained. There is no stored 0: 046's "absence is the only
--     spelling" rule. Clearing a proficiency is a DELETE.
--   * The CHECK ties 'save' keys to the six abilities and 'skill' keys to the
--     eighteen skills, the same codes as ABILITIES and SKILLS in
--     src/data/rules.ts. One list in two places; change them together.
--   * level 2 (expertise) only for skills and tools.
--   * A 'weapon' row's key is an items.id as text: a per-weapon override of the
--     class's simple/martial default. No FK, like 042's map_key, because the
--     same column also holds free-text keys for tools and languages.
--
-- THE STATS ROW EXISTS FOR EVERY CHARACTER, so the client only ever UPDATEs:
--   * create_character_stats_row, an AFTER INSERT trigger on characters,
--     writes one with defaults. SECURITY INVOKER: the inserting owner passes
--     the INSERT policy, and the demo fixture runs as the table owner. It is
--     the only AFTER INSERT trigger on characters, so there is no firing order
--     to worry about (contrast 048's warning on campaigns).
--   * The backfill below gives every existing character one.
--
-- adjust_character_hp(target, delta) is one UPDATE, 045's shape, so a DM and a
-- player applying damage in the same round can't lose each other's change.
-- Damage drains temporary HP first and floors at 0; healing caps at hp_max and
-- never lowers HP that's already above it. SECURITY INVOKER: RLS is still the
-- boundary, and a refused or missing target returns no rows.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.
--
-- RUN THE MIGRATION BLOCK BELOW ON ITS OWN, then the verification blocks one at
-- a time.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- ---------- character_stats ----------

create table public.character_stats (
  character_id uuid primary key references public.characters(id) on delete cascade,
  race_id uuid references public.races(id) on delete set null,

  strength     smallint not null default 10 check (strength between 1 and 30),
  dexterity    smallint not null default 10 check (dexterity between 1 and 30),
  constitution smallint not null default 10 check (constitution between 1 and 30),
  intelligence smallint not null default 10 check (intelligence between 1 and 30),
  wisdom       smallint not null default 10 check (wisdom between 1 and 30),
  charisma     smallint not null default 10 check (charisma between 1 and 30),

  hp_max smallint not null default 1 check (hp_max between 1 and 999),
  hp_current smallint not null default 1 check (hp_current between 0 and 999),
  hp_temp smallint not null default 0 check (hp_temp between 0 and 999),

  speed_override smallint check (speed_override between 0 and 120),
  ac_bonus smallint not null default 0 check (ac_bonus between -10 and 20),

  updated_at timestamptz not null default now()
);

alter table public.character_stats enable row level security;

create policy "character viewers read stats"
  on public.character_stats for select to authenticated
  using (
    exists (
      select 1 from characters c
      where c.id = character_stats.character_id
    )
  );

create policy "owner or dm creates stats"
  on public.character_stats for insert to authenticated
  with check (public.can_edit_character(character_id));

create policy "owner or dm edits stats"
  on public.character_stats for update to authenticated
  using (public.can_edit_character(character_id))
  with check (public.can_edit_character(character_id));

create policy "owner or dm deletes stats"
  on public.character_stats for delete to authenticated
  using (public.can_edit_character(character_id));

create or replace function public.pin_character_stats_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
begin
  new.character_id := old.character_id;
  new.updated_at   := now();
  return new;
end;
$function$
;

create trigger pin_character_stats_row
  before update on public.character_stats
  for each row execute function public.pin_character_stats_row();

-- ---------- character_classes ----------

create table public.character_classes (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters(id) on delete cascade,
  class_id uuid not null references public.classes(id),
  subclass_id uuid,

  level smallint not null default 1 check (level between 1 and 20),
  is_starting boolean not null default false,

  created_at timestamptz not null default now(),

  unique (character_id, class_id),
  foreign key (subclass_id, class_id)
    references public.subclasses (id, class_id)
    on delete set null (subclass_id)
);

-- At most one starting class per character.
create unique index character_classes_one_starting
  on public.character_classes (character_id)
  where is_starting;

alter table public.character_classes enable row level security;

create policy "character viewers read classes"
  on public.character_classes for select to authenticated
  using (
    exists (
      select 1 from characters c
      where c.id = character_classes.character_id
    )
  );

create policy "owner or dm adds classes"
  on public.character_classes for insert to authenticated
  with check (public.can_edit_character(character_id));

create policy "owner or dm edits classes"
  on public.character_classes for update to authenticated
  using (public.can_edit_character(character_id))
  with check (public.can_edit_character(character_id));

create policy "owner or dm removes classes"
  on public.character_classes for delete to authenticated
  using (public.can_edit_character(character_id));

create or replace function public.pin_character_class_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
begin
  new.id           := old.id;
  new.character_id := old.character_id;
  new.created_at   := old.created_at;
  return new;
end;
$function$
;

create trigger pin_character_class_row
  before update on public.character_classes
  for each row execute function public.pin_character_class_row();

-- ---------- character_proficiencies ----------

create table public.character_proficiencies (
  character_id uuid not null references public.characters(id) on delete cascade,
  kind text not null
    check (kind in ('save', 'skill', 'weapon', 'armor', 'tool', 'language')),
  key text not null,
  level smallint not null default 1 check (level in (1, 2)),

  primary key (character_id, kind, key),

  constraint character_proficiencies_key_valid check (
    (kind = 'save'
      and key in ('str', 'dex', 'con', 'int', 'wis', 'cha'))
    or (kind = 'skill'
      and key in ('acrobatics', 'animalHandling', 'arcana', 'athletics',
                  'deception', 'history', 'insight', 'intimidation',
                  'investigation', 'medicine', 'nature', 'perception',
                  'performance', 'persuasion', 'religion', 'sleightOfHand',
                  'stealth', 'survival'))
    or (kind in ('weapon', 'armor', 'tool', 'language')
      and length(btrim(key)) between 1 and 60)
  ),

  -- Expertise exists for skills and tools only.
  constraint character_proficiencies_expertise_kinds
    check (level = 1 or kind in ('skill', 'tool'))
);

alter table public.character_proficiencies enable row level security;

create policy "character viewers read proficiencies"
  on public.character_proficiencies for select to authenticated
  using (
    exists (
      select 1 from characters c
      where c.id = character_proficiencies.character_id
    )
  );

create policy "owner or dm adds proficiencies"
  on public.character_proficiencies for insert to authenticated
  with check (public.can_edit_character(character_id));

create policy "owner or dm edits proficiencies"
  on public.character_proficiencies for update to authenticated
  using (public.can_edit_character(character_id))
  with check (public.can_edit_character(character_id));

create policy "owner or dm removes proficiencies"
  on public.character_proficiencies for delete to authenticated
  using (public.can_edit_character(character_id));

-- Only `level` is meant to change (proficient <-> expertise); the key columns
-- are pinned.
create or replace function public.pin_character_proficiency_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
begin
  new.character_id := old.character_id;
  new.kind         := old.kind;
  new.key          := old.key;
  return new;
end;
$function$
;

create trigger pin_character_proficiency_row
  before update on public.character_proficiencies
  for each row execute function public.pin_character_proficiency_row();

-- ---------- every character gets a stats row ----------

create or replace function public.create_character_stats_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
begin
  insert into character_stats (character_id) values (new.id);
  return null;
end;
$function$
;

create trigger create_character_stats_row
  after insert on public.characters
  for each row execute function public.create_character_stats_row();

insert into public.character_stats (character_id)
select c.id from public.characters c
where not exists (
  select 1 from public.character_stats s where s.character_id = c.id
);

-- ---------- HP ----------

create or replace function public.adjust_character_hp(
  target_character uuid,
  delta int
)
 returns setof public.character_stats
 language sql
 security invoker
 set search_path to 'public'
as $function$
  -- Every right-hand side reads the OLD row, so hp_current's damage branch
  -- sees the temp HP from before this update.
  update character_stats set
    hp_temp = case
      when delta < 0 then greatest(0, hp_temp + delta)
      else hp_temp
    end,
    hp_current = case
      when delta < 0 then greatest(0, hp_current + least(0, hp_temp + delta))
      else greatest(hp_current, least(hp_max, hp_current + delta))
    end
  where character_id = target_character
  returning *;
$function$
;

insert into public.schema_migrations (version) values ('056');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Each block is independent. Run them one at a time. Blocks that write end in
-- `rollback`, so nothing here survives.
--
-- Every refusal on UPDATE is a zero-row success, not an error, so these blocks
-- report rows_updated rather than catching 42501. Blocks that need a character
-- resolve Nat's in campaign A first and report target_found, so "zero rows"
-- can't mean "there was nothing to hit".
--
--   campaign A   d721b412-2750-492e-bddd-7387fc464bba   The cool kids
--   player of A  1313672b-6990-45a6-8a28-c448ca116d2d   Nat
--   DM of A      ea74d56b-8f45-4e4c-80f8-90a6d29b5adf   Dlizard72


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist, and every character has a stats row
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

select
  (select count(*) = 4 from pg_policies
    where schemaname = 'public' and tablename = 'character_stats')         as stats_4_policies,
  (select count(*) = 4 from pg_policies
    where schemaname = 'public' and tablename = 'character_classes')       as classes_4_policies,
  (select count(*) = 4 from pg_policies
    where schemaname = 'public' and tablename = 'character_proficiencies') as profs_4_policies,
  (select count(*) = 4 from pg_trigger
    where tgname in ('pin_character_stats_row', 'pin_character_class_row',
                     'pin_character_proficiency_row',
                     'create_character_stats_row'))                         as four_triggers,
  (select bool_and(not prosecdef) from pg_proc
    where proname in ('pin_character_stats_row', 'pin_character_class_row',
                      'pin_character_proficiency_row',
                      'create_character_stats_row', 'adjust_character_hp')) as all_invoker,
  (select count(*) = 0 from public.characters c
    where not exists (select 1 from public.character_stats s
                      where s.character_id = c.id))                         as every_character_has_stats,
  (select count(*) = 1 from public.schema_migrations where version = '056') as ledger_row;


-- ---------------------------------------------------------------------------
-- BLOCK 1: owner, DM and a stranger each try to edit Nat's stats
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: target_found = true; owner_rows = 1; dm_rows = 1;
-- stranger_rows = 0; str_now = 16 (the DM's write, the last one that landed).

begin;

select set_config(
  'verification.nat_character',
  (select id::text from public.characters
    where campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
      and user_id = '1313672b-6990-45a6-8a28-c448ca116d2d'),
  true
);

create temp table results (k text, v text) on commit drop;
grant all on results to authenticated;
insert into results
  values ('target_found', (current_setting('verification.nat_character', true) is not null)::text);

set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"1313672b-6990-45a6-8a28-c448ca116d2d","role":"authenticated"}', true);
with u as (
  update public.character_stats set strength = 15
   where character_id = current_setting('verification.nat_character')::uuid
  returning 1
) insert into results select 'owner_rows', count(*)::text from u;

select set_config('request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}', true);
with u as (
  update public.character_stats set strength = 16
   where character_id = current_setting('verification.nat_character')::uuid
  returning 1
) insert into results select 'dm_rows', count(*)::text from u;

-- Someone in no campaign at all.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
with u as (
  update public.character_stats set strength = 3
   where character_id = current_setting('verification.nat_character')::uuid
  returning 1
) insert into results select 'stranger_rows', count(*)::text from u;

reset role;
insert into results
  select 'str_now', strength::text from public.character_stats
   where character_id = current_setting('verification.nat_character')::uuid;

select * from results;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: the pin trigger stops the DM moving a stats row
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: rows_updated = 1, character_id_unchanged = true.

begin;

select set_config(
  'verification.nat_character',
  (select id::text from public.characters
    where campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
      and user_id = '1313672b-6990-45a6-8a28-c448ca116d2d'),
  true
);
select set_config('request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}', true);
set local role authenticated;

with u as (
  update public.character_stats
     set character_id = gen_random_uuid(), dexterity = 14
   where character_id = current_setting('verification.nat_character')::uuid
  returning character_id
)
select 'case 2: pin' as check,
       jsonb_build_object(
         'rows_updated', (select count(*) from u),
         'character_id_unchanged',
           (select bool_and(character_id = current_setting('verification.nat_character')::uuid) from u)
       ) as result;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 3: adjust_character_hp — temp HP first, healing capped
-- ---------------------------------------------------------------------------
--
-- Starts Nat at 15/20 with 5 temp, takes 7, then heals 100.
--
-- CORRECT OUTPUT: two rows: after_damage {"cur": 13, "temp": 0},
--                           after_heal   {"cur": 20, "temp": 0}.

begin;

select set_config(
  'verification.nat_character',
  (select id::text from public.characters
    where campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
      and user_id = '1313672b-6990-45a6-8a28-c448ca116d2d'),
  true
);

update public.character_stats set hp_max = 20, hp_current = 15, hp_temp = 5
 where character_id = current_setting('verification.nat_character')::uuid;

create temp table results (step text, hp jsonb) on commit drop;
grant all on results to authenticated;

select set_config('request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}', true);
set local role authenticated;

-- Two separate statements, so the heal is guaranteed to see the damage.
insert into results
  select 'after_damage', jsonb_build_object('cur', hp_current, 'temp', hp_temp)
    from public.adjust_character_hp(current_setting('verification.nat_character')::uuid, -7);
insert into results
  select 'after_heal', jsonb_build_object('cur', hp_current, 'temp', hp_temp)
    from public.adjust_character_hp(current_setting('verification.nat_character')::uuid, 100);

select * from results;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 4: a new character gets a stats row, through RLS
-- ---------------------------------------------------------------------------
--
-- The DM creates a character of their own in campaign A, as an authenticated
-- user, so the trigger's INSERT has to pass the policy rather than run as
-- owner. If the DM already has a character there, the block says so instead.
--
-- CORRECT OUTPUT: outcome = 'stats row created'
--             (or 'skipped: DM already has a character in A').

begin;

create temp table results (outcome text) on commit drop;
grant all on results to authenticated;

select set_config('request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  new_id uuid;
begin
  insert into public.characters (campaign_id, user_id, name)
  values ('d721b412-2750-492e-bddd-7387fc464bba',
          'ea74d56b-8f45-4e4c-80f8-90a6d29b5adf', 'Stats Trigger Test')
  returning id into new_id;

  insert into results
  select case when exists (select 1 from public.character_stats
                            where character_id = new_id)
              then 'stats row created' else 'NO STATS ROW' end;
exception when unique_violation then
  insert into results values ('skipped: DM already has a character in A');
end $$;

select * from results;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 5: the proficiency CHECKs
-- ---------------------------------------------------------------------------
--
-- A made-up skill, expertise on a save, and a valid expertise on Stealth.
-- Runs as owner: this is about the CHECKs, not RLS.
--
-- CORRECT OUTPUT: fake_skill = refused, save_expertise = refused,
-- stealth_expertise = ok.

begin;

select set_config(
  'verification.nat_character',
  (select id::text from public.characters
    where campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
      and user_id = '1313672b-6990-45a6-8a28-c448ca116d2d'),
  true
);

create temp table results (check_name text, outcome text) on commit drop;

do $$
declare
  cid uuid := current_setting('verification.nat_character')::uuid;
begin
  begin
    insert into public.character_proficiencies values (cid, 'skill', 'juggling', 1);
    insert into results values ('fake_skill', 'ok');
  exception when check_violation then
    insert into results values ('fake_skill', 'refused');
  end;
  begin
    insert into public.character_proficiencies values (cid, 'save', 'dex', 2);
    insert into results values ('save_expertise', 'ok');
  exception when check_violation then
    insert into results values ('save_expertise', 'refused');
  end;
  begin
    insert into public.character_proficiencies values (cid, 'skill', 'stealth', 2);
    insert into results values ('stealth_expertise', 'ok');
  exception when check_violation then
    insert into results values ('stealth_expertise', 'refused');
  end;
end $$;

select * from results;

rollback;

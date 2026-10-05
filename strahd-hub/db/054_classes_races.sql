-- db/054_classes_races.sql
--
-- The class, subclass and race catalogues: the first half of moving the
-- character sheet off localStorage. Until now the twelve classes and nine
-- races lived as constants in src/data/rules.ts, which meant no homebrew and
-- nowhere for class features to hang later. 055 seeds the shared rows; 056
-- adds the per-character tables that point at them.
--
-- ALL THREE ARE 039's FEATS TABLE IN SHAPE, for 039's reasons:
--   campaign_id null      -- the shared catalogue, seeded by migration only
--   campaign_id not null  -- one campaign's homebrew, written by its DM
-- Same read policy (shared, or a campaign you're a member of), same INSERT
-- policy (`campaign_id is not null and is_campaign_dm`), same index. No UPDATE
-- or DELETE policy yet: 053's homebrew-edit shape is the template when wanted,
-- and needs a pin trigger beside it.
--
-- WHAT IS A COLUMN AND WHAT IS NOT. A column here is a fact the sheet computes
-- with: hit die (hit dice, average HP), the two save proficiencies (set when
-- the class is picked), spell_ability (spell DC and attack), weapon_training
-- (default weapon proficiency), unarmored_ability (Unarmored Defense, because
-- it changes the AC number), subclass_level (when the subclass picker opens).
-- Everything descriptive is `description` text. Class FEATURES are not here:
-- they get their own catalogue later (class_id, subclass_id, level), the way
-- feats are not columns on anything.
--
-- THE ABILITY CODES ('str' .. 'cha') ARE ONE LIST IN TWO PLACES: these CHECKs
-- and ABILITIES / SPELL_ABILITIES in src/data/rules.ts. Change them together,
-- as with featCategories and 039's CHECK (CLAUDE.md).
--
-- SUBCLASSES CARRY unique (id, class_id) so 056 can give character_classes a
-- composite FK: "a Wizard with the Path of the Berserker" is then
-- unrepresentable, the same trick 028 uses against a character for a
-- non-member.
--
-- ⚠ THE CROSS-CAMPAIGN HOMEBREW HOLE 041 DOCUMENTS APPLIES HERE TOO. A DM of
-- campaigns A and B can create a class in B and attach it to a character in
-- A. Same exposure, same reason it's left open; the client never offers it,
-- because its pickers read getClasses(campaignId).
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`. No
-- client reads these tables until the sheet is switched over.
--
-- RUN THE MIGRATION BLOCK BELOW ON ITS OWN, then the verification blocks one at
-- a time.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid references public.campaigns(id) on delete cascade,

  name text not null check (length(btrim(name)) between 1 and 60),
  description text not null default '',

  hit_die smallint not null check (hit_die in (6, 8, 10, 12)),
  save_proficiencies text[] not null check (
    cardinality(save_proficiencies) = 2
    and save_proficiencies <@ array['str', 'dex', 'con', 'int', 'wis', 'cha']
  ),
  spell_ability text check (spell_ability in ('int', 'wis', 'cha')),
  weapon_training text not null check (weapon_training in ('simple', 'martial')),
  unarmored_ability text check (
    unarmored_ability in ('str', 'dex', 'con', 'int', 'wis', 'cha')
  ),
  subclass_level smallint not null default 3 check (subclass_level between 1 and 20),

  created_at timestamptz not null default now()
);

create table public.subclasses (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  campaign_id uuid references public.campaigns(id) on delete cascade,

  name text not null check (length(btrim(name)) between 1 and 60),
  description text not null default '',
  -- Eldritch Knight and Arcane Trickster cast though their class doesn't.
  spell_ability text check (spell_ability in ('int', 'wis', 'cha')),

  created_at timestamptz not null default now(),

  -- The target of 056's composite FK. id alone is already unique; this pair
  -- exists so (subclass_id, class_id) can be referenced together.
  unique (id, class_id)
);

create table public.races (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid references public.campaigns(id) on delete cascade,

  name text not null check (length(btrim(name)) between 1 and 60),
  description text not null default '',
  speed smallint not null check (speed between 0 and 120),
  size text not null default 'medium'
    check (size in ('tiny', 'small', 'medium', 'large')),

  created_at timestamptz not null default now()
);

-- 022's index, for 022's read: `campaign_id is null or campaign_id = $1`.
create index on public.classes (campaign_id);
create index on public.subclasses (campaign_id);
create index on public.subclasses (class_id);
create index on public.races (campaign_id);

alter table public.classes enable row level security;
alter table public.subclasses enable row level security;
alter table public.races enable row level security;

create policy "read shared and own-campaign classes"
  on public.classes for select to authenticated
  using (campaign_id is null or public.is_campaign_member(campaign_id));

create policy "dms create homebrew classes"
  on public.classes for insert to authenticated
  with check (campaign_id is not null and public.is_campaign_dm(campaign_id));

create policy "read shared and own-campaign subclasses"
  on public.subclasses for select to authenticated
  using (campaign_id is null or public.is_campaign_member(campaign_id));

create policy "dms create homebrew subclasses"
  on public.subclasses for insert to authenticated
  with check (campaign_id is not null and public.is_campaign_dm(campaign_id));

create policy "read shared and own-campaign races"
  on public.races for select to authenticated
  using (campaign_id is null or public.is_campaign_member(campaign_id));

create policy "dms create homebrew races"
  on public.races for insert to authenticated
  with check (campaign_id is not null and public.is_campaign_dm(campaign_id));

insert into public.schema_migrations (version) values ('054');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Each block is independent. Run them one at a time. Blocks that write end in
-- `rollback`, so nothing here survives.
--
--   campaign A   d721b412-2750-492e-bddd-7387fc464bba   The cool kids
--   player of A  1313672b-6990-45a6-8a28-c448ca116d2d   Nat
--   DM of A      ea74d56b-8f45-4e4c-80f8-90a6d29b5adf   Dlizard72


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist
-- ---------------------------------------------------------------------------
--
-- Two policies per table, exactly: a third is a write path nobody decided on.
--
-- CORRECT OUTPUT: one row, every column `t`.

select
  (select count(*) = 2 from pg_policies
    where schemaname = 'public' and tablename = 'classes')     as classes_2_policies,
  (select count(*) = 2 from pg_policies
    where schemaname = 'public' and tablename = 'subclasses')  as subclasses_2_policies,
  (select count(*) = 2 from pg_policies
    where schemaname = 'public' and tablename = 'races')       as races_2_policies,
  (select bool_and(relrowsecurity) from pg_class
    where oid in ('public.classes'::regclass,
                  'public.subclasses'::regclass,
                  'public.races'::regclass))                  as rls_on,
  (select count(*) = 1 from public.schema_migrations
    where version = '054')                                     as ledger_row;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the DM creates homebrew; a player is refused
-- ---------------------------------------------------------------------------
--
-- 039's shape: each outcome is caught and stashed with set_config, then read
-- back in one row, so a passing refusal doesn't paint the editor red
-- (CLAUDE.md).
--
-- CORRECT OUTPUT: one row: dm_insert = 'ok',
--                          player_insert = 'denied by RLS (42501)'.

begin;

select set_config(
  'request.jwt.claims',
  '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}',
  true
);
set local role authenticated;

do $$
begin
  insert into public.classes (campaign_id, name, hit_die, save_proficiencies, weapon_training)
  values ('d721b412-2750-492e-bddd-7387fc464bba', 'Test Blood Hunter', 10,
          array['dex', 'int'], 'martial');
  perform set_config('verification.dm_insert', 'ok', true);
exception
  when insufficient_privilege then
    perform set_config('verification.dm_insert', 'denied by RLS (42501)', true);
end
$$;

select set_config(
  'request.jwt.claims',
  '{"sub":"1313672b-6990-45a6-8a28-c448ca116d2d","role":"authenticated"}',
  true
);

do $$
begin
  insert into public.classes (campaign_id, name, hit_die, save_proficiencies, weapon_training)
  values ('d721b412-2750-492e-bddd-7387fc464bba', 'Sneaky Player Class', 12,
          array['str', 'con'], 'martial');
  perform set_config('verification.player_insert', 'INSERT SUCCEEDED -- LEAK', true);
exception
  when insufficient_privilege then
    perform set_config('verification.player_insert', 'denied by RLS (42501)', true);
end
$$;

select 'case 1: homebrew classes' as check,
       jsonb_build_object(
         'dm_insert',     current_setting('verification.dm_insert'),
         'player_insert', current_setting('verification.player_insert')
       ) as result;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: the CHECKs refuse a malformed class
-- ---------------------------------------------------------------------------
--
-- Three saves, a d7 and a STR caster, each its own attempt. Runs as the table
-- owner: this is about the CHECKs, not RLS.
--
-- CORRECT OUTPUT: one row, all three 'refused (23514)'.

begin;

do $$
begin
  begin
    insert into public.classes (name, hit_die, save_proficiencies, weapon_training)
    values ('Three Saves', 8, array['str', 'dex', 'con'], 'simple');
    perform set_config('verification.three_saves', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.three_saves', 'refused (23514)', true);
  end;
  begin
    insert into public.classes (name, hit_die, save_proficiencies, weapon_training)
    values ('D7', 7, array['str', 'dex'], 'simple');
    perform set_config('verification.d7', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.d7', 'refused (23514)', true);
  end;
  begin
    insert into public.classes (name, hit_die, save_proficiencies, weapon_training, spell_ability)
    values ('Str Caster', 8, array['str', 'dex'], 'simple', 'str');
    perform set_config('verification.str_caster', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.str_caster', 'refused (23514)', true);
  end;
end
$$;

select 'case 2: malformed classes' as check,
       jsonb_build_object(
         'three_saves', current_setting('verification.three_saves'),
         'd7',          current_setting('verification.d7'),
         'str_caster',  current_setting('verification.str_caster')
       ) as result;

rollback;

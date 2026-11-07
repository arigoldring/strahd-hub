-- db/161_weapon_proficiency_magic_weapons.sql
--
-- Two things the attack table needs that the schema couldn't say:
--
--   1. WHICH WEAPONS A CLASS KNOWS. classes.weapon_training was 'simple' or
--      'martial', and 055's header called that an approximation. It was wrong
--      for six classes: the 2014 Wizard and Sorcerer know five weapons
--      (dagger, dart, sling, quarterstaff, light crossbow), the Druid ten, and
--      the Bard, Rogue and Monk get named weapons on top of simple ones. So:
--        * weapon_training gains 'none', for a class with no whole category;
--        * weapon_proficiencies text[] lists the named weapons beside it;
--        * multiclass_grants_weapons says whether taking the class as a
--          second class grants its weapons. The PHB's multiclassing table
--          gives weapons for Barbarian, Fighter, Paladin, Ranger (simple and
--          martial), Monk (simple and shortswords) and Warlock (simple), and
--          none for the rest. Every class whose table row grants weapons
--          grants exactly its own list, so one boolean is exact.
--
--      Names, not item ids, because proficiency is with *longswords*, not
--      with one row of the items table. No FK: a text[] can't carry one, and
--      a homebrew class may name a homebrew weapon. 162 asserts every seeded
--      name matches a shared weapon row, since a misspelt name matches
--      nothing and fails silently.
--
--   2. MAGIC WEAPONS THAT ARE WEAPONS. 130-137 seeded every magic weapon as
--      kind = 'general' text (KNOWN_ISSUES, "Magic items are text"), because
--      most are "any sword". The DM makes the concrete one ("+1 Longsword")
--      as homebrew, so the row needs:
--        * magic_bonus smallint, 1-3: added to attack and damage rolls with a
--          weapon (and, later, to AC on armour; the column allows armour so
--          that needs no migration, but no client reads it there yet);
--        * base_weapon_id: the shared, mundane weapon this one *is*. It
--          decides proficiency (a +1 Longsword is a longsword) and nothing
--          else. Dice and properties are still copied onto the row, because
--          001's weapon_fields_required needs them there, and the 2014 stats
--          of a longsword don't change, so the copy can't drift in practice.
--
--      A CHECK can't look at another row, so `check_item_base_weapon` (a
--      BEFORE INSERT/UPDATE trigger) refuses a base that isn't a shared,
--      mundane weapon with no base of its own. It raises 23514, so a refusal
--      reads like the CHECKs beside it. Without it a DM could point a weapon
--      at another campaign's homebrew, or at a general item, and the sheet
--      would read proficiency off a row the player can't see.
--
-- SCHEMA ONLY, the 159/160 split: this file writes no 'none', so the deployed
-- client (whose WEAPON_TRAINING tuple doesn't know it) keeps working, and it
-- ignores the new columns. 162 fills the class lists and re-keys weapon
-- proficiency rows AFTER the client that reads them is deployed.
--
-- PIN TRIGGER: pin_item_row is a blocklist (053), so magic_bonus and
-- base_weapon_id are DM-editable on homebrew, which is the point. Shared rows
-- have no UPDATE policy. classes has no UPDATE policy either, so its two new
-- columns are owner-only after insert.
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

-- ---- classes ---------------------------------------------------------------

alter table public.classes drop constraint classes_weapon_training_check;
alter table public.classes
  add constraint classes_weapon_training_check
    check (weapon_training in ('none', 'simple', 'martial')),
  add column weapon_proficiencies text[] not null default '{}',
  add column multiclass_grants_weapons boolean not null default false;

-- ---- items -----------------------------------------------------------------

alter table public.items
  add column magic_bonus smallint
    check (magic_bonus between 1 and 3),
  add column base_weapon_id uuid
    references public.items(id) on delete restrict;

alter table public.items
  -- A +1 is magic: rarity null is the only spelling of mundane (129).
  add constraint magic_bonus_needs_rarity
    check (magic_bonus is null or rarity is not null),
  add constraint magic_bonus_kinds
    check (magic_bonus is null or kind in ('weapon', 'armor')),
  add constraint base_weapon_only_on_weapons
    check (base_weapon_id is null or kind = 'weapon'),
  add constraint base_weapon_not_self
    check (base_weapon_id is distinct from id);

create or replace function public.check_item_base_weapon()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
begin
  if new.base_weapon_id is null then
    return new;
  end if;
  -- Invoker: the base is read through items' own SELECT policy, and shared
  -- rows are readable by every member, so a valid base is always visible.
  if not exists (
    select 1 from public.items b
     where b.id = new.base_weapon_id
       and b.campaign_id is null
       and b.kind = 'weapon'
       and b.rarity is null
       and b.base_weapon_id is null
  ) then
    raise exception 'base weapon must be a shared, mundane weapon'
      using errcode = '23514';
  end if;
  return new;
end;
$function$
;

create trigger check_item_base_weapon
  before insert or update of base_weapon_id on public.items
  for each row execute function public.check_item_base_weapon();

-- ---- Assert the end state. -------------------------------------------------
do $$
declare
  v_count int;
begin
  select count(*) into v_count
    from information_schema.columns
   where table_schema = 'public'
     and ((table_name = 'classes'
           and column_name in ('weapon_proficiencies', 'multiclass_grants_weapons'))
       or (table_name = 'items'
           and column_name in ('magic_bonus', 'base_weapon_id')));
  if v_count <> 4 then
    raise exception '% of 4 new columns exist. Rolled back.', v_count;
  end if;

  -- Nothing is written yet: 162 fills the lists after the client deploys.
  if exists (select 1 from public.classes where weapon_training = 'none') then
    raise exception 'a class is already ''none''; that is 162''s job. Rolled back.';
  end if;
end
$$;

insert into public.schema_migrations (version) values ('161');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 4 from information_schema.columns
    where table_schema = 'public'
      and column_name in ('weapon_proficiencies', 'multiclass_grants_weapons',
                          'magic_bonus', 'base_weapon_id'))            as columns,
  (select count(*) = 4 from pg_constraint
    where conrelid = 'public.items'::regclass
      and conname in ('magic_bonus_needs_rarity', 'magic_bonus_kinds',
                      'base_weapon_only_on_weapons',
                      'base_weapon_not_self'))                         as checks,
  (select count(*) = 1 from pg_trigger
    where tgrelid = 'public.items'::regclass
      and tgname = 'check_item_base_weapon')                           as trigger,
  (select not prosecdef from pg_proc
    where proname = 'check_item_base_weapon')                          as invoker,
  (select count(*) = 1 from public.schema_migrations
    where version = '161')                                             as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the base weapon trigger accepts a longsword and refuses the rest
-- ---------------------------------------------------------------------------
--
-- 039's shape: each attempt is caught and reported as a row. Runs as the
-- table owner, so RLS isn't what refuses anything here; the trigger and the
-- CHECKs are.
-- CORRECT OUTPUT: four rows:
--   shared longsword   ACCEPTED
--   general item       refused (23514)
--   homebrew weapon    refused (23514)
--   on a general item  refused (23514)

begin;

do $$
declare
  v_campaign uuid := (select id from public.campaigns limit 1);
  v_longsword uuid := (select id from public.items
                        where campaign_id is null and name = 'Longsword');
  v_rope uuid := (select id from public.items
                   where campaign_id is null and kind = 'general' limit 1);
  v_homebrew uuid;
begin
  -- A homebrew mundane weapon to point at (and to be refused as a base).
  insert into public.items (campaign_id, name, description, price_cp, tags,
                            kind, weapon_category, damage_dice, damage_type)
  values (v_campaign, 'Verification Blade', 'x', 0, '{}',
          'weapon', 'martial', '1d8', 'slashing')
  returning id into v_homebrew;

  begin
    insert into public.items (campaign_id, name, description, price_cp, tags,
                              kind, weapon_category, damage_dice, damage_type,
                              rarity, magic_bonus, base_weapon_id)
    values (v_campaign, '+1 Longsword (verification)', 'x', 0, '{}',
            'weapon', 'martial', '1d8', 'slashing', 'uncommon', 1, v_longsword);
    perform set_config('verification.a', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.a', 'refused (23514)', true);
  end;

  begin
    update public.items set base_weapon_id = v_rope where id = v_homebrew;
    perform set_config('verification.b', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.b', 'refused (23514)', true);
  end;

  begin
    insert into public.items (campaign_id, name, description, price_cp, tags,
                              kind, weapon_category, damage_dice, damage_type,
                              base_weapon_id)
    values (v_campaign, 'Copy (verification)', 'x', 0, '{}',
            'weapon', 'martial', '1d8', 'slashing', v_homebrew);
    perform set_config('verification.c', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.c', 'refused (23514)', true);
  end;

  begin
    insert into public.items (campaign_id, name, description, price_cp, tags,
                              kind, base_weapon_id)
    values (v_campaign, 'Not a weapon (verification)', 'x', 0, '{}',
            'general', v_longsword);
    perform set_config('verification.d', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.d', 'refused (23514)', true);
  end;
end
$$;

select 'shared longsword' as attempt, current_setting('verification.a') as result
union all select 'general item', current_setting('verification.b')
union all select 'homebrew weapon', current_setting('verification.c')
union all select 'on a general item', current_setting('verification.d');

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: a +1 must be magic, and only on weapons and armour
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: three rows, every result 'refused (23514)'.

begin;

do $$
declare
  v_id uuid := (select id from public.items
                 where campaign_id is null and name = 'Longsword');
  v_general uuid := (select id from public.items
                      where campaign_id is null and kind = 'general'
                        and rarity is not null limit 1);
begin
  begin
    update public.items set magic_bonus = 1 where id = v_id;  -- mundane
    perform set_config('verification.a', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.a', 'refused (23514)', true);
  end;
  begin
    update public.items set magic_bonus = 1 where id = v_general;  -- general
    perform set_config('verification.b', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.b', 'refused (23514)', true);
  end;
  begin
    update public.items set rarity = 'rare', magic_bonus = 4 where id = v_id;
    perform set_config('verification.c', 'ACCEPTED', true);
  exception when check_violation then
    perform set_config('verification.c', 'refused (23514)', true);
  end;
end
$$;

select 'bonus on a mundane weapon' as attempt, current_setting('verification.a') as result
union all select 'bonus on a general item', current_setting('verification.b')
union all select '+4', current_setting('verification.c');

rollback;

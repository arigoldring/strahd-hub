-- db/083_fighting_style_options.sql
--
-- Each Fighting Style feature row says which styles its picker offers. Until
-- now the sheet offered all eleven to anyone with the feature, which was right
-- only because the Fighter was the only class seeded with one. 089 (Paladin)
-- and 090 (Ranger) seed the other two, and each gets a smaller list, plus one
-- Tasha's style of its own: Blessed Warrior and Druidic Warrior.
-- RUN BEFORE 089 AND 090.
--
-- FOUR CHANGES:
--
--   1. A domain, public.fighting_style, holds the thirteen keys: 079's eleven
--      plus the two new ones. character_classes.fighting_style is retyped to
--      it and 079's column CHECK is dropped. Why a domain and not a second
--      CHECK on the new column: the database would then spell the list in two
--      places, and the client in a third. With the domain, the list lives once
--      here and once in FIGHTING_STYLES (src/data/rules.ts). THE DOMAIN AND
--      FIGHTING_STYLES ARE ONE LIST IN TWO PLACES, as with SKILLS.
--
--   2. class_features.fighting_style_options public.fighting_style[]: the
--      styles this row's picker offers. An array of a domain checks every
--      element, so an unknown key is refused (BLOCK 1).
--      * A column, not a `classes: [...]` field on FIGHTING_STYLES keyed by
--        class name: 079's reason for class_features being a table at all. A
--        homebrew class's Fighting Style row can carry its own list; a map
--        keyed on "Paladin" can't serve a class a DM invents.
--
--   3. The Fighter's row (080) is backfilled with its eleven. Owner UPDATE;
--      class_features has no pin trigger.
--
--   4. CHECK: a row carries a list if and only if it carries the picker.
--      * No "null means every style". That would be a second spelling of the
--        same thing (042's argument against a defaulted row), and the two would
--        disagree the day a style is added for one class only, which is today.
--      * `is not distinct from`, not `=`: with `choice` null, `choice = '...'`
--        is null, a CHECK passes on null, and a non-picker row could carry a
--        list. BLOCK 1 tries exactly that.
--      * cardinality > 0: an empty list would render a picker with nothing in
--        it.
--
-- Nothing in the database ties a character's stored pick to its feature's
-- list (079 already said the same of class). The client clears the pick on a
-- class change, and the sheet shows an out-of-list pick rather than hiding it.
--
-- THE SQL EDITOR MAY OFFER "Run and enable RLS": it misreads plpgsql's
-- `into strict` as a table being created (CLAUDE.md). This file creates no
-- table. Take the option that runs WITHOUT enabling.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

create domain public.fighting_style as text check (value in (
  -- PHB
  'archery', 'defense', 'dueling', 'great_weapon', 'protection', 'two_weapon',
  -- Tasha's
  'blind_fighting', 'interception', 'superior_technique', 'thrown_weapon',
  'unarmed', 'blessed_warrior', 'druidic_warrior'
));

-- 079's CHECK was inline on `add column`, so Postgres named it
-- <table>_<column>_check. Dropping a name that isn't there raises, which rolls
-- the whole file back: wanted, since it would mean 079 isn't what we think.
alter table public.character_classes
  drop constraint character_classes_fighting_style_check;

alter table public.character_classes
  alter column fighting_style type public.fighting_style;

alter table public.class_features
  add column fighting_style_options public.fighting_style[];

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class   constant text := 'Fighter';
  c_feature constant text := 'Fighting Style';
  -- 079's eleven: every style except the Paladin's and Ranger's own.
  c_options constant public.fighting_style[] := array[
    'archery', 'defense', 'dueling', 'great_weapon', 'protection', 'two_weapon',
    'blind_fighting', 'interception', 'superior_technique', 'thrown_weapon',
    'unarmed'
  ]::public.fighting_style[];

  v_class   uuid;
  v_options public.fighting_style[];
begin
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  update public.class_features
     set fighting_style_options = c_options
   where class_id = v_class and subclass_id is null
     and name = c_feature and campaign_id is null;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select fighting_style_options into strict v_options
  from public.class_features
  where class_id = v_class and subclass_id is null
    and name = c_feature and campaign_id is null;

  if v_options is distinct from c_options then
    raise exception
      '% % has options % (expected %). Rolled back.',
      c_class, c_feature, coalesce(v_options::text, 'null'), c_options;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % class, or no % row on it. 055 and 080 seed them.',
      c_class, c_feature;
  when too_many_rows then
    raise exception
      'More than one shared % class or % row. Resolve the duplicate first.',
      c_class, c_feature;
end
$$;

-- After the backfill: added first, the Fighter's row would fail it.
alter table public.class_features
  add constraint class_features_fighting_style_options_check check (
    (choice is not distinct from 'fighting_style')
      = (fighting_style_options is not null)
    and (fighting_style_options is null or cardinality(fighting_style_options) > 0)
  );

insert into public.schema_migrations (version) values ('083');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist and the Fighter row has its list
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 1 from pg_type
    where typname = 'fighting_style' and typtype = 'd'
      and typnamespace = 'public'::regnamespace)                         as domain_exists,
  (select count(*) = 0 from pg_constraint
    where conname = 'character_classes_fighting_style_check')            as old_check_gone,
  (select domain_name = 'fighting_style' from information_schema.columns
    where table_schema = 'public' and table_name = 'character_classes'
      and column_name = 'fighting_style')                                as column_retyped,
  (select count(*) = 1 from pg_constraint
    where conname = 'class_features_fighting_style_options_check')       as new_check,
  (select cardinality(f.fighting_style_options) = 11
      and not ('blessed_warrior' = any(f.fighting_style_options))
     from public.class_features f
     join public.classes c on c.id = f.class_id
    where c.name = 'Fighter' and c.campaign_id is null
      and f.name = 'Fighting Style' and f.campaign_id is null)           as fighter_11,
  (select count(*) = 0 from public.class_features
    where choice is null and fighting_style_options is not null)         as no_stray_lists,
  (select count(*) = 1 from public.schema_migrations
    where version = '083')                                               as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: what the domain and the new CHECK refuse
-- ---------------------------------------------------------------------------
--
-- Probe rows on the Fighter, as the table owner: this is about constraints,
-- not RLS. Each outcome is caught and reported (039's shape). Rolled back.
--
-- CORRECT OUTPUT: six rows:
--   picker_with_list   = 'ok'
--   unknown_key        = 'refused (23514)'
--   picker_no_list     = 'refused (23514)'
--   plain_with_list    = 'refused (23514)'   <- the null-comparison trap
--   empty_list         = 'refused (23514)'
--   pick_new_style     = 'ok'                (or 'skipped' with no characters)

begin;

do $$
declare
  v_fighter uuid;
  v_entry   uuid;
begin
  select id into strict v_fighter from public.classes
   where name = 'Fighter' and campaign_id is null;

  begin
    insert into public.class_features (class_id, level, name, description, choice, fighting_style_options)
    values (v_fighter, 1, 'Probe: picker with list', 'probe', 'fighting_style', array['defense']::public.fighting_style[]);
    perform set_config('verification.picker_with_list', 'ok', true);
  exception when check_violation then
    perform set_config('verification.picker_with_list', 'REFUSED -- should have passed', true);
  end;

  begin
    insert into public.class_features (class_id, level, name, description, choice, fighting_style_options)
    values (v_fighter, 1, 'Probe: unknown key', 'probe', 'fighting_style', array['kung_fu']::public.fighting_style[]);
    perform set_config('verification.unknown_key', 'ACCEPTED -- DOMAIN NOT CHECKED', true);
  exception when check_violation then
    perform set_config('verification.unknown_key', 'refused (23514)', true);
  end;

  begin
    insert into public.class_features (class_id, level, name, description, choice)
    values (v_fighter, 1, 'Probe: picker no list', 'probe', 'fighting_style');
    perform set_config('verification.picker_no_list', 'ACCEPTED -- CHECK MISSING', true);
  exception when check_violation then
    perform set_config('verification.picker_no_list', 'refused (23514)', true);
  end;

  begin
    insert into public.class_features (class_id, level, name, description, fighting_style_options)
    values (v_fighter, 1, 'Probe: plain with list', 'probe', array['defense']::public.fighting_style[]);
    perform set_config('verification.plain_with_list', 'ACCEPTED -- NULL COMPARISON TRAP', true);
  exception when check_violation then
    perform set_config('verification.plain_with_list', 'refused (23514)', true);
  end;

  begin
    insert into public.class_features (class_id, level, name, description, choice, fighting_style_options)
    values (v_fighter, 1, 'Probe: empty list', 'probe', 'fighting_style', array[]::public.fighting_style[]);
    perform set_config('verification.empty_list', 'ACCEPTED -- EMPTY LIST ALLOWED', true);
  exception when check_violation then
    perform set_config('verification.empty_list', 'refused (23514)', true);
  end;

  select id into v_entry from public.character_classes limit 1;
  if v_entry is null then
    perform set_config('verification.pick_new_style', 'skipped: no character_classes row', true);
  else
    begin
      update public.character_classes set fighting_style = 'blessed_warrior' where id = v_entry;
      perform set_config('verification.pick_new_style', 'ok', true);
    exception when check_violation then
      perform set_config('verification.pick_new_style', 'REFUSED -- domain missing the new key', true);
    end;
  end if;
end
$$;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'picker_with_list', current_setting('verification.picker_with_list'),
         'unknown_key',      current_setting('verification.unknown_key'),
         'picker_no_list',   current_setting('verification.picker_no_list'),
         'plain_with_list',  current_setting('verification.plain_with_list'),
         'empty_list',       current_setting('verification.empty_list'),
         'pick_new_style',   current_setting('verification.pick_new_style')
       ));

rollback;

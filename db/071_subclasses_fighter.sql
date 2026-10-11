-- db/071_subclasses_fighter.sql
--
-- Fighter subclasses (Martial Archetype): 8 rows, 3 PHB, 3 XGtE, 2 TCoE.
-- One of twelve per-class files, 067-078. RUN 066 FIRST: it adds
-- subclass_title and source, which this file writes.
--
-- Eldritch Knight carries spell_ability = 'int': the Fighter row has none, and
-- the sheet falls back to the subclass's for spell DC and attack.
--
-- BLOCK 1 below is the one place 056's composite FK is proven against real
-- rows, using Path of the Berserker from 067 as the wrong-class subclass.
--
-- ---------------------------------------------------------------------------
-- REWRITTEN AFTER GENERATION, BEFORE THIS FILE WAS RUN (2026-10-11).
-- ---------------------------------------------------------------------------
-- As first generated, the DO block was tagged `do $seed$ ... $seed$` with the
-- descriptions $$-quoted inside it. It was rewritten to 059's shape (a plain
-- `do $$` block, single-quoted strings) on a WRONG GUESS about an editor
-- error that 067 and 068 hit. Either shape is correct SQL.
--
-- THE ACTUAL CAUSE, found afterwards: before running, the Supabase SQL editor
-- scans for new tables so it can offer "Run and enable RLS". It reads plpgsql's
-- `select id into strict v_class` as a plain-SQL SELECT INTO creating a table
-- named "strict", and "Run and enable" appends
-- `alter table strict enable row level security` after this file. The
-- migration commits first; the appended statement then fails with
-- `relation "strict" does not exist`. CHOOSE THE OPTION THAT RUNS WITHOUT
-- ENABLING RLS: this file creates no table. The original text is kept,
-- commented out, at the foot of the file. 067 and 068 are left as they ran.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class    constant text := 'Fighter';
  c_title    constant text := 'Martial Archetype';
  c_expected constant int  := 8;

  v_class uuid;
  v_count int;
  v_title text;
begin
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  update public.classes set subclass_title = c_title where id = v_class;

  insert into public.subclasses (class_id, name, source, spell_ability, description)
  select v_class, v.name, v.source, v.spell_ability, v.description
  from (values
      ('Champion', 'phb', null,
       'Raw physical excellence; critical hits land more often.'),
      ('Battle Master', 'phb', null,
       'Tacticians who spend superiority dice on combat manoeuvres.'),
      ('Eldritch Knight', 'phb', 'int',
       'Fighters who blend swordplay with abjuration and evocation magic.'),
      ('Arcane Archer', 'xgte', null,
       'Archers of an elven tradition who weave magic into their arrows.'),
      ('Cavalier', 'xgte', null,
       'Mounted warriors and bodyguards who hold the line and mark their foes.'),
      ('Samurai', 'xgte', null,
       'Warriors whose fighting spirit drives relentless, precise attacks.'),
      ('Psi Warrior', 'tcoe', null,
       'Fighters who channel psionic power to shield, shove and strike.'),
      ('Rune Knight', 'tcoe', null,
       'Warriors who carve the runes of giants and grow to giant size.')
  ) as v(name, source, spell_ability, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.subclasses
  where class_id = v_class and campaign_id is null;

  select subclass_title into v_title from public.classes where id = v_class;

  if v_count <> c_expected or v_title is distinct from c_title then
    raise exception
      '% has % shared subclasses (expected %) and subclass_title %. Rolled back.',
      c_class, v_count, c_expected, coalesce(v_title, 'null');
  end if;
exception
  when no_data_found then
    raise exception
      'No shared class is named "%". 055 seeds it; check: select name from classes where campaign_id is null;',
      c_class;
  when too_many_rows then
    raise exception
      'More than one shared class is named "%". Resolve the duplicate before seeding its subclasses.',
      c_class;
end
$$;

insert into public.schema_migrations (version) values ('071');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the rows, the title and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 8 from public.subclasses s
     join public.classes c on c.id = s.class_id
    where c.name = 'Fighter' and c.campaign_id is null
      and s.campaign_id is null)                                     as count_8,
  (select subclass_title = 'Martial Archetype' from public.classes
    where name = 'Fighter' and campaign_id is null)                 as title_set,
  (select count(*) = 1 from public.subclasses s
     join public.classes c on c.id = s.class_id
    where c.name = 'Fighter' and c.campaign_id is null
      and s.name = 'Rune Knight' and s.source = 'tcoe')       as spot_check,
  (select count(*) = 1 from public.schema_migrations
    where version = '071')                                         as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: 056's composite FK refuses a subclass of the wrong class
-- ---------------------------------------------------------------------------
--
-- Borrows the first character_classes row, makes it a Champion Fighter (which
-- must succeed), then tries Path of the Berserker on it (which must be refused:
-- (subclass_id, class_id) has no match in subclasses). Runs as the table owner:
-- this is about the FK, not RLS. Each outcome is caught and reported as a row
-- (039's shape). Needs 067 run, for the Berserker row.
--
-- CORRECT OUTPUT: two rows: right_class = 'ok',
--                           wrong_class = 'refused (23503)'.
-- With no characters yet, both read 'skipped'.

begin;

do $$
declare
  v_entry     uuid;
  v_fighter   uuid;
  v_champion  uuid;
  v_berserker uuid;
begin
  select id into v_entry from public.character_classes limit 1;
  if v_entry is null then
    perform set_config('verification.right_class', 'skipped: no character_classes row', true);
    perform set_config('verification.wrong_class', 'skipped: no character_classes row', true);
    return;
  end if;

  select id into strict v_fighter from public.classes
   where name = 'Fighter' and campaign_id is null;
  select id into strict v_champion from public.subclasses
   where class_id = v_fighter and name = 'Champion' and campaign_id is null;
  select s.id into strict v_berserker from public.subclasses s
    join public.classes c on c.id = s.class_id
   where c.name = 'Barbarian' and c.campaign_id is null
     and s.name = 'Path of the Berserker' and s.campaign_id is null;

  begin
    update public.character_classes
       set class_id = v_fighter, subclass_id = v_champion
     where id = v_entry;
    perform set_config('verification.right_class', 'ok', true);
  exception when foreign_key_violation then
    perform set_config('verification.right_class', 'REFUSED -- should have passed', true);
  end;

  begin
    update public.character_classes
       set subclass_id = v_berserker
     where id = v_entry;
    perform set_config('verification.wrong_class', 'ACCEPTED -- FK MISSING', true);
  exception when foreign_key_violation then
    perform set_config('verification.wrong_class', 'refused (23503)', true);
  end;
end
$$;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'right_class', current_setting('verification.right_class'),
         'wrong_class', current_setting('verification.wrong_class')
       ));

rollback;


-- ===========================================================================
-- ORIGINAL VERSION -- superseded before it ran; kept for the record.
-- Do not uncomment. See the note at the top of this file.
-- ===========================================================================
--
-- -- db/071_subclasses_fighter.sql
-- --
-- -- Fighter subclasses (Martial Archetype): 8 rows, 3 PHB, 3 XGtE, 2 TCoE.
-- -- One of twelve per-class files, 067-078. RUN 066 FIRST: it adds
-- -- subclass_title and source, which this file writes.
-- --
-- -- Eldritch Knight carries spell_ability = 'int': the Fighter row has none, and
-- -- the sheet falls back to the subclass's for spell DC and attack.
-- --
-- -- BLOCK 1 below is the one place 056's composite FK is proven against real
-- -- rows, using Path of the Berserker from 067 as the wrong-class subclass.
--
--
-- -- ===========================================================================
-- -- MIGRATION
-- -- ===========================================================================
-- --
-- -- CORRECT OUTPUT: "Success. No rows returned."
--
-- begin;
--
-- -- Tagged $seed$, not $$: the descriptions inside are $$-quoted (055's style),
-- -- and a bare $$ there would end this block's body early.
-- do $seed$
-- declare
--   -- The one place each literal is named. Nothing below repeats them.
--   c_class    constant text := 'Fighter';
--   c_title    constant text := 'Martial Archetype';
--   c_expected constant int  := 8;
--
--   v_class uuid;
--   v_count int;
--   v_title text;
-- begin
--   select id into strict v_class
--   from public.classes
--   where name = c_class and campaign_id is null;
--
--   update public.classes set subclass_title = c_title where id = v_class;
--
--   insert into public.subclasses (class_id, name, source, spell_ability, description)
--   select v_class, v.name, v.source, v.spell_ability, v.description
--   from (values
--       ($$Champion$$, 'phb', null,
--        $$Raw physical excellence; critical hits land more often.$$),
--       ($$Battle Master$$, 'phb', null,
--        $$Tacticians who spend superiority dice on combat manoeuvres.$$),
--       ($$Eldritch Knight$$, 'phb', 'int',
--        $$Fighters who blend swordplay with abjuration and evocation magic.$$),
--       ($$Arcane Archer$$, 'xgte', null,
--        $$Archers of an elven tradition who weave magic into their arrows.$$),
--       ($$Cavalier$$, 'xgte', null,
--        $$Mounted warriors and bodyguards who hold the line and mark their foes.$$),
--       ($$Samurai$$, 'xgte', null,
--        $$Warriors whose fighting spirit drives relentless, precise attacks.$$),
--       ($$Psi Warrior$$, 'tcoe', null,
--        $$Fighters who channel psionic power to shield, shove and strike.$$),
--       ($$Rune Knight$$, 'tcoe', null,
--        $$Warriors who carve the runes of giants and grow to giant size.$$)
--   ) as v(name, source, spell_ability, description);
--
--   -- ---- Assert the end state, not the work. Do not demote to a notice. -----
--   select count(*) into v_count
--   from public.subclasses
--   where class_id = v_class and campaign_id is null;
--
--   select subclass_title into v_title from public.classes where id = v_class;
--
--   if v_count <> c_expected or v_title is distinct from c_title then
--     raise exception
--       '% has % shared subclasses (expected %) and subclass_title %. Rolled back.',
--       c_class, v_count, c_expected, coalesce(v_title, 'null');
--   end if;
-- exception
--   when no_data_found then
--     raise exception
--       'No shared class is named "%". 055 seeds it; check: select name from classes where campaign_id is null;',
--       c_class;
--   when too_many_rows then
--     raise exception
--       'More than one shared class is named "%". Resolve the duplicate before seeding its subclasses.',
--       c_class;
-- end
-- $seed$;
--
-- insert into public.schema_migrations (version) values ('071');
--
-- commit;
--
--
-- -- ===========================================================================
-- -- VERIFICATION
-- -- ===========================================================================
--
--
-- -- ---------------------------------------------------------------------------
-- -- BLOCK 0: the rows, the title and the ledger
-- -- ---------------------------------------------------------------------------
-- --
-- -- CORRECT OUTPUT: one row, every column `t`.
--
-- begin;
--
-- select
--   (select count(*) = 8 from public.subclasses s
--      join public.classes c on c.id = s.class_id
--     where c.name = 'Fighter' and c.campaign_id is null
--       and s.campaign_id is null)                                     as count_8,
--   (select subclass_title = 'Martial Archetype' from public.classes
--     where name = 'Fighter' and campaign_id is null)                 as title_set,
--   (select count(*) = 1 from public.subclasses s
--      join public.classes c on c.id = s.class_id
--     where c.name = 'Fighter' and c.campaign_id is null
--       and s.name = $$Rune Knight$$ and s.source = 'tcoe')       as spot_check,
--   (select count(*) = 1 from public.schema_migrations
--     where version = '071')                                         as ledger_row;
--
-- rollback;
--
--
-- -- ---------------------------------------------------------------------------
-- -- BLOCK 1: 056's composite FK refuses a subclass of the wrong class
-- -- ---------------------------------------------------------------------------
-- --
-- -- Borrows the first character_classes row, makes it a Champion Fighter (which
-- -- must succeed), then tries Path of the Berserker on it (which must be refused:
-- -- (subclass_id, class_id) has no match in subclasses). Runs as the table owner:
-- -- this is about the FK, not RLS. Each outcome is caught and reported as a row
-- -- (039's shape). Needs 067 run, for the Berserker row.
-- --
-- -- CORRECT OUTPUT: two rows: right_class = 'ok',
-- --                           wrong_class = 'refused (23503)'.
-- -- With no characters yet, both read 'skipped'.
--
-- begin;
--
-- do $$
-- declare
--   v_entry     uuid;
--   v_fighter   uuid;
--   v_champion  uuid;
--   v_berserker uuid;
-- begin
--   select id into v_entry from public.character_classes limit 1;
--   if v_entry is null then
--     perform set_config('verification.right_class', 'skipped: no character_classes row', true);
--     perform set_config('verification.wrong_class', 'skipped: no character_classes row', true);
--     return;
--   end if;
--
--   select id into strict v_fighter from public.classes
--    where name = 'Fighter' and campaign_id is null;
--   select id into strict v_champion from public.subclasses
--    where class_id = v_fighter and name = 'Champion' and campaign_id is null;
--   select s.id into strict v_berserker from public.subclasses s
--     join public.classes c on c.id = s.class_id
--    where c.name = 'Barbarian' and c.campaign_id is null
--      and s.name = 'Path of the Berserker' and s.campaign_id is null;
--
--   begin
--     update public.character_classes
--        set class_id = v_fighter, subclass_id = v_champion
--      where id = v_entry;
--     perform set_config('verification.right_class', 'ok', true);
--   exception when foreign_key_violation then
--     perform set_config('verification.right_class', 'REFUSED -- should have passed', true);
--   end;
--
--   begin
--     update public.character_classes
--        set subclass_id = v_berserker
--      where id = v_entry;
--     perform set_config('verification.wrong_class', 'ACCEPTED -- FK MISSING', true);
--   exception when foreign_key_violation then
--     perform set_config('verification.wrong_class', 'refused (23503)', true);
--   end;
-- end
-- $$;
--
-- select key as check, value as result
--   from jsonb_each_text(jsonb_build_object(
--          'right_class', current_setting('verification.right_class'),
--          'wrong_class', current_setting('verification.wrong_class')
--        ));
--
-- rollback;

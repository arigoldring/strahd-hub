-- db/075_subclasses_rogue.sql
--
-- Rogue subclasses (Roguish Archetype): 9 rows, 3 PHB, 4 XGtE, 2 TCoE.
-- One of twelve per-class files, 067-078. RUN 066 FIRST: it adds
-- subclass_title and source, which this file writes.
--
-- Arcane Trickster carries spell_ability = 'int': the Rogue row has none, and
-- the sheet falls back to the subclass's for spell DC and attack.
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
  c_class    constant text := 'Rogue';
  c_title    constant text := 'Roguish Archetype';
  c_expected constant int  := 9;

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
      ('Thief', 'phb', null,
       'Burglars and climbers with uncannily fast hands.'),
      ('Assassin', 'phb', null,
       'Killers who strike before the target knows a fight has begun, and masters of disguise.'),
      ('Arcane Trickster', 'phb', 'int',
       'Rogues who sharpen stealth and larceny with enchantment and illusion magic.'),
      ('Inquisitive', 'xgte', null,
       'Investigators who read lies and find an opponent''s weakness.'),
      ('Mastermind', 'xgte', null,
       'Schemers and spies who direct others from the sidelines.'),
      ('Scout', 'xgte', null,
       'Skirmishers and wilderness experts who strike and slip away.'),
      ('Swashbuckler', 'xgte', null,
       'Duellists with flair, at their best one on one.'),
      ('Phantom', 'tcoe', null,
       'Rogues touched by death who draw on the knowledge of departed souls.'),
      ('Soulknife', 'tcoe', null,
       'Rogues who manifest blades of psionic energy.')
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

insert into public.schema_migrations (version) values ('075');

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
  (select count(*) = 9 from public.subclasses s
     join public.classes c on c.id = s.class_id
    where c.name = 'Rogue' and c.campaign_id is null
      and s.campaign_id is null)                                     as count_9,
  (select subclass_title = 'Roguish Archetype' from public.classes
    where name = 'Rogue' and campaign_id is null)                 as title_set,
  (select count(*) = 1 from public.subclasses s
     join public.classes c on c.id = s.class_id
    where c.name = 'Rogue' and c.campaign_id is null
      and s.name = 'Soulknife' and s.source = 'tcoe')       as spot_check,
  (select count(*) = 1 from public.schema_migrations
    where version = '075')                                         as ledger_row;

rollback;


-- ===========================================================================
-- ORIGINAL VERSION -- superseded before it ran; kept for the record.
-- Do not uncomment. See the note at the top of this file.
-- ===========================================================================
--
-- -- db/075_subclasses_rogue.sql
-- --
-- -- Rogue subclasses (Roguish Archetype): 9 rows, 3 PHB, 4 XGtE, 2 TCoE.
-- -- One of twelve per-class files, 067-078. RUN 066 FIRST: it adds
-- -- subclass_title and source, which this file writes.
-- --
-- -- Arcane Trickster carries spell_ability = 'int': the Rogue row has none, and
-- -- the sheet falls back to the subclass's for spell DC and attack.
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
--   c_class    constant text := 'Rogue';
--   c_title    constant text := 'Roguish Archetype';
--   c_expected constant int  := 9;
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
--       ($$Thief$$, 'phb', null,
--        $$Burglars and climbers with uncannily fast hands.$$),
--       ($$Assassin$$, 'phb', null,
--        $$Killers who strike before the target knows a fight has begun, and masters of disguise.$$),
--       ($$Arcane Trickster$$, 'phb', 'int',
--        $$Rogues who sharpen stealth and larceny with enchantment and illusion magic.$$),
--       ($$Inquisitive$$, 'xgte', null,
--        $$Investigators who read lies and find an opponent's weakness.$$),
--       ($$Mastermind$$, 'xgte', null,
--        $$Schemers and spies who direct others from the sidelines.$$),
--       ($$Scout$$, 'xgte', null,
--        $$Skirmishers and wilderness experts who strike and slip away.$$),
--       ($$Swashbuckler$$, 'xgte', null,
--        $$Duellists with flair, at their best one on one.$$),
--       ($$Phantom$$, 'tcoe', null,
--        $$Rogues touched by death who draw on the knowledge of departed souls.$$),
--       ($$Soulknife$$, 'tcoe', null,
--        $$Rogues who manifest blades of psionic energy.$$)
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
-- insert into public.schema_migrations (version) values ('075');
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
--   (select count(*) = 9 from public.subclasses s
--      join public.classes c on c.id = s.class_id
--     where c.name = 'Rogue' and c.campaign_id is null
--       and s.campaign_id is null)                                     as count_9,
--   (select subclass_title = 'Roguish Archetype' from public.classes
--     where name = 'Rogue' and campaign_id is null)                 as title_set,
--   (select count(*) = 1 from public.subclasses s
--      join public.classes c on c.id = s.class_id
--     where c.name = 'Rogue' and c.campaign_id is null
--       and s.name = $$Soulknife$$ and s.source = 'tcoe')       as spot_check,
--   (select count(*) = 1 from public.schema_migrations
--     where version = '075')                                         as ledger_row;
--
-- rollback;

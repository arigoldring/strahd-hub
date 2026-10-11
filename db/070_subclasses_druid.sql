-- db/070_subclasses_druid.sql
--
-- Druid subclasses (Druid Circle): 7 rows, 2 PHB, 2 XGtE, 3 TCoE.
-- One of twelve per-class files, 067-078. RUN 066 FIRST: it adds
-- subclass_title and source, which this file writes.
--
-- Circle of Spores is counted under Tasha's, where it was reissued for general play.
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
  c_class    constant text := 'Druid';
  c_title    constant text := 'Druid Circle';
  c_expected constant int  := 7;

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
      ('Circle of the Land', 'phb', null,
       'Mystics tied to one kind of landscape, recovering spells and drawing on its magic.'),
      ('Circle of the Moon', 'phb', null,
       'Shapeshifters who take the forms of fiercer beasts, and sooner.'),
      ('Circle of Dreams', 'xgte', null,
       'Druids bound to the Feywild, healing allies and stepping between places.'),
      ('Circle of the Shepherd', 'xgte', null,
       'Protectors of beasts and fey who call on spirit totems and strengthen summoned creatures.'),
      ('Circle of Spores', 'tcoe', null,
       'Druids of decay and fungus who find life in rot and raise the dead to serve.'),
      ('Circle of Stars', 'tcoe', null,
       'Star-gazers who take a starry form drawn from the constellations.'),
      ('Circle of Wildfire', 'tcoe', null,
       'Druids of renewing flame, accompanied by a wildfire spirit.')
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

insert into public.schema_migrations (version) values ('070');

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
  (select count(*) = 7 from public.subclasses s
     join public.classes c on c.id = s.class_id
    where c.name = 'Druid' and c.campaign_id is null
      and s.campaign_id is null)                                     as count_7,
  (select subclass_title = 'Druid Circle' from public.classes
    where name = 'Druid' and campaign_id is null)                 as title_set,
  (select count(*) = 1 from public.subclasses s
     join public.classes c on c.id = s.class_id
    where c.name = 'Druid' and c.campaign_id is null
      and s.name = 'Circle of Wildfire' and s.source = 'tcoe')       as spot_check,
  (select count(*) = 1 from public.schema_migrations
    where version = '070')                                         as ledger_row;

rollback;


-- ===========================================================================
-- ORIGINAL VERSION -- superseded before it ran; kept for the record.
-- Do not uncomment. See the note at the top of this file.
-- ===========================================================================
--
-- -- db/070_subclasses_druid.sql
-- --
-- -- Druid subclasses (Druid Circle): 7 rows, 2 PHB, 2 XGtE, 3 TCoE.
-- -- One of twelve per-class files, 067-078. RUN 066 FIRST: it adds
-- -- subclass_title and source, which this file writes.
-- --
-- -- Circle of Spores is counted under Tasha's, where it was reissued for general play.
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
--   c_class    constant text := 'Druid';
--   c_title    constant text := 'Druid Circle';
--   c_expected constant int  := 7;
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
--       ($$Circle of the Land$$, 'phb', null,
--        $$Mystics tied to one kind of landscape, recovering spells and drawing on its magic.$$),
--       ($$Circle of the Moon$$, 'phb', null,
--        $$Shapeshifters who take the forms of fiercer beasts, and sooner.$$),
--       ($$Circle of Dreams$$, 'xgte', null,
--        $$Druids bound to the Feywild, healing allies and stepping between places.$$),
--       ($$Circle of the Shepherd$$, 'xgte', null,
--        $$Protectors of beasts and fey who call on spirit totems and strengthen summoned creatures.$$),
--       ($$Circle of Spores$$, 'tcoe', null,
--        $$Druids of decay and fungus who find life in rot and raise the dead to serve.$$),
--       ($$Circle of Stars$$, 'tcoe', null,
--        $$Star-gazers who take a starry form drawn from the constellations.$$),
--       ($$Circle of Wildfire$$, 'tcoe', null,
--        $$Druids of renewing flame, accompanied by a wildfire spirit.$$)
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
-- insert into public.schema_migrations (version) values ('070');
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
--   (select count(*) = 7 from public.subclasses s
--      join public.classes c on c.id = s.class_id
--     where c.name = 'Druid' and c.campaign_id is null
--       and s.campaign_id is null)                                     as count_7,
--   (select subclass_title = 'Druid Circle' from public.classes
--     where name = 'Druid' and campaign_id is null)                 as title_set,
--   (select count(*) = 1 from public.subclasses s
--      join public.classes c on c.id = s.class_id
--     where c.name = 'Druid' and c.campaign_id is null
--       and s.name = $$Circle of Wildfire$$ and s.source = 'tcoe')       as spot_check,
--   (select count(*) = 1 from public.schema_migrations
--     where version = '070')                                         as ledger_row;
--
-- rollback;

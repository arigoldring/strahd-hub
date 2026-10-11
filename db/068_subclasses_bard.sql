-- db/068_subclasses_bard.sql
--
-- Bard subclasses (Bard College): 7 rows, 2 PHB, 3 XGtE, 2 TCoE.
-- One of twelve per-class files, 067-078. RUN 066 FIRST: it adds
-- subclass_title and source, which this file writes.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- Tagged $seed$, not $$: the descriptions inside are $$-quoted (055's style),
-- and a bare $$ there would end this block's body early.
do $seed$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class    constant text := 'Bard';
  c_title    constant text := 'Bard College';
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
      ($$College of Lore$$, 'phb', null,
       $$Collectors of knowledge and secrets, with extra skills and spells borrowed from other traditions.$$),
      ($$College of Valor$$, 'phb', null,
       $$Skalds who sing of heroes and fight beside them in armour.$$),
      ($$College of Glamour$$, 'xgte', null,
       $$Bards touched by the Feywild, whose performances beguile and command.$$),
      ($$College of Swords$$, 'xgte', null,
       $$Blade-wielding entertainers who weave flourishes into every strike.$$),
      ($$College of Whispers$$, 'xgte', null,
       $$Spies and blackmailers who trade in fear and stolen secrets.$$),
      ($$College of Creation$$, 'tcoe', null,
       $$Bards who sing the notes of creation, animating objects and conjuring things from nothing.$$),
      ($$College of Eloquence$$, 'tcoe', null,
       $$Masters of oratory whose words always find their mark.$$)
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
$seed$;

insert into public.schema_migrations (version) values ('068');

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
    where c.name = 'Bard' and c.campaign_id is null
      and s.campaign_id is null)                                     as count_7,
  (select subclass_title = 'Bard College' from public.classes
    where name = 'Bard' and campaign_id is null)                 as title_set,
  (select count(*) = 1 from public.subclasses s
     join public.classes c on c.id = s.class_id
    where c.name = 'Bard' and c.campaign_id is null
      and s.name = $$College of Eloquence$$ and s.source = 'tcoe')       as spot_check,
  (select count(*) = 1 from public.schema_migrations
    where version = '068')                                         as ledger_row;

rollback;

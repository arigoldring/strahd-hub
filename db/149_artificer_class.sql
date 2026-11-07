-- db/149_artificer_class.sql
--
-- The Artificer joins the shared class catalogue, with one subclass: Battle
-- Smith. The first of four files (149-152) that add the class:
--
--   149  the class row, its subclass_title, Battle Smith       (this file)
--   150  base-class and Battle Smith features, + battle_ready effect key
--   151  Infusions as a picker (kind 'infusion')
--   152  the Artificer on TCoE's spell list
--
-- WHY NOW, AND WHY ITS OWN FILE. 055 seeded the PHB twelve, and 066 left the
-- Artificer out because "it has nothing for a subclass to belong to". It is
-- a Tasha's class, so it isn't a 055 amendment; it's 055's shape plus 067's
-- in one file, because a class whose subclass picker opens onto nothing is
-- a half-state nobody needs to see.
--
-- ONLY BATTLE SMITH. Alchemist, Armorer and Artillerist are deliberately not
-- seeded yet (KNOWN_ISSUES). Adding one later is an insert in this file's
-- shape plus a 150-shaped features file. The end-state check below counts
-- one subclass, so it describes today, not the class's final shape.
--
-- THE CLASS ROW (TCoE, 2014-era rules): d8, Constitution and Intelligence
-- saves, Intelligence casting, simple weapons, no Unarmored Defense, and the
-- specialist chosen at 3rd. Armour (light, medium, shields) and tools are
-- not columns, as with every class. Battle Smith's martial weapons come from
-- 150's battle_ready effect, not from weapon_training, because they are the
-- subclass's and not the class's.
--
-- Battle Smith's spell_ability is null: the class already casts with INT,
-- and the subclass column is only the fallback for Eldritch Knight-style
-- subclasses of non-casting classes (054).
--
-- STALE CHECKS ELSEWHERE, ON PURPOSE. 055's BLOCK 0 (`twelve_classes`,
-- `eight_casters`) and 066's "97 subclasses across the twelve" now read
-- false or out of date on a re-run. They describe the state those files
-- produced, not the catalogue's forever.
--
-- 148 is the Warforged race (on main). Numbering continues from it.
--
-- In the SQL editor, decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- Tagged $seed$, not $$: the descriptions inside are $$-quoted (055's style).
do $seed$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class    constant text := 'Artificer';
  c_title    constant text := 'Artificer Specialist';
  c_smith    constant text := 'Battle Smith';
  c_expected constant int  := 1;

  v_class uuid;
  v_count int;
  v_title text;
begin
  -- No `not exists` guard: the ledger stops a re-run, and a hand-made shared
  -- Artificer already in the table makes the `into strict` below fail with
  -- too_many_rows, so a twin can't land quietly.
  insert into public.classes
    (name, hit_die, save_proficiencies, spell_ability, weapon_training,
     unarmored_ability, subclass_level, subclass_title, description)
  values
    (c_class, 8, array['con', 'int'], 'int', 'simple', null, 3, c_title,
     $$An inventor who channels magic through tools, infusing ordinary objects with arcane power.$$);

  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  insert into public.subclasses (class_id, name, source, spell_ability, description)
  values
    (v_class, c_smith, 'tcoe', null,
     $$A soldier-engineer who fights beside a steel defender of their own making.$$);

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
    raise exception 'No shared class is named "%" after inserting it. Rolled back.', c_class;
  when too_many_rows then
    raise exception
      'More than one shared class is named "%". Resolve the duplicate first.', c_class;
end
$seed$;

insert into public.schema_migrations (version) values ('149');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the class, the subclass, the title and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 1 from public.classes
    where name = 'Artificer' and campaign_id is null)                 as one_class,
  (select hit_die = 8 and save_proficiencies = array['con', 'int']
          and spell_ability = 'int' and weapon_training = 'simple'
          and unarmored_ability is null and subclass_level = 3
          and subclass_title = 'Artificer Specialist'
     from public.classes
    where name = 'Artificer' and campaign_id is null)                 as class_ok,
  (select count(*) = 1 from public.subclasses s
     join public.classes c on c.id = s.class_id
    where c.name = 'Artificer' and c.campaign_id is null
      and s.campaign_id is null
      and s.name = 'Battle Smith' and s.source = 'tcoe')              as battle_smith,
  (select count(*) = 1 from public.schema_migrations
    where version = '149')                                            as ledger_row;

rollback;

-- db/119_class_features_xgte_wizard.sql
--
-- The Wizard's one Xanathar's tradition: War Magic. 5 rows, all subclass
-- features (the base class is 094's).
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 078.
--
-- TEXT: every row is a short summary in our own words, mechanics intact, not
-- the book's wording. Tables are referenced, not reproduced.
--
-- NO PICKERS: no row here is linked to a feature option (095). The end-state
-- check counts class_feature_options links on these subclasses' features and
-- requires zero. Display only, like every feature row (KNOWN_ISSUES).
--
-- Run by Claude via `npx supabase db query --linked`; in the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class constant text := 'Wizard';
  c_war_magic            constant text := 'War Magic';
  c_war_magic_n          constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_war_magic            uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_war_magic;
  select id into strict v_war_magic
  from public.subclasses
  where class_id = v_class and name = c_war_magic and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- War Magic ---------------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_war_magic::uuid, 2, 'Arcane Deflection',
       'Reaction: when an attack hits you or you fail a saving throw, gain '
       '+2 AC against that attack or +4 to that save. If you do, you can '
       'cast only cantrips until the end of your next turn.'),
      (v_war_magic, 2, 'Tactical Wit',
       'Add your Intelligence modifier to initiative.'),
      (v_war_magic, 6, 'Power Surge',
       'You hold power surges, up to your Intelligence modifier (minimum 1). '
       'A long rest resets them to one; a short rest that ends with none '
       'gives you one; ending a spell with dispel magic or counterspell '
       'gives you one. Once per turn, when a wizard spell damages a creature '
       'or object, spend a surge for extra force damage equal to half your '
       'wizard level.'),
      (v_war_magic, 10, 'Durable Magic',
       'While you concentrate on a spell, +2 to AC and to all saving throws.'),
      (v_war_magic, 14, 'Deflecting Shroud',
       'When you use Arcane Deflection, up to three creatures of your choice '
       'within 60 feet take force damage equal to half your wizard level.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_war_magic and campaign_id is null;
  if v_count <> c_war_magic_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_war_magic, v_count, c_war_magic_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_war_magic);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 078 the Wizard''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('119');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the rows and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

with f as (
  select s.name as subclass, f.*
    from public.class_features f
    join public.classes c on c.id = f.class_id
    join public.subclasses s on s.id = f.subclass_id
   where c.name = 'Wizard' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('War Magic')
)
select
  (select array_agg(level order by level, name)
          = array[2, 2, 6, 10, 14]::smallint[]
     from f where subclass = 'War Magic')                     as war_magic_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '119')                                            as ledger_row;

rollback;

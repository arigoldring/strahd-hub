-- db/066_subclass_catalogue.sql
--
-- The schema half of seeding subclasses. 055 left `subclasses` empty on
-- purpose ("content arrives with class features"); this is the step before
-- features: the sheet gets a subclass picker now, and the rows it picks from
-- become what class features hang on next. No rows here. 067-078 seed one
-- class each, and every one of them depends on this file.
--
-- WHICH BOOKS. The 2014 Player's Handbook, Xanathar's Guide to Everything and
-- Tasha's Cauldron of Everything: 97 subclasses across the twelve classes 055
-- seeded. Two reprints are counted under Tasha's, where they were reissued for
-- general play: Circle of Spores and Bladesinging. The DMG's Death Domain and
-- Oathbreaker are left out (villain options, not player ones).
--
-- ARTIFICER IS NOT HERE. It is a Tasha's CLASS, and 055 has no row for it, so
-- it has nothing for a subclass to belong to. Adding it means a class row first
-- (hit die, saves, subclass_level), then its subclasses, in its own migration.
--
-- THREE CHANGES:
--
--   1. classes.subclass_title -- "Primal Path", "Divine Domain", "Arcane
--      Tradition". The picker's label and, later, the heading class features
--      sit under. A catalogue fact like hit_die, so a column rather than a map
--      in code: a homebrew class needs one too. NOT NULL with a 'Subclass'
--      default, so homebrew classes stay valid without one and a class whose
--      seed file hasn't run yet reads sensibly. Each class file sets its own.
--
--   2. subclasses.source -- 'phb', 'xgte' or 'tcoe', null for homebrew. Shown
--      in the picker so a DM can see at a glance which book an option comes
--      from. THE CHECK AND SUBCLASS_SOURCES IN src/services/classes.ts ARE ONE
--      LIST IN TWO PLACES; change them together, as with featCategories.
--
--   3. A partial unique index on (class_id, name) for shared rows. THIS IS FOR
--      THE FEATURES MIGRATION. It will resolve "(Fighter, Battle Master)" to a
--      subclass id by name, with `into strict`, the way 051 resolves a campaign.
--      Without this index a duplicated shared row turns that lookup into a
--      too_many_rows rollback at the worst possible time; with it, the duplicate
--      can't be written in the first place. Homebrew (campaign_id not null) is
--      left unconstrained, as npcs is: nothing is resolved by its name.
--
-- No policy changes. subclasses keeps 054's SELECT and INSERT, and nothing on
-- character_classes changes: 056's composite FK already refuses a subclass of
-- the wrong class, and pin_character_class_row leaves subclass_id writable.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.
-- 067-078 add rows only and don't change the types.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

alter table public.classes
  add column subclass_title text not null default 'Subclass'
    check (length(btrim(subclass_title)) between 1 and 40);

alter table public.subclasses
  add column source text check (source in ('phb', 'xgte', 'tcoe'));

create unique index subclasses_shared_class_name_key
  on public.subclasses (class_id, name)
  where campaign_id is null;

insert into public.schema_migrations (version) values ('066');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist, and nothing else moved
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'classes'
      and column_name = 'subclass_title' and is_nullable = 'NO')     as subclass_title_col,
  (select count(*) = 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'subclasses'
      and column_name = 'source')                                     as source_col,
  (select count(*) = 1 from pg_indexes
    where schemaname = 'public'
      and indexname = 'subclasses_shared_class_name_key')            as unique_index,
  (select count(*) = 2 from pg_policies
    where schemaname = 'public' and tablename = 'subclasses')        as still_2_policies,
  (select count(*) = 1 from public.schema_migrations
    where version = '066')                                            as ledger_row;

rollback;

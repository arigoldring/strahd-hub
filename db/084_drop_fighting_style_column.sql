-- db/084_drop_fighting_style_column.sql
--
-- The second half of 083: drops the columns 083 replaced. RUN 083 FIRST, AND
-- ONLY ONCE THE CLIENT THAT READS character_feature_choices IS LIVE. The
-- client deploys from main; until that merge the old client still writes
-- character_classes.fighting_style, and dropping it first breaks every sheet.
--
-- THREE DROPS:
--   * mirror_fighting_style (trigger and function). 083's bridge for the old
--     client's writes. The new client never writes the column, so the trigger
--     has had nothing to do since the merge.
--   * character_classes.fighting_style, and 079's CHECK with it. The picks are
--     the truth now. The column is NOT compared against them first: once the
--     new client is live a player can change or clear a pick without touching
--     the column, so a mismatch is expected, not an error.
--   * class_features.choice, and 079's CHECK with it. A feature carries a
--     picker when it has class_feature_options rows; FEATURE_CHOICES in
--     src/services/classes.ts goes with it.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

drop trigger mirror_fighting_style on public.character_classes;
drop function public.mirror_fighting_style();

alter table public.character_classes drop column fighting_style;
alter table public.class_features drop column choice;

insert into public.schema_migrations (version) values ('084');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the columns and the bridge are gone, the picks are not
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 0 from information_schema.columns
    where table_schema = 'public' and table_name = 'character_classes'
      and column_name = 'fighting_style')                                as style_col_gone,
  (select count(*) = 0 from information_schema.columns
    where table_schema = 'public' and table_name = 'class_features'
      and column_name = 'choice')                                        as choice_col_gone,
  (select count(*) = 0 from pg_proc
    where proname = 'mirror_fighting_style')                             as mirror_gone,
  (select count(*) = 1 from pg_trigger
    where tgname = 'clear_stale_feature_choices')                        as clear_trigger_kept,
  (select count(*) = 22 from public.class_feature_options)               as links_kept,
  (select count(*) = 1 from public.schema_migrations
    where version = '084')                                               as ledger_row;

rollback;

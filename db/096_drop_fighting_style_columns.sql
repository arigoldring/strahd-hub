-- db/096_drop_fighting_style_columns.sql
--
-- The contract half of 095. It drops what character_feature_choices replaced:
--
--   character_classes.fighting_style        079's one pick per class entry
--   class_features.fighting_style_options   083's per-row list, now links
--   class_features.choice                   079's picker flag. A feature has a
--                                           picker exactly when it has linked
--                                           options, so the flag became a
--                                           second spelling of that fact and
--                                           could only ever disagree with it.
--                                           Its CHECK and FEATURE_CHOICES in
--                                           services/classes.ts were one list
--                                           in two places; both are gone now.
--   public.fighting_style                   083's domain, which typed the two
--                                           columns above and nothing else.
--   mirror_fighting_style                   095's temporary trigger
--
-- RUN ONLY AFTER THE NEW CLIENT IS LIVE on dnd-cos.pages.dev. The old client
-- reads and writes these columns. Once they're gone, every sheet it renders
-- fails to load, and every fighting-style save it makes fails. The database
-- can't check which client is deployed, so this guard is a sentence, not SQL.
--
-- ONE CHECK BEFORE DROPPING: every non-null fighting_style must already have
-- its pick in character_feature_choices. 095's backfill and mirror trigger
-- should guarantee that, so a miss means an old-client write the mirror
-- couldn't place (a style outside its feature's list). Raise and roll back
-- rather than drop a pick nobody copied.
--
-- `drop domain` without CASCADE is the last statement before the ledger
-- insert, on purpose: if anything still uses the domain, it raises and the
-- whole file rolls back.
--
-- OLDER VERIFICATION BLOCKS STOP RUNNING. 079-095's blocks name `choice`,
-- `fighting_style` or `fighting_style_options` (079, 080, 082, 083, 084-094's
-- "no pickers" column, and 095's mirror test), and after this file they fail
-- with "column does not exist". That is expected: each one checked the
-- schema as it stood at its own migration. Don't re-add a column to make one
-- pass. 095's BLOCKS 2-4 still describe the live design, but they set
-- `fighting_style = null` in their setup. The 097+ seed files assert
-- "no pickers" by counting class_feature_options links instead.
--
-- THE SQL EDITOR MAY OFFER "Run and enable RLS". Decline it: this file creates
-- no table.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  v_unmapped int;
begin
  select count(*) into v_unmapped
    from public.character_classes cc
   where cc.fighting_style is not null
     and not exists (
       select 1 from public.character_feature_choices ch
         join public.class_features f on f.id = ch.feature_id
         join public.feature_options o on o.id = ch.option_id
        where ch.character_class_id = cc.id
          and f.choice = 'fighting_style'
          and o.key = cc.fighting_style::text
     );
  if v_unmapped <> 0 then
    raise exception
      '% class entries hold a fighting_style with no matching pick. Check: select id, class_id, fighting_style from character_classes where fighting_style is not null; Rolled back.',
      v_unmapped;
  end if;
end
$$;

drop trigger mirror_fighting_style on public.character_classes;
drop function public.mirror_fighting_style();

alter table public.character_classes drop column fighting_style;

-- 083's CHECK names both columns. Dropped by name first, so a renamed or
-- missing constraint raises here rather than vanishing as a side effect.
alter table public.class_features
  drop constraint class_features_fighting_style_options_check;
alter table public.class_features drop column fighting_style_options;
alter table public.class_features drop constraint class_features_choice_check;
alter table public.class_features drop column choice;

drop domain public.fighting_style;

insert into public.schema_migrations (version) values ('096');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the old objects are gone and the new ones are untouched
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 0 from information_schema.columns
    where table_schema = 'public'
      and ((table_name = 'character_classes' and column_name = 'fighting_style')
        or (table_name = 'class_features'
            and column_name in ('fighting_style_options', 'choice'))))     as columns_gone,
  (select count(*) = 0 from pg_type
    where typname = 'fighting_style'
      and typnamespace = 'public'::regnamespace)                           as domain_gone,
  (select count(*) = 0 from pg_proc
    where proname = 'mirror_fighting_style'
      and pronamespace = 'public'::regnamespace)                           as mirror_gone,
  (select count(*) = 1 from pg_trigger
    where tgrelid = 'public.character_classes'::regclass
      and tgname = 'clear_stale_feature_choices')                          as clear_trigger_kept,
  (select count(*) = 36 from public.class_feature_options)                 as links_kept,
  (select count(*) = 1 from public.schema_migrations
    where version = '096')                                                 as ledger_row;

rollback;

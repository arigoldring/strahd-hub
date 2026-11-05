-- db/103_class_features_xgte_druid.sql
--
-- The Druid's two Xanathar's circles: Dreams and the Shepherd. 9 rows, all
-- subclass features (the base class is 087's).
--
-- Spirit Totem's animal is chosen each time it's summoned, not stored.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 070.
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
  c_class constant text := 'Druid';
  c_dreams               constant text := 'Circle of Dreams';
  c_shepherd             constant text := 'Circle of the Shepherd';
  c_dreams_n             constant int  := 4;
  c_shepherd_n           constant int  := 5;

  v_seeking text;
  v_class   uuid;
  v_dreams               uuid;
  v_shepherd             uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_dreams;
  select id into strict v_dreams
  from public.subclasses
  where class_id = v_class and name = c_dreams and campaign_id is null;

  v_seeking := 'subclass ' || c_shepherd;
  select id into strict v_shepherd
  from public.subclasses
  where class_id = v_class and name = c_shepherd and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Circle of Dreams --------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_dreams::uuid, 2, 'Balm of the Summer Court',
       'You have a pool of d6s equal to your druid level, restored on a long '
       'rest. Bonus action: spend up to half your druid level in dice on one '
       'creature you can see within 120 feet. It regains hit points equal to '
       'the roll, plus 1 temporary hit point per die spent.'),
      (v_dreams, 6, 'Hearth of Moonlight and Shadow',
       'At the start of a short or long rest, ward a 30-foot sphere around '
       'you. During the rest, you and your allies in it have +5 to Dexterity '
       '(Stealth) and Wisdom (Perception) checks, and light from open flames '
       'in it can''t be seen from outside.'),
      (v_dreams, 10, 'Hidden Paths',
       'Bonus action: teleport up to 60 feet to a space you can see. Or, as '
       'an action, teleport one willing creature you touch up to 30 feet. '
       'Uses equal to your Wisdom modifier (minimum 1) per long rest.'),
      (v_dreams, 14, 'Walker in Dreams',
       'After a short rest, cast dream (you as the messenger), scrying or '
       'teleportation circle without a spell slot. The teleportation circle '
       'opens to where you last took a long rest on this plane. Once per '
       'long rest.'),
      -- ---- Circle of the Shepherd --------------------------------------------
      (v_shepherd, 2, 'Speech of the Woods',
       'You speak, read and write Sylvan. Beasts understand your speech, and '
       'you can make sense of their noises and movements.'),
      (v_shepherd, 2, 'Spirit Totem',
       concat_ws(E'\n',
       'Bonus action: summon a spirit at a point within 60 feet, with a '
       '30-foot aura, for 1 minute or until you are incapacitated. Move it '
       '60 feet as a bonus action. Once per short or long rest. Pick an '
       'animal each time:',
       '- Bear: creatures of your choice in the aura gain 5 + your druid '
       'level temporary hit points when it appears, and you and your allies '
       'in it have advantage on Strength checks and saves.',
       '- Hawk: you and your allies in it have advantage on Wisdom '
       '(Perception) checks, and you can use your reaction to give advantage '
       'to an attack against a creature in the aura.',
       '- Unicorn: you and your allies have advantage on checks to detect '
       'creatures in it, and when you heal anyone with a spell slot, '
       'creatures of your choice in the aura regain hit points equal to your '
       'druid level.')),
      (v_shepherd, 6, 'Mighty Summoner',
       'Beasts and fey you conjure with a spell gain 2 extra hit points per '
       'Hit Die, and their natural weapons count as magical.'),
      (v_shepherd, 10, 'Guardian Spirit',
       'A beast or fey you summoned or created with a spell regains hit '
       'points equal to half your druid level when it ends its turn in your '
       'Spirit Totem''s aura.'),
      (v_shepherd, 14, 'Faithful Summons',
       'When you drop to 0 hit points or are incapacitated against your '
       'will, you can gain the effect of conjure animals at 9th level: four '
       'beasts of your choice, challenge 2 or lower, appear within 20 feet '
       'and protect you for 1 hour, without concentration. Once per long '
       'rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_dreams and campaign_id is null;
  if v_count <> c_dreams_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_dreams, v_count, c_dreams_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_shepherd and campaign_id is null;
  if v_count <> c_shepherd_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_shepherd, v_count, c_shepherd_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_dreams, v_shepherd);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 070 the Druid''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('103');

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
   where c.name = 'Druid' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Circle of Dreams', 'Circle of the Shepherd')
)
select
  (select array_agg(level order by level, name)
          = array[2, 6, 10, 14]::smallint[]
     from f where subclass = 'Circle of Dreams')              as dreams_levels,
  (select array_agg(level order by level, name)
          = array[2, 2, 6, 10, 14]::smallint[]
     from f where subclass = 'Circle of the Shepherd')        as shepherd_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '103')                                            as ledger_row;

rollback;

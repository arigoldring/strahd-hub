-- db/162_class_weapon_lists.sql
--
-- 161's data half: the 2014 PHB weapon proficiencies for the thirteen shared
-- classes, the multiclass flag, and the re-key of 'weapon' proficiency rows
-- from item id to weapon name.
--
-- ⚠ RUN ONLY AFTER THE CLIENT THAT KNOWS 'none' IS DEPLOYED. The Wizard,
-- Sorcerer and Druid become weapon_training = 'none', and a client from before
-- 161 parses that column strictly (toCharacterClass throws), which would fail
-- every sheet's class load. 159/160's ordering, for the same reason.
--
-- THE LISTS (PHB 2014, class tables; Artificer from TCoE):
--   Barbarian, Fighter, Paladin, Ranger   simple + martial
--   Cleric, Warlock, Artificer            simple
--   Bard, Rogue                           simple + hand crossbow, longsword,
--                                         rapier, shortsword
--   Monk                                  simple + shortsword
--   Druid                                 club, dagger, dart, javelin, mace,
--                                         quarterstaff, scimitar, sickle,
--                                         sling, spear
--   Sorcerer, Wizard                      dagger, dart, sling, quarterstaff,
--                                         light crossbow
-- The Artificer's firearms aren't in the catalogue, so they aren't listed.
--
-- MULTICLASS (PHB p.164, TCoE for the Artificer): a second class grants
-- weapons for Barbarian, Fighter, Paladin, Ranger (simple and martial), Monk
-- (simple and shortswords) and Warlock (simple). Bard, Cleric, Druid, Rogue,
-- Sorcerer, Wizard and Artificer grant none. Each class that grants weapons
-- grants exactly its own list, so a boolean is enough.
--
-- NAMES are the shared weapon rows' names exactly ("Crossbow, Hand"), because
-- that is what the client compares (proficiencyName in services/items.ts).
-- The assertion checks every listed name against a shared, mundane weapon:
-- a misspelt name in a text[] matches nothing and fails silently.
--
-- RE-KEY: 056 keyed a 'weapon' proficiency row by items.id; 161 keys it by
-- the weapon's name (a magic weapon's base). Done as insert-then-delete, not
-- an UPDATE, because two item rows can resolve to one name (a stack of each),
-- and an UPDATE would collide on the (character_id, kind, key) unique. Zero
-- such rows existed when this was written (checked live 2026-11-07); the
-- statement is here so the file is right whatever the count is when it runs.
--
-- Homebrew classes are left alone: their weapon_training is still valid,
-- their list is empty, and their multiclass flag is false. A DM who wants
-- more has no form for it (KNOWN_ISSUES, "Classes ... can't be created or
-- edited from the app").
--
-- Run by Claude via `npx supabase db query --linked`. In the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): the temp table is dropped on
-- commit.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

create temp table class_weapons (
  name text primary key,
  training text not null,
  weapons text[] not null,
  multiclass boolean not null
) on commit drop;

insert into class_weapons values
  ('Artificer', 'simple',  '{}', false),
  ('Barbarian', 'martial', '{}', true),
  ('Bard',      'simple',  array['Crossbow, Hand', 'Longsword', 'Rapier', 'Shortsword'], false),
  ('Cleric',    'simple',  '{}', false),
  ('Druid',     'none',    array['Club', 'Dagger', 'Dart', 'Javelin', 'Mace',
                               'Quarterstaff', 'Scimitar', 'Sickle', 'Sling', 'Spear'], false),
  ('Fighter',   'martial', '{}', true),
  ('Monk',      'simple',  array['Shortsword'], true),
  ('Paladin',   'martial', '{}', true),
  ('Ranger',    'martial', '{}', true),
  ('Rogue',     'simple',  array['Crossbow, Hand', 'Longsword', 'Rapier', 'Shortsword'], false),
  ('Sorcerer',  'none',    array['Dagger', 'Dart', 'Sling', 'Quarterstaff', 'Crossbow, Light'], false),
  ('Warlock',   'simple',  '{}', true),
  ('Wizard',    'none',    array['Dagger', 'Dart', 'Sling', 'Quarterstaff', 'Crossbow, Light'], false);

update public.classes c
   set weapon_training = w.training,
       weapon_proficiencies = w.weapons,
       multiclass_grants_weapons = w.multiclass
  from class_weapons w
 where c.campaign_id is null
   and c.name = w.name;

-- ---- re-key 'weapon' rows from item id to weapon name ----------------------

insert into public.character_proficiencies (character_id, kind, key, level)
select distinct p.character_id, 'weapon', coalesce(b.name, i.name), 1
  from public.character_proficiencies p
  join public.items i on i.id::text = p.key
  left join public.items b on b.id = i.base_weapon_id
 where p.kind = 'weapon'
on conflict (character_id, kind, key) do nothing;

delete from public.character_proficiencies p
 using public.items i
 where p.kind = 'weapon'
   and i.id::text = p.key;

-- ---- Assert the end state. -------------------------------------------------
do $$
declare
  v_count int;
  v_bad text;
begin
  -- Every shared class is in the list above and holds exactly its row.
  select count(*) into v_count
    from public.classes c
    join class_weapons w on w.name = c.name
   where c.campaign_id is null
     and c.weapon_training = w.training
     and c.weapon_proficiencies = w.weapons
     and c.multiclass_grants_weapons = w.multiclass;
  if v_count <> 13 then
    raise exception '% of 13 shared classes hold their weapon list. Rolled back.', v_count;
  end if;
  if (select count(*) from public.classes where campaign_id is null) <> 13 then
    raise exception 'a shared class is missing from this file''s list. Rolled back.';
  end if;

  -- Every listed name is a shared, mundane weapon.
  select string_agg(distinct n, ', ') into v_bad
    from class_weapons, unnest(weapons) as n
   where not exists (
     select 1 from public.items i
      where i.campaign_id is null and i.kind = 'weapon'
        and i.rarity is null and i.name = n);
  if v_bad is not null then
    raise exception 'not a shared weapon: %. Rolled back.', v_bad;
  end if;

  -- No 'weapon' row is still keyed by an item id.
  if exists (select 1 from public.character_proficiencies p
               join public.items i on i.id::text = p.key
              where p.kind = 'weapon') then
    raise exception 'a weapon proficiency is still keyed by item id. Rolled back.';
  end if;
end
$$;

insert into public.schema_migrations (version) values ('162');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the lists as stored, and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: thirteen rows matching the table in the header, then
-- ledger_row = true on every row.

begin;

select name, weapon_training, weapon_proficiencies, multiclass_grants_weapons,
       (select count(*) = 1 from public.schema_migrations
         where version = '162') as ledger_row
  from public.classes
 where campaign_id is null
 order by name;

rollback;

-- db/163_magic_weapons_with_bases.sql
--
-- Turns the seeded magic weapons that name ONE weapon into weapon rows, so
-- they reach the attack table with their bonus and their base's proficiency.
-- 130-137 seeded every magic weapon as kind = 'general' text; 161 gave items
-- magic_bonus and base_weapon_id. "Any sword" items (Flame Tongue, Weapon +1,
-- Vorpal Sword...) stay text: the DM makes the concrete one as homebrew with
-- 161's Base weapon field, because the book leaves the weapon to the DM.
--
-- ⚠ WRITTEN FROM MEMORY (2026-11-07), like 147 and 152. Check each row
-- against the DMG (and TCoE for the Moon Sickle) before running. The bases
-- match what the seeded descriptions already say.
--
--   item                    base         bonus  changes from the base
--   Dagger of Venom         Dagger       +1
--   Dwarven Thrower         Warhammer    +3     thrown, 20/60
--   Hammer of Thunderbolts  Maul         +1
--   Javelin of Lightning    Javelin      none
--   Mace of Disruption      Mace         none
--   Mace of Smiting         Mace         +1     (+3 vs constructs: text)
--   Mace of Terror          Mace         none
--   Moon Sickle, +1/+2/+3   Sickle       tier   (also to spells: text)
--   Oathbow                 Longbow      none
--   Scimitar of Speed       Scimitar     +2
--   Sun Blade               Longsword    +2     finesse, radiant
--   Sword of Answering      Longsword    +3
--   Trident of Fish Command Trident      none
--
-- Ammunition (+1 Ammunition, Arrow of Slaying) is skipped: the attack table
-- has no ammunition row, and a +1 arrow's bonus applies to whatever bow fires
-- it.
--
-- Sun Blade's proficiency is "shortswords or longswords" in the book; with a
-- Longsword base it reads as longsword only. A character with only
-- shortsword proficiency adds Longsword as an extra. Too small to model.
--
-- A WEAPON ROW, SO THE SHOP CHANGES A LITTLE: these items still have a
-- rarity, so they stay under the Shop's Magic filter and out of its Weapons
-- filter (the kind filters exclude magic items). Their detail card now shows
-- weapon stats. Every existing stack keeps pointing at the same row.
--
-- pin_item_row pins only id, campaign_id and created_at, so this UPDATE needs
-- no trigger disabled. check_item_base_weapon (161) checks every base.
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

create temp table magic_bases (
  name text primary key,
  base text not null,
  bonus smallint,
  add_properties text[] not null default '{}',
  range_normal int,
  range_long int,
  damage_type text
) on commit drop;

insert into magic_bases (name, base, bonus, add_properties, range_normal, range_long, damage_type) values
  ('Dagger of Venom',         'Dagger',    1,    '{}',              null, null, null),
  ('Dwarven Thrower',         'Warhammer', 3,    array['thrown'],   20,   60,   null),
  ('Hammer of Thunderbolts',  'Maul',      1,    '{}',              null, null, null),
  ('Javelin of Lightning',    'Javelin',   null, '{}',              null, null, null),
  ('Mace of Disruption',      'Mace',      null, '{}',              null, null, null),
  ('Mace of Smiting',         'Mace',      1,    '{}',              null, null, null),
  ('Mace of Terror',          'Mace',      null, '{}',              null, null, null),
  ('Moon Sickle, +1',         'Sickle',    1,    '{}',              null, null, null),
  ('Moon Sickle, +2',         'Sickle',    2,    '{}',              null, null, null),
  ('Moon Sickle, +3',         'Sickle',    3,    '{}',              null, null, null),
  ('Oathbow',                 'Longbow',   null, '{}',              null, null, null),
  ('Scimitar of Speed',       'Scimitar',  2,    '{}',              null, null, null),
  ('Sun Blade',               'Longsword', 2,    array['finesse'],  null, null, 'radiant'),
  ('Sword of Answering',      'Longsword', 3,    '{}',              null, null, null),
  ('Trident of Fish Command', 'Trident',   null, '{}',              null, null, null);

-- Each name must be exactly one shared magic general item, and each base
-- exactly one shared mundane weapon, before anything is written: an UPDATE
-- whose join matches nothing succeeds silently (CLAUDE.md).
do $$
declare
  v_bad text;
begin
  select string_agg(m.name, ', ') into v_bad
    from magic_bases m
   where (select count(*) from public.items i
           where i.campaign_id is null and i.name = m.name
             and i.kind = 'general' and i.rarity is not null) <> 1;
  if v_bad is not null then
    raise exception 'not exactly one shared magic general item: %. Rolled back.', v_bad;
  end if;

  select string_agg(distinct m.base, ', ') into v_bad
    from magic_bases m
   where (select count(*) from public.items b
           where b.campaign_id is null and b.name = m.base
             and b.kind = 'weapon' and b.rarity is null) <> 1;
  if v_bad is not null then
    raise exception 'not exactly one shared mundane weapon: %. Rolled back.', v_bad;
  end if;
end
$$;

update public.items i
   set kind            = 'weapon',
       base_weapon_id  = b.id,
       magic_bonus     = m.bonus,
       weapon_category = b.weapon_category,
       damage_dice     = b.damage_dice,
       damage_type     = coalesce(m.damage_type, b.damage_type),
       properties      = (select array_agg(distinct p order by p)
                            from unnest(coalesce(b.properties, '{}') || m.add_properties) p),
       versatile_dice  = b.versatile_dice,
       range_normal    = coalesce(m.range_normal, b.range_normal),
       range_long      = coalesce(m.range_long, b.range_long)
  from magic_bases m
  join public.items b
    on b.campaign_id is null and b.name = m.base
   and b.kind = 'weapon' and b.rarity is null
 where i.campaign_id is null
   and i.name = m.name;

-- ---- Assert the end state. -------------------------------------------------
do $$
declare
  v_count int;
begin
  select count(*) into v_count
    from magic_bases m
    join public.items i on i.campaign_id is null and i.name = m.name
    join public.items b on b.id = i.base_weapon_id
   where i.kind = 'weapon'
     and b.name = m.base
     and i.magic_bonus is not distinct from m.bonus
     and i.damage_dice = b.damage_dice;
  if v_count <> 15 then
    raise exception '% of 15 magic weapons converted. Rolled back.', v_count;
  end if;
end
$$;

insert into public.schema_migrations (version) values ('163');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the fifteen rows as stored, and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: fifteen rows matching the header's table; ledger_row true.

begin;

select i.name, b.name as base, i.magic_bonus, i.damage_dice, i.damage_type,
       i.properties, i.range_normal, i.range_long,
       (select count(*) = 1 from public.schema_migrations
         where version = '163') as ledger_row
  from public.items i
  join public.items b on b.id = i.base_weapon_id
 where i.campaign_id is null
 order by i.name;

rollback;

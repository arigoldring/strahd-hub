-- db/166_effect_keys_races.sql
--
-- Puts 164's two race-level effect keys on their races:
--
--   Dwarf      heavy_armor_speed   heavy armour's STR requirement costs no speed
--   Half-Orc   savage_attacks      one extra weapon die on a melee crit
--
-- (164's third key, dwarven_toughness, went on Hill Dwarf in 165. That was
-- safe early because no deployed client read subraces.)
--
-- ⚠ RUN ONLY AFTER THE CLIENT FROM THE SAME CHANGE IS DEPLOYED. The client
-- before it parses races.effect strictly and knows neither key, so this file
-- would blank the sheet of every character in every campaign (the race
-- catalogue is loaded whole). 160's header has the same warning.
--
-- Resolved by name with `into strict` (160's shape): races has no unique
-- name, so strict turns "no such race" or "two of them" into a rollback.
--
-- No schema change, so no reload and no gen:types.
--
-- Run by Claude via `npx supabase db query --linked`. In the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  -- The one place each row is named.
  c_races constant text[][] := array[
    ['Dwarf',    'heavy_armor_speed'],
    ['Half-Orc', 'savage_attacks']
  ];

  v_seeking text;
  v_id      uuid;
  v_count   int;
  i         int;
begin
  for i in 1 .. array_length(c_races, 1) loop
    v_seeking := c_races[i][1];
    select r.id into strict v_id
      from public.races r
     where r.name = c_races[i][1] and r.campaign_id is null;
    update public.races set effect = c_races[i][2] where id = v_id;
  end loop;

  -- Assert the end state: these two plus 160's Warforged, and no other.
  select count(*) into v_count
    from public.races where effect is not null;
  if v_count <> 3 then
    raise exception '% keyed races (expected 3). Rolled back.', v_count;
  end if;

  for i in 1 .. array_length(c_races, 1) loop
    select count(*) into v_count
      from public.races
     where name = c_races[i][1] and campaign_id is null
       and effect = c_races[i][2];
    if v_count <> 1 then
      raise exception 'Race % does not carry %. Rolled back.', c_races[i][1], c_races[i][2];
    end if;
  end loop;
exception
  when no_data_found then
    raise exception 'Found no shared race %. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one shared race %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('166');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the keys and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select effect::text = 'heavy_armor_speed' from public.races
    where name = 'Dwarf' and campaign_id is null)                  as dwarf,
  (select effect::text = 'savage_attacks' from public.races
    where name = 'Half-Orc' and campaign_id is null)               as half_orc,
  (select effect::text = 'integrated_protection' from public.races
    where name = 'Warforged' and campaign_id is null)              as warforged_kept,
  (select count(*) = 1 from public.schema_migrations
    where version = '166')                                         as ledger_row;

rollback;

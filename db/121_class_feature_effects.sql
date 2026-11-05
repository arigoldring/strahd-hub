-- db/121_class_feature_effects.sql
--
-- class_features.effect: the key that tells the sheet a feature changes a
-- number it derives. Until now every feature row was display only
-- (KNOWN_ISSUES), and the sheet could only have found Extra Attack by its
-- name. CLAUDE.md's rule is that the sheet keys on data, not names (095 gave
-- feature_options a `key` for the same reason), so the link is a column.
--
-- WHY A COLUMN AND NOT A NAME MAP IN rules.ts:
--   * A homebrew class's feature can opt into an effect by carrying the key.
--     A name map would either miss it, or hand the effect to any homebrew row
--     that happened to reuse a name.
--   * Renaming a row can't silently switch its effect off.
--   * The column says which rows the sheet computes from, so "is this feature
--     display only?" has an answer in the database.
--
-- THE KEYS ARE A CHECK, AND ONE LIST IN TWO PLACES with FEATURE_EFFECTS in
-- src/data/rules.ts, as with featCategories. The set is small and closed, and
-- a new key means new maths in rules.ts, so adding one should be a migration.
-- A row carries at most one effect: no feature seeded so far needs two.
--
-- THE KEYS, and the 21 shared rows they go on:
--   extra_attack          Extra Attack: Barbarian, Monk, Paladin, Ranger
--                         (5th), Valor and Swords Bards and Bladesinging (6th)
--   extra_attack_fighter  the Fighter's Extra Attack, which grows to three
--                         attacks at 11th and four at 20th. A separate key
--                         because the tiers belong to that row alone.
--   improved_critical     Champion 3rd: crit on 19-20
--   superior_critical     Champion 15th: crit on 18-20
--   sneak_attack          Rogue 1st: ceil(level / 2) d6
--   martial_arts          Monk 1st: DEX with monk weapons, the Martial Arts die
--   jack_of_all_trades    Bard 2nd: half proficiency (down) on untrained checks
--   remarkable_athlete    Champion 7th: half proficiency (up) on untrained
--                         STR, DEX and CON checks
--   dread_ambusher        Gloom Stalker 3rd: WIS to initiative
--   tactical_wit          War Magic 2nd: INT to initiative
--   rakish_audacity       Swashbuckler 3rd: CHA to initiative
--   aura_of_protection    Paladin 6th: CHA (minimum +1) to saving throws
--   fast_movement         Barbarian 5th: +10 ft without heavy armor
--   unarmored_movement    Monk 2nd: +10 to +30 ft without armor or shield
--   draconic_resilience   Draconic Bloodline 1st: +1 HP per level, AC 13 + DEX
--
-- Only the number each one changes is computed. The conditions the sheet
-- can't see stay with the player: Sneak Attack still needs advantage or an
-- ally beside the target, Aura of Protection needs the paladin conscious, and
-- Dread Ambusher's first-turn extra attack is not shown.
--
-- class_features has no UPDATE policy (shared rows are owner-only) and no pin
-- trigger, so the backfill is a plain UPDATE as the table owner (083's shape).
-- Each row is resolved with `into strict` from its class, subclass and name,
-- the identity the shared-row unique index guarantees.
--
-- Run by Claude via `npx supabase db query --linked`; in the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): this file creates no table.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

alter table public.class_features
  add column effect text check (effect in (
    'extra_attack', 'extra_attack_fighter', 'improved_critical',
    'superior_critical', 'sneak_attack', 'martial_arts',
    'jack_of_all_trades', 'remarkable_athlete', 'dread_ambusher',
    'tactical_wit', 'rakish_audacity', 'aura_of_protection',
    'fast_movement', 'unarmored_movement', 'draconic_resilience'
  ));

do $$
declare
  -- The one place each row is named. Nothing below repeats them.
  -- (class, subclass or null, feature, effect)
  c_rows constant text[][] := array[
    ['Barbarian', null,                 'Extra Attack',        'extra_attack'],
    ['Bard',      'College of Swords',  'Extra Attack',        'extra_attack'],
    ['Bard',      'College of Valor',   'Extra Attack',        'extra_attack'],
    ['Monk',      null,                 'Extra Attack',        'extra_attack'],
    ['Paladin',   null,                 'Extra Attack',        'extra_attack'],
    ['Ranger',    null,                 'Extra Attack',        'extra_attack'],
    ['Wizard',    'Bladesinging',       'Extra Attack',        'extra_attack'],
    ['Fighter',   null,                 'Extra Attack',        'extra_attack_fighter'],
    ['Fighter',   'Champion',           'Improved Critical',   'improved_critical'],
    ['Fighter',   'Champion',           'Superior Critical',   'superior_critical'],
    ['Rogue',     null,                 'Sneak Attack',        'sneak_attack'],
    ['Monk',      null,                 'Martial Arts',        'martial_arts'],
    ['Bard',      null,                 'Jack of All Trades',  'jack_of_all_trades'],
    ['Fighter',   'Champion',           'Remarkable Athlete',  'remarkable_athlete'],
    ['Ranger',    'Gloom Stalker',      'Dread Ambusher',      'dread_ambusher'],
    ['Wizard',    'War Magic',          'Tactical Wit',        'tactical_wit'],
    ['Rogue',     'Swashbuckler',       'Rakish Audacity',     'rakish_audacity'],
    ['Paladin',   null,                 'Aura of Protection',  'aura_of_protection'],
    ['Barbarian', null,                 'Fast Movement',       'fast_movement'],
    ['Monk',      null,                 'Unarmored Movement',  'unarmored_movement'],
    ['Sorcerer',  'Draconic Bloodline', 'Draconic Resilience', 'draconic_resilience']
  ];

  v_seeking text;
  v_feature uuid;
  v_count   int;
  i         int;
begin
  for i in 1 .. array_length(c_rows, 1) loop
    v_seeking := format('%s / %s / %s', c_rows[i][1],
                        coalesce(c_rows[i][2], 'base class'), c_rows[i][3]);
    select f.id into strict v_feature
      from public.class_features f
      join public.classes k on k.id = f.class_id
      left join public.subclasses s on s.id = f.subclass_id
     where k.name = c_rows[i][1] and k.campaign_id is null
       and f.campaign_id is null
       and f.name = c_rows[i][3]
       and s.name is not distinct from c_rows[i][2];

    update public.class_features set effect = c_rows[i][4] where id = v_feature;
  end loop;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  -- Every listed row carries its key, and no other row carries one.
  select count(*) into v_count
    from public.class_features f
   where f.effect is not null;
  if v_count <> array_length(c_rows, 1) then
    raise exception '% rows carry an effect (expected %). Rolled back.',
      v_count, array_length(c_rows, 1);
  end if;

  for i in 1 .. array_length(c_rows, 1) loop
    select count(*) into v_count
      from public.class_features f
      join public.classes k on k.id = f.class_id
      left join public.subclasses s on s.id = f.subclass_id
     where k.name = c_rows[i][1] and k.campaign_id is null
       and f.campaign_id is null and f.name = c_rows[i][3]
       and s.name is not distinct from c_rows[i][2]
       and f.effect = c_rows[i][4];
    if v_count <> 1 then
      raise exception '% does not carry %. Rolled back.',
        format('%s / %s / %s', c_rows[i][1], coalesce(c_rows[i][2], 'base class'),
               c_rows[i][3]),
        c_rows[i][4];
    end if;
  end loop;
exception
  when no_data_found then
    raise exception 'Found no shared feature %. 084-120 seed them. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one shared feature %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('121');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the keys landed where the header says
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 21 from public.class_features where effect is not null)  as twenty_one,
  (select count(*) = 7 from public.class_features
    where effect = 'extra_attack')                                           as extra_attack_7,
  (select count(distinct effect) = 15 from public.class_features)           as fifteen_keys,
  (select bool_and(campaign_id is null) from public.class_features
    where effect is not null)                                                as all_shared,
  (select count(*) = 1 from public.schema_migrations
    where version = '121')                                                   as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the CHECK refuses a key rules.ts doesn't know
-- ---------------------------------------------------------------------------
--
-- 'rage' is the plausible wrong answer: a real feature whose number (rage
-- damage) the sheet does not compute.
--
-- CORRECT OUTPUT: one row, outcome = 'rejected by the check (23514)'.

begin;

do $$
begin
  update public.class_features set effect = 'rage'
   where id = (select id from public.class_features where name = 'Rage' limit 1);
  perform set_config('verification.outcome', 'UPDATE SUCCEEDED -- CHECK MISSING', true);
exception
  when check_violation then
    perform set_config('verification.outcome', 'rejected by the check (23514)', true);
end
$$;

select 'an unknown effect key' as check,
       current_setting('verification.outcome') as outcome;

rollback;

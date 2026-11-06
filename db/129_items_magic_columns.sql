-- db/129_items_magic_columns.sql
--
-- Gives items a way to be magic. Until now `kind` (general | weapon | armor)
-- was the only thing that classified an item, and nothing could say "this is
-- a Bag of Holding, uncommon" except prose in the description. 130-137 seed
-- every non-artifact magic item from the DMG, XGtE and TCoE; this file is the
-- schema they need.
--
-- RARITY IS AN AXIS, NOT A KIND. `kind` decides which columns a row has
-- (001's *_fields_required / *_fields_absent checks). "Magic" is orthogonal
-- to that: a +1 longsword is a weapon AND magic, a Bag of Holding is general
-- AND magic. A fourth kind would have forced every magic item to give up its
-- weapon or armour columns, and would have made "a magic weapon" a contradiction
-- in the schema. So magic is a nullable column beside kind: rarity null means
-- mundane, and that is the only spelling of mundane.
--
-- 'varies' is for the two items the DMG does not split into one rarity per
-- row (Spell Scroll, Figurine of Wondrous Power). Everything else that comes in
-- tiers is seeded one row per tier (+1/+2/+3 Weapon, each Belt of Giant
-- Strength), so its rarity is a fact rather than a range.
--
-- THE CHECK AND `magicRarities` IN services/items.ts ARE ONE LIST IN TWO
-- PLACES. toItem narrows the column against the tuple with parseOneOf, so a
-- value the database admits but the client doesn't know throws on the way in
-- and blanks the whole Shop. Change them together, client first.
--
-- ATTUNEMENT is a boolean plus an optional note ("by a cleric or paladin").
-- Two CHECKs make the nonsense states unrepresentable: a mundane item cannot
-- require attunement, and a note cannot exist without the requirement.
--
-- PRICE: magic items are seeded at price_cp = 0, and the client shows the
-- rarity where the price would be (priceLabel in services/items.ts). The 2014
-- books give rarity ranges, not prices. Potion of Healing is the exception:
-- the PHB prices it at 50 gp, so it keeps that price and only gains its rarity.
--
-- PIN TRIGGER: pin_item_row is a blocklist (053), so all three columns are
-- DM-editable on homebrew, which is the right answer. Shared rows have no
-- UPDATE policy, so they stay owner-only.
--
-- AFTERWARDS: npm run gen:types. No notify pgrst needed; select("*") picks up
-- the columns, and the deployed client ignores fields it doesn't read, so this
-- is safe to run before the client that reads them ships.
--
-- RUN THE MIGRATION BLOCK ON ITS OWN, then the verification blocks one at a
-- time.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

alter table public.items
  add column rarity text
    check (rarity in ('common', 'uncommon', 'rare', 'very rare', 'legendary', 'varies')),
  add column requires_attunement boolean not null default false,
  add column attunement_note text;

alter table public.items
  add constraint attunement_needs_rarity
    check (rarity is not null or not requires_attunement),
  add constraint attunement_note_needs_attunement
    check (attunement_note is null or requires_attunement);

-- The one magic item the shared catalogue already holds (003). Asserted below,
-- since an update that matches nothing is a successful statement.
update public.items
   set rarity = 'common',
       tags = case when 'PHB' = any(tags) then tags else tags || array['PHB'] end
 where campaign_id is null
   and name = 'Potion of Healing';

do $$
begin
  if (select count(*) from public.items
       where campaign_id is null and name = 'Potion of Healing'
         and rarity = 'common') <> 1 then
    raise exception 'expected exactly one shared Potion of Healing marked common';
  end if;
end
$$;

insert into public.schema_migrations (version) values ('129');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Each block is independent. Run them one at a time. Blocks that write end in
-- `rollback`, so nothing here survives.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

select
  (select count(*) = 3
     from information_schema.columns
    where table_schema = 'public' and table_name = 'items'
      and column_name in ('rarity', 'requires_attunement', 'attunement_note'))  as columns,
  (select count(*) = 2
     from pg_constraint
    where conrelid = 'public.items'::regclass
      and conname in ('attunement_needs_rarity',
                      'attunement_note_needs_attunement'))                      as constraints,
  (select count(*) = 1
     from public.items
    where campaign_id is null and name = 'Potion of Healing'
      and rarity = 'common' and price_cp = 5000)                                as potion,
  (select count(*) = 1
     from public.schema_migrations
    where version = '129')                                                      as ledger_row;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the CHECKs refuse the three nonsense states
-- ---------------------------------------------------------------------------
--
-- Runs as the table owner, so RLS is out of the picture and only the
-- constraints can refuse.
--
-- CORRECT OUTPUT: one row; all three outcomes 'rejected by the check (23514)'.
--                 'INSERT SUCCEEDED -- CONSTRAINT MISSING' means that check
--                 never landed.

begin;

do $$
begin
  begin
    insert into public.items (name, price_cp, rarity)
    values ('Bad Rarity', 0, 'mythic');
    perform set_config('verification.rarity', 'INSERT SUCCEEDED -- CONSTRAINT MISSING', true);
  exception when check_violation then
    perform set_config('verification.rarity', 'rejected by the check (23514)', true);
  end;

  begin
    insert into public.items (name, price_cp, requires_attunement)
    values ('Mundane Attuned', 0, true);
    perform set_config('verification.attune', 'INSERT SUCCEEDED -- CONSTRAINT MISSING', true);
  exception when check_violation then
    perform set_config('verification.attune', 'rejected by the check (23514)', true);
  end;

  begin
    insert into public.items (name, price_cp, rarity, attunement_note)
    values ('Orphan Note', 0, 'rare', 'by a wizard');
    perform set_config('verification.note', 'INSERT SUCCEEDED -- CONSTRAINT MISSING', true);
  exception when check_violation then
    perform set_config('verification.note', 'rejected by the check (23514)', true);
  end;
end
$$;

select 'case 1: nonsense magic states' as check,
       jsonb_build_object(
         'unknown_rarity',         current_setting('verification.rarity'),
         'mundane_with_attunement', current_setting('verification.attune'),
         'note_without_attunement', current_setting('verification.note')
       ) as result;

rollback;

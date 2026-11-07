-- db/158_caster_type.sql
--
-- Spell slots. KNOWN_ISSUES ("Spellcasting has no slot or school model")
-- asked for slots "as a derived table in rules.ts keyed on caster type". This
-- file adds the key. The table is spellSlots / pactSlots in rules.ts, and
-- the spent count is 153's character_resource_uses under `slot:<1-9>` and
-- `pact`, keys 153's CHECK already accepts.
--
-- caster_type, one list in two places with CASTER_TYPES in rules.ts:
--   full     Bard, Cleric, Druid, Sorcerer, Wizard: the PHB's Spellcaster
--            table by class level
--   half     Paladin, Ranger: the full table at half the level, rounded
--            up, from 2nd level (none at 1st)
--   half_up  Artificer: the same, but from 1st level. Its own key because
--            the Artificer's table starts a level earlier, which is the
--            "rounded up" in Tasha's multiclassing note.
--   third    Eldritch Knight, Arcane Trickster: the full table at a third
--            of the level, rounded up, from 3rd level
--   pact     Warlock: Pact Magic, all slots one level, back on a short rest
--
-- ON BOTH classes AND subclasses, as with spell_ability (071): the two
-- third-casters cast through an archetype of a class that doesn't. The
-- sheet takes the class's value, else the subclass's. Null means no slots.
--
-- A homebrew class or subclass is null until its DM sets it, which nothing
-- in the app can do yet (KNOWN_ISSUES, "Classes, subclasses and races can't
-- be created or edited from the app").
--
-- Single-class only, as agreed for this work: a multiclass caster's slots
-- come from the starting class's table, not the PHB's multiclass table
-- (KNOWN_ISSUES, "Use counters and rests").
--
-- The backfill is a plain UPDATE as the table owner. Shared classes and
-- subclasses have no UPDATE policy.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

alter table public.classes
  add column caster_type text check (caster_type in ('full', 'half', 'half_up', 'third', 'pact'));
alter table public.subclasses
  add column caster_type text check (caster_type in ('full', 'half', 'half_up', 'third', 'pact'));

do $$
declare
  v_count int;
begin
  update public.classes set caster_type = v.caster_type
    from (values
      ('Bard', 'full'), ('Cleric', 'full'), ('Druid', 'full'),
      ('Sorcerer', 'full'), ('Wizard', 'full'),
      ('Paladin', 'half'), ('Ranger', 'half'),
      ('Artificer', 'half_up'),
      ('Warlock', 'pact')
    ) as v(name, caster_type)
   where classes.name = v.name and classes.campaign_id is null;

  update public.subclasses s set caster_type = 'third'
    from public.classes k
   where k.id = s.class_id and k.campaign_id is null and s.campaign_id is null
     and (k.name, s.name) in (('Fighter', 'Eldritch Knight'), ('Rogue', 'Arcane Trickster'));

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
    from public.classes where campaign_id is null and caster_type is not null;
  if v_count <> 9 then
    raise exception '% shared classes have a caster type (expected 9). Rolled back.', v_count;
  end if;

  select count(*) into v_count
    from public.subclasses where campaign_id is null and caster_type is not null;
  if v_count <> 2 then
    raise exception '% shared subclasses have a caster type (expected 2). Rolled back.', v_count;
  end if;
end
$$;

insert into public.schema_migrations (version) values ('158');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the keys landed where the header says
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

select
  (select caster_type = 'pact' from public.classes
    where name = 'Warlock' and campaign_id is null)                as warlock_pact,
  (select caster_type = 'half_up' from public.classes
    where name = 'Artificer' and campaign_id is null)              as artificer_half_up,
  (select caster_type is null from public.classes
    where name = 'Fighter' and campaign_id is null)                as fighter_none,
  (select caster_type = 'third' from public.subclasses
    where name = 'Arcane Trickster' and campaign_id is null)       as trickster_third,
  (select count(*) = 1 from public.schema_migrations
    where version = '158')                                         as ledger_row;

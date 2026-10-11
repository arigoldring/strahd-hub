-- db/067_subclasses_barbarian.sql
--
-- Barbarian subclasses (Primal Path): 7 rows, 2 PHB, 3 XGtE, 2 TCoE.
-- One of twelve per-class files, 067-078. RUN 066 FIRST: it adds
-- subclass_title and source, which this file writes.
--
-- THIS FILE IS THE TEMPLATE FOR 068-078, and its reasoning is theirs.
--
-- ONE CLASS PER FILE so each is small enough to review against the book in
-- one sitting, and each one asserts its own count. The files depend on 066
-- and nothing else, so their order among themselves doesn't matter; run them
-- in number order anyway so the ledger reads cleanly.
--
-- THE CLASS IS NAMED ONCE, in c_class, and resolved once with `into strict`
-- (051's shape). A join on class name in the INSERT would be shorter, and
-- it is exactly 050's failure: a misspelt name matches nothing, the insert
-- succeeds having written zero rows, and the ledger records a migration that
-- did nothing. Here a miss is no_data_found and a duplicate is too_many_rows,
-- and both roll the file back. `campaign_id is null` keeps a DM's homebrew
-- class of the same name out of it.
--
-- THE CLOSING CHECK ASSERTS THE END STATE (052's shape): this class has
-- exactly c_expected shared subclasses and its title is set. It doesn't count
-- rows inserted, so it would also catch a stray hand-made shared row.
--
-- DESCRIPTIONS are one-line paraphrases in 055's voice, never book text. They
-- are what the picker shows until class features arrive.
--
-- spell_ability is null on every row except Eldritch Knight (071) and Arcane
-- Trickster (075), the reason 054 gave subclasses the column. Psi Warrior and
-- Soulknife use Intelligence for psionic save DCs but aren't spellcasters, so
-- they stay null.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- Tagged $seed$, not $$: the descriptions inside are $$-quoted (055's style),
-- and a bare $$ there would end this block's body early.
do $seed$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class    constant text := 'Barbarian';
  c_title    constant text := 'Primal Path';
  c_expected constant int  := 7;

  v_class uuid;
  v_count int;
  v_title text;
begin
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  update public.classes set subclass_title = c_title where id = v_class;

  insert into public.subclasses (class_id, name, source, spell_ability, description)
  select v_class, v.name, v.source, v.spell_ability, v.description
  from (values
      ($$Path of the Berserker$$, 'phb', null,
       $$Rage becomes a frenzy of extra attacks, paid for in exhaustion.$$),
      ($$Path of the Totem Warrior$$, 'phb', null,
       $$A spirit animal -- bear, eagle, wolf and others -- guides and shapes the rage.$$),
      ($$Path of the Ancestral Guardian$$, 'xgte', null,
       $$Ancestral spirits rise during the rage to shield allies and hinder foes.$$),
      ($$Path of the Storm Herald$$, 'xgte', null,
       $$The rage radiates a storm aura of desert heat, sea lightning or tundra cold.$$),
      ($$Path of the Zealot$$, 'xgte', null,
       $$A god's fury fuels the rage, and even death struggles to keep hold of the warrior.$$),
      ($$Path of the Beast$$, 'tcoe', null,
       $$The rage brings out bestial claws, a savage bite or a lashing tail.$$),
      ($$Path of Wild Magic$$, 'tcoe', null,
       $$Raw magic surges unpredictably whenever the rage begins.$$)
  ) as v(name, source, spell_ability, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.subclasses
  where class_id = v_class and campaign_id is null;

  select subclass_title into v_title from public.classes where id = v_class;

  if v_count <> c_expected or v_title is distinct from c_title then
    raise exception
      '% has % shared subclasses (expected %) and subclass_title %. Rolled back.',
      c_class, v_count, c_expected, coalesce(v_title, 'null');
  end if;
exception
  when no_data_found then
    raise exception
      'No shared class is named "%". 055 seeds it; check: select name from classes where campaign_id is null;',
      c_class;
  when too_many_rows then
    raise exception
      'More than one shared class is named "%". Resolve the duplicate before seeding its subclasses.',
      c_class;
end
$seed$;

insert into public.schema_migrations (version) values ('067');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the rows, the title and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 7 from public.subclasses s
     join public.classes c on c.id = s.class_id
    where c.name = 'Barbarian' and c.campaign_id is null
      and s.campaign_id is null)                                     as count_7,
  (select subclass_title = 'Primal Path' from public.classes
    where name = 'Barbarian' and campaign_id is null)                 as title_set,
  (select count(*) = 1 from public.subclasses s
     join public.classes c on c.id = s.class_id
    where c.name = 'Barbarian' and c.campaign_id is null
      and s.name = $$Path of Wild Magic$$ and s.source = 'tcoe')       as spot_check,
  (select count(*) = 1 from public.schema_migrations
    where version = '067')                                         as ledger_row;

rollback;

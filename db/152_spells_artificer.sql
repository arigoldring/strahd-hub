-- db/152_spells_artificer.sql
--
-- Adds 'Artificer' to the `classes` array of every shared spell on Tasha's
-- Artificer list: 95 spells, cantrips to 5th level. RUN 149 FIRST: the
-- class guard below requires a shared Artificer.
--
-- WHY NOW. 138-147 left the Artificer out of every class list rather than
-- name a class nothing could pick (KNOWN_ISSUES, "Spell class lists leave
-- out the Artificer"). 149 seeds the class; the issue said to fix the
-- lists in the same change, and this is that file.
--
-- WHAT'S IN IT. The class's own list only. Battle Smith Spells (heroism,
-- shield, branding smite and so on) are always prepared for that
-- subclass, not artificer-list spells, and stay in 150's feature text, the
-- same way no domain or oath list was ever written into `classes`. The
-- SCAG cantrips Tasha's reprints (Booming Blade, Green-Flame Blade,
-- Lightning Lure, Sword Burst) are included because the catalogue already
-- holds them as shared rows.
--
-- ⚠ CHECK AGAINST THE BOOK. Like 147, these pairs were written from memory
-- of TCoE's table, not copied from it. The name guard proves every name is
-- a real shared spell, not that every spell belongs on the list. A wrong
-- pair is a one-line fix in a later migration: array_remove on that spell.
--
-- SHAPE: 147's exactly. Names written once into a temp table; two guards
-- (every spell name resolves to exactly one shared spell, the class to a
-- shared class) because a misspelt name in an UPDATE's `where` matches
-- nothing and succeeds; then a de-duplicating, sorted union into each
-- array; then an end-state assertion that every pair is present.
--
-- RUN AS ONE BLOCK. CORRECT OUTPUT: "Success. No rows returned." If the
-- Supabase editor offers to enable RLS, decline (CLAUDE.md).

begin;

create temp table _ext (
  spell_name text not null,
  class_name text not null,
  primary key (spell_name, class_name)
) on commit drop;

insert into _ext (class_name, spell_name)
select 'Artificer', n from unnest(array[
  -- Cantrips (23)
  $$Acid Splash$$, $$Booming Blade$$, $$Create Bonfire$$, $$Dancing Lights$$,
  $$Fire Bolt$$, $$Frostbite$$, $$Green-Flame Blade$$, $$Guidance$$, $$Light$$,
  $$Lightning Lure$$, $$Mage Hand$$, $$Magic Stone$$, $$Mending$$, $$Message$$,
  $$Poison Spray$$, $$Prestidigitation$$, $$Ray of Frost$$, $$Resistance$$,
  $$Shocking Grasp$$, $$Spare the Dying$$, $$Sword Burst$$, $$Thorn Whip$$,
  $$Thunderclap$$,
  -- 1st (18)
  $$Absorb Elements$$, $$Alarm$$, $$Catapult$$, $$Cure Wounds$$,
  $$Detect Magic$$, $$Disguise Self$$, $$Expeditious Retreat$$,
  $$Faerie Fire$$, $$False Life$$, $$Feather Fall$$, $$Grease$$, $$Identify$$,
  $$Jump$$, $$Longstrider$$, $$Purify Food and Drink$$, $$Sanctuary$$,
  $$Snare$$, $$Tasha's Caustic Brew$$,
  -- 2nd (21)
  $$Aid$$, $$Alter Self$$, $$Arcane Lock$$, $$Blur$$, $$Continual Flame$$,
  $$Darkvision$$, $$Enhance Ability$$, $$Enlarge/Reduce$$, $$Heat Metal$$,
  $$Invisibility$$, $$Lesser Restoration$$, $$Levitate$$, $$Magic Mouth$$,
  $$Magic Weapon$$, $$Protection from Poison$$, $$Pyrotechnics$$,
  $$Rope Trick$$, $$See Invisibility$$, $$Skywrite$$, $$Spider Climb$$, $$Web$$,
  -- 3rd (15)
  $$Blink$$, $$Catnap$$, $$Create Food and Water$$, $$Dispel Magic$$,
  $$Elemental Weapon$$, $$Flame Arrows$$, $$Fly$$, $$Glyph of Warding$$,
  $$Haste$$, $$Intellect Fortress$$, $$Protection from Energy$$, $$Revivify$$,
  $$Tiny Servant$$, $$Water Breathing$$, $$Water Walk$$,
  -- 4th (11)
  $$Arcane Eye$$, $$Elemental Bane$$, $$Fabricate$$, $$Freedom of Movement$$,
  $$Leomund's Secret Chest$$, $$Mordenkainen's Faithful Hound$$,
  $$Mordenkainen's Private Sanctum$$, $$Otiluke's Resilient Sphere$$,
  $$Stone Shape$$, $$Stoneskin$$, $$Summon Construct$$,
  -- 5th (7)
  $$Animate Objects$$, $$Bigby's Hand$$, $$Creation$$, $$Greater Restoration$$,
  $$Skill Empowerment$$, $$Transmute Rock$$, $$Wall of Stone$$
]) as n;

do $do$
declare
  v_missing text;
  v_count   int := (select count(*) from _ext);
begin
  -- The list's own size, so a dropped or doubled line in the array above
  -- (the primary key would refuse a double) is caught before the update.
  if v_count <> 95 then
    raise exception 'artificer list has % names (expected 95)', v_count;
  end if;

  select string_agg(distinct e.spell_name, ', ') into v_missing
    from _ext e
   where (select count(*) from public.spells s
           where s.campaign_id is null and s.name = e.spell_name) <> 1;
  if v_missing is not null then
    raise exception 'artificer list names spells that are not exactly one shared row: %', v_missing;
  end if;

  select string_agg(distinct e.class_name, ', ') into v_missing
    from _ext e
   where not exists (select 1 from public.classes c
                      where c.campaign_id is null and c.name = e.class_name);
  if v_missing is not null then
    raise exception 'artificer list names classes not in the catalogue: %', v_missing;
  end if;
end
$do$;

update public.spells s
   set classes = (
     select array_agg(distinct c order by c)
       from unnest(s.classes || array(
              select e.class_name from _ext e where e.spell_name = s.name)) c
   )
 where s.campaign_id is null
   and s.name in (select spell_name from _ext);

do $do$
declare
  v_expected int := (select count(*) from _ext);
  v_found    int;
begin
  select count(*) into v_found
    from _ext e
    join public.spells s
      on s.campaign_id is null
     and s.name = e.spell_name
     and e.class_name = any (s.classes);
  if v_found <> v_expected then
    raise exception 'artificer list incomplete: % of % pairs present', v_found, v_expected;
  end if;
end
$do$;

insert into public.schema_migrations (version) values ('152');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the list by level, a spell that must not be on it, the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select array_agg(n order by lvl)
          = array[23, 18, 21, 15, 11, 7]::bigint[]
     from (select level as lvl, count(*) as n
             from public.spells
            where campaign_id is null and 'Artificer' = any (classes)
            group by level) t)                                        as by_level,
  (select not ('Artificer' = any (classes)) from public.spells
    where campaign_id is null and name = 'Shield')                    as shield_not_listed,
  (select count(*) = 1 from public.schema_migrations
    where version = '152')                                            as ledger_row;

rollback;

-- db/147_spells_tcoe_expanded_lists.sql
--
-- Adds Tasha's Cauldron of Everything's optional "expanded spell lists" to
-- the shared catalogue's `classes` arrays. The last of 138-147 (138's header
-- has the map).
--
-- WHY ITS OWN FILE. 138-146 write each spell's class list as its own book
-- prints it. TCoE's expansions are an optional rule, adopted for this table
-- on 2026-11-06, and keeping them here means the whole rule reads, and
-- reverts, as one diff. It covers only spells from other books; a TCoE
-- spell's own entry already lists its classes (146). No Artificer list:
-- that class isn't in the catalogue.
--
-- ⚠ CHECK AGAINST THE BOOK. These pairs were written from memory of TCoE's
-- tables, not copied from them. The likeliest slips are at the edges:
-- Sorcerer's Flame Blade, and the 8th/9th rows (Bard's Antipathy/Sympathy
-- and Prismatic Wall, Cleric's Sunburst and Power Word Heal, Druid's
-- Incendiary Cloud, Sorcerer's Demiplane). A wrong pair is a one-line fix in
-- a later migration: array_remove on that spell.
--
-- SHAPE. The pairs are written once into a temp table. The update unions
-- each spell's new classes into its array, de-duplicated and sorted, so a
-- re-run (were the ledger not stopping it) would change nothing. Two
-- guards run first, because a misspelt name in an UPDATE's `where` matches
-- nothing and succeeds (CLAUDE.md, the 050 lesson): every spell name must
-- resolve to exactly one shared spell, and every class name to a shared
-- class. The assertion is on the end state: every pair present.
--
-- RUN AS ONE BLOCK. CORRECT OUTPUT: "Success. No rows returned." If the
-- Supabase editor offers to enable RLS, decline (CLAUDE.md).

begin;

create temp table _ext (
  spell_name text not null,
  class_name text not null,
  primary key (spell_name, class_name)
) on commit drop;

insert into _ext (class_name, spell_name) values
-- Bard
('Bard', $$Color Spray$$), ('Bard', $$Command$$), ('Bard', $$Aid$$),
('Bard', $$Enlarge/Reduce$$), ('Bard', $$Mirror Image$$),
('Bard', $$Mass Healing Word$$), ('Bard', $$Slow$$),
('Bard', $$Phantasmal Killer$$), ('Bard', $$Rary's Telepathic Bond$$),
('Bard', $$Heroes' Feast$$), ('Bard', $$Prismatic Spray$$),
('Bard', $$Antipathy/Sympathy$$), ('Bard', $$Prismatic Wall$$),
-- Cleric
('Cleric', $$Aura of Vitality$$), ('Cleric', $$Aura of Life$$),
('Cleric', $$Aura of Purity$$), ('Cleric', $$Sunbeam$$),
('Cleric', $$Sunburst$$), ('Cleric', $$Power Word Heal$$),
-- Druid
('Druid', $$Protection from Evil and Good$$), ('Druid', $$Augury$$),
('Druid', $$Continual Flame$$), ('Druid', $$Enlarge/Reduce$$),
('Druid', $$Aura of Vitality$$), ('Druid', $$Elemental Weapon$$),
('Druid', $$Revivify$$), ('Druid', $$Divination$$), ('Druid', $$Fire Shield$$),
('Druid', $$Cone of Cold$$), ('Druid', $$Flesh to Stone$$),
('Druid', $$Symbol$$), ('Druid', $$Incendiary Cloud$$),
-- Paladin
('Paladin', $$Gentle Repose$$), ('Paladin', $$Prayer of Healing$$),
('Paladin', $$Warding Bond$$),
-- Ranger
('Ranger', $$Entangle$$), ('Ranger', $$Searing Smite$$), ('Ranger', $$Aid$$),
('Ranger', $$Enhance Ability$$), ('Ranger', $$Gust of Wind$$),
('Ranger', $$Magic Weapon$$), ('Ranger', $$Elemental Weapon$$),
('Ranger', $$Meld into Stone$$), ('Ranger', $$Revivify$$),
('Ranger', $$Dominate Beast$$), ('Ranger', $$Greater Restoration$$),
-- Sorcerer
('Sorcerer', $$Grease$$), ('Sorcerer', $$Flame Blade$$),
('Sorcerer', $$Flaming Sphere$$), ('Sorcerer', $$Magic Weapon$$),
('Sorcerer', $$Vampiric Touch$$), ('Sorcerer', $$Fire Shield$$),
('Sorcerer', $$Bigby's Hand$$), ('Sorcerer', $$Flesh to Stone$$),
('Sorcerer', $$Otiluke's Freezing Sphere$$), ('Sorcerer', $$Demiplane$$),
-- Warlock
('Warlock', $$Mislead$$), ('Warlock', $$Planar Binding$$),
('Warlock', $$Teleportation Circle$$),
-- Wizard
('Wizard', $$Augury$$), ('Wizard', $$Enhance Ability$$),
('Wizard', $$Speak with Dead$$), ('Wizard', $$Divination$$);

do $do$
declare
  v_missing text;
begin
  select string_agg(distinct e.spell_name, ', ') into v_missing
    from _ext e
   where (select count(*) from public.spells s
           where s.campaign_id is null and s.name = e.spell_name) <> 1;
  if v_missing is not null then
    raise exception 'expanded lists name spells that are not exactly one shared row: %', v_missing;
  end if;

  select string_agg(distinct e.class_name, ', ') into v_missing
    from _ext e
   where not exists (select 1 from public.classes c
                      where c.campaign_id is null and c.name = e.class_name);
  if v_missing is not null then
    raise exception 'expanded lists name classes not in the catalogue: %', v_missing;
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
    raise exception 'expanded lists incomplete: % of % pairs present', v_found, v_expected;
  end if;
end
$do$;

insert into public.schema_migrations (version) values ('147');

commit;

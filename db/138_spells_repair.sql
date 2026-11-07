-- db/138_spells_repair.sql
--
-- Repairs the 81 spells 023/024 seeded, before 139-146 add the rest of the
-- 2014 catalogue around them, and makes a duplicate shared spell unwritable.
--
--   138 repair + index   139 PHB 0-1   140 PHB 2     141 PHB 3
--   142 PHB 4-5          143 PHB 6-7   144 PHB 8-9   145 XGtE   146 TCoE
--   147 TCoE expanded class lists
--
-- WHY A REPAIR. An audit against the 2014 PHB (2026-11-06) found about a
-- third of the old rows wrong somewhere:
--   * levels: Thorn Whip is a cantrip (024 had 1st), Feeblemind is 8th
--     (024 had 5th). Each row's level tag in `tags` moves with it.
--   * components: Counterspell is S only; Magic Missile, Shield, Sleep,
--     Detect Magic, Sacred Flame, Blink, Telekinesis and Dispel Magic have an
--     S the old rows lacked; Blur, Blindness/Deafness and Darkness have none;
--     Magic Weapon and Conjure Animals have no M; Feather Fall, Hex, Sleep,
--     Fear, Lightning Bolt and Thorn Whip have an M.
--   * class lists, set here to the PHB's own list: Fire Bolt is not Bard,
--     Identify and Call Lightning are not Cleric, Revivify is not Bard,
--     Greater Restoration is not Paladin, Heat Metal and Daylight are not
--     Wizard, Dispel Magic is not Ranger, and Hold Person, Invisibility,
--     Mirror Image, Misty Step and Counterspell are Warlock. A few rows carried
--     a TCoE optional class (Grease on Sorcerer, Aid on Bard, Enhance Ability
--     on Wizard); they are reset to the PHB list here and 147 puts them back,
--     so the optional rule lives in exactly one file.
-- Every row touched gets its material component written; the untouched old
-- rows still have none (KNOWN_ISSUES). Descriptions are left alone.
--
-- `spells` has no pin trigger and no UPDATE policy, so this runs as the table
-- owner with nothing to disable.
--
-- THE INDEX. Shared spells are unique by name from here on, the move 066 made
-- for subclasses. Today's 81 names are distinct (checked live). The seeds
-- keep their `not exists` guard anyway, in 130's shape.
--
-- RUN AS ONE BLOCK. CORRECT OUTPUT: "Success. No rows returned." If the
-- Supabase editor offers to enable RLS, decline (CLAUDE.md).

begin;

create unique index spells_shared_name_key
  on public.spells (name) where campaign_id is null;

create temp table _fix (
  name               text primary key,
  level              int  not null,
  comp               text not null,   -- any of V, S, M
  material_component text,
  classes            text[] not null
) on commit drop;

insert into _fix values
($$Thorn Whip$$,             0, 'VSM', $$the stem of a plant with thorns$$, array['Druid']),
($$Feeblemind$$,             8, 'VSM', $$a handful of clay, crystal, glass, or mineral spheres$$, array['Bard','Druid','Warlock','Wizard']),
($$Sacred Flame$$,           0, 'VS',  null, array['Cleric']),
($$Fire Bolt$$,              0, 'VS',  null, array['Sorcerer','Wizard']),
($$Detect Magic$$,           1, 'VS',  null, array['Bard','Cleric','Druid','Paladin','Ranger','Sorcerer','Wizard']),
($$Feather Fall$$,           1, 'VM',  $$a small feather or piece of down$$, array['Bard','Sorcerer','Wizard']),
($$Hex$$,                    1, 'VSM', $$the petrified eye of a newt$$, array['Warlock']),
($$Magic Missile$$,          1, 'VS',  null, array['Sorcerer','Wizard']),
($$Shield$$,                 1, 'VS',  null, array['Sorcerer','Wizard']),
($$Sleep$$,                  1, 'VSM', $$a pinch of fine sand, rose petals, or a cricket$$, array['Bard','Sorcerer','Wizard']),
($$Cure Wounds$$,            1, 'VS',  null, array['Bard','Cleric','Druid','Paladin','Ranger']),
($$Identify$$,               1, 'VSM', $$a pearl worth at least 100 gp and an owl feather$$, array['Bard','Wizard']),
($$Grease$$,                 1, 'VSM', $$a bit of pork rind or butter$$, array['Wizard']),
($$Aid$$,                    2, 'VSM', $$a tiny strip of white cloth$$, array['Cleric','Paladin']),
($$Blindness/Deafness$$,     2, 'V',   null, array['Bard','Cleric','Sorcerer','Wizard']),
($$Blur$$,                   2, 'V',   null, array['Sorcerer','Wizard']),
($$Darkness$$,               2, 'VM',  $$bat fur and a drop of pitch or piece of coal$$, array['Sorcerer','Warlock','Wizard']),
($$Enhance Ability$$,        2, 'VSM', $$fur or a feather from a beast$$, array['Bard','Cleric','Druid','Sorcerer']),
($$Heat Metal$$,             2, 'VSM', $$a piece of iron and a flame$$, array['Bard','Druid']),
($$Hold Person$$,            2, 'VSM', $$a small, straight piece of iron$$, array['Bard','Cleric','Druid','Sorcerer','Warlock','Wizard']),
($$Invisibility$$,           2, 'VSM', $$an eyelash encased in gum arabic$$, array['Bard','Sorcerer','Warlock','Wizard']),
($$Magic Weapon$$,           2, 'VS',  null, array['Paladin','Wizard']),
($$Mirror Image$$,           2, 'VS',  null, array['Sorcerer','Warlock','Wizard']),
($$Misty Step$$,             2, 'V',   null, array['Sorcerer','Warlock','Wizard']),
($$Blink$$,                  3, 'VS',  null, array['Sorcerer','Wizard']),
($$Call Lightning$$,         3, 'VS',  null, array['Druid']),
($$Conjure Animals$$,        3, 'VS',  null, array['Druid','Ranger']),
($$Counterspell$$,           3, 'S',   null, array['Sorcerer','Warlock','Wizard']),
($$Daylight$$,               3, 'VS',  null, array['Cleric','Druid','Paladin','Ranger','Sorcerer']),
($$Dispel Magic$$,           3, 'VS',  null, array['Bard','Cleric','Druid','Paladin','Sorcerer','Warlock','Wizard']),
($$Fear$$,                   3, 'VSM', $$a white feather or the heart of a hen$$, array['Bard','Sorcerer','Warlock','Wizard']),
($$Lightning Bolt$$,         3, 'VSM', $$a bit of fur and a rod of amber, crystal, or glass$$, array['Sorcerer','Wizard']),
($$Revivify$$,               3, 'VSM', $$diamonds worth 300 gp, which the spell consumes$$, array['Cleric','Paladin']),
($$Greater Restoration$$,    5, 'VSM', $$diamond dust worth at least 100 gp, which the spell consumes$$, array['Bard','Cleric','Druid']),
($$Telekinesis$$,            5, 'VS',  null, array['Sorcerer','Wizard']),
($$Teleportation Circle$$,   5, 'VM',  $$rare chalks and inks infused with precious gems worth 50 gp, which the spell consumes$$, array['Bard','Sorcerer','Wizard']);

update public.spells s
   set level              = f.level,
       verbal             = position('V' in f.comp) > 0,
       somatic            = position('S' in f.comp) > 0,
       material           = position('M' in f.comp) > 0,
       material_component = f.material_component,
       classes            = f.classes,
       tags = array(
         select case
                  when t ~ '^(cantrip|[0-9](st|nd|rd|th)-level)$' then
                    case f.level
                      when 0 then 'cantrip'
                      when 1 then '1st-level'
                      when 2 then '2nd-level'
                      when 3 then '3rd-level'
                      else f.level || 'th-level'
                    end
                  else t
                end
           from unnest(s.tags) t
       )
  from _fix f
 where s.campaign_id is null
   and s.name = f.name;

do $do$
declare
  v_expected int := (select count(*) from _fix);
  v_found    int;
begin
  select count(*) into v_found
    from _fix f
    join public.spells s
      on s.campaign_id is null
     and s.name = f.name
     and s.level = f.level
     and s.verbal  = (position('V' in f.comp) > 0)
     and s.somatic = (position('S' in f.comp) > 0)
     and s.material = (position('M' in f.comp) > 0)
     and s.material_component is not distinct from f.material_component
     and s.classes = f.classes;
  if v_found <> v_expected then
    raise exception 'spell repair incomplete: % of % rows match', v_found, v_expected;
  end if;
end
$do$;

insert into public.schema_migrations (version) values ('138');

commit;

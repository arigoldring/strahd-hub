-- db/087_class_features_druid.sql
--
-- The Druid's base-class features (levels 1-20) and its two PHB circles:
-- Land and Moon. 18 rows. RUN 086 FIRST (ledger order only).
--
-- RULES EDITION: D&D 5e 2014 (PHB 2014). Not the 2024 revision: the circle
-- is chosen at 2nd level, and Wild Shape is limited by challenge rating.
--
-- 084's shape: one file per class, base + PHB subclass rows. 081's rule: one
-- row per named feature at its first level, later steps in the text (Wild
-- Shape's CR limits, Circle Forms' CR).
--
-- Circle of the Land's terrain is a pick with nowhere to store it (no
-- `choice`, see KNOWN_ISSUES), so Circle Spells lists all eight terrains,
-- and the player notes theirs.
--
-- TEXT: short summaries in our own words, mechanics intact.
--
-- Run by Claude via `npx supabase db query --linked`; in the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class         constant text := 'Druid';
  c_land          constant text := 'Circle of the Land';
  c_moon          constant text := 'Circle of the Moon';
  c_expected_base constant int  := 7;
  c_expected_la   constant int  := 6;
  c_expected_mo   constant int  := 5;

  v_seeking text;

  v_class   uuid;
  v_land    uuid;
  v_moon    uuid;
  v_base    int;
  v_la      int;
  v_mo      int;
  v_choices int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_land;
  select id into strict v_land from public.subclasses
  where class_id = v_class and name = c_land and campaign_id is null;

  v_seeking := 'subclass ' || c_moon;
  select id into strict v_moon from public.subclasses
  where class_id = v_class and name = c_moon and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (null::uuid, 1, 'Druidic',
       'You know Druidic, the secret language of druids. You can speak it and '
       'leave hidden messages in it. Others notice a message only with a DC 15 '
       'Wisdom (Perception) check, and can''t read it without magic.'),
      (null, 1, 'Spellcasting', concat_ws(E'\n',
       'Wisdom is your spellcasting ability. Spell save DC = 8 + proficiency '
       'bonus + Wisdom modifier; spell attack = proficiency bonus + Wisdom '
       'modifier. A druidic focus can be your focus. You can cast a prepared '
       'druid spell as a ritual if it has the ritual tag.',
       '',
       'Cantrips known: 2; 3 at 4th, 4 at 10th.',
       'Prepared spells: Wisdom modifier + druid level (minimum 1), chosen from '
       'the whole druid list after each long rest.',
       '',
       'Spell slots (1st/2nd/.../9th), regained on a long rest:',
       '1: 2 | 2: 3 | 3: 4/2 | 4: 4/3 | 5: 4/3/2 | 6: 4/3/3 | 7: 4/3/3/1 | '
       '8: 4/3/3/2 | 9: 4/3/3/3/1 | 10: 4/3/3/3/2 | 11-12: 4/3/3/3/2/1 | '
       '13-14: +1 7th | 15-16: +1 8th | 17: +1 9th | 18: 5th becomes 3 | '
       '19: 6th becomes 2 | 20: 7th becomes 2')),
      (null, 2, 'Wild Shape', concat_ws(E'\n',
       'Action: turn into a beast you have seen. Twice per short or long rest. '
       'You stay transformed for up to half your druid level in hours (round '
       'down), until you drop to 0 hit points, or until you end it as a bonus '
       'action.',
       '- Beast limits: CR 1/4 with no flying or swimming speed at 2nd; CR 1/2, '
       'no flying, at 4th; CR 1 at 8th.',
       '- You take the beast''s game statistics and hit points, but keep your '
       'alignment, personality, Intelligence, Wisdom and Charisma, and your '
       'skill and save proficiencies (using the better bonus).',
       '- When you revert, extra damage carries over to your normal hit points.',
       '- You can''t cast spells while transformed (concentration continues).',
       '- Your gear merges into the new form, or is worn if it fits (DM''s '
       'call).')),
      (null, 4, 'Ability Score Improvement',
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 18, 'Timeless Body',
       'You age only 1 year for every 10 that pass.'),
      (null, 18, 'Beast Spells',
       'You can cast many druid spells in any Wild Shape form, performing the '
       'verbal and somatic components. Material components still can''t be '
       'provided.'),
      (null, 20, 'Archdruid',
       'You can use Wild Shape any number of times. You also ignore the verbal '
       'and somatic components of druid spells, and material ones with no cost '
       'that aren''t consumed, in both your normal and beast forms.'),

      -- ---- Circle of the Land ---------------------------------------------
      (v_land, 2, 'Bonus Cantrip',
       'You learn one extra druid cantrip.'),
      (v_land, 2, 'Natural Recovery',
       'Once per day, during a short rest, recover expended spell slots whose '
       'levels add up to no more than half your druid level (round up). None '
       'can be 6th level or higher.'),
      (v_land, 3, 'Circle Spells', concat_ws(E'\n',
       'Choose the terrain where you became a druid and note it. Its spells are '
       'always prepared and don''t count against your total. Pairs listed are '
       'gained at 3rd / 5th / 7th / 9th druid level.',
       '- Arctic: hold person, spike growth / sleet storm, slow / freedom of '
       'movement, ice storm / commune with nature, cone of cold.',
       '- Coast: mirror image, misty step / water breathing, water walk / '
       'control water, freedom of movement / conjure elemental, scrying.',
       '- Desert: blur, silence / create food and water, protection from '
       'energy / blight, hallucinatory terrain / insect plague, wall of stone.',
       '- Forest: barkskin, spider climb / call lightning, plant growth / '
       'divination, freedom of movement / commune with nature, tree stride.',
       '- Grassland: invisibility, pass without trace / daylight, haste / '
       'divination, freedom of movement / dream, insect plague.',
       '- Mountain: spider climb, spike growth / lightning bolt, meld into '
       'stone / stone shape, stoneskin / passwall, wall of stone.',
       '- Swamp: darkness, Melf''s acid arrow / water walk, stinking cloud / '
       'freedom of movement, locate creature / insect plague, scrying.',
       '- Underdark: spider climb, web / gaseous form, stinking cloud / greater '
       'invisibility, stone shape / cloudkill, insect plague.')),
      (v_land, 6, 'Land''s Stride',
       'Nonmagical difficult terrain costs you no extra movement, and nonmagical '
       'plants don''t slow or hurt you. Advantage on saves against plants '
       'magically made to impede movement, such as entangle.'),
      (v_land, 10, 'Nature''s Ward',
       'You can''t be charmed or frightened by elementals or fey, and you are '
       'immune to poison and disease.'),
      (v_land, 14, 'Nature''s Sanctuary',
       'A beast or plant creature that attacks you must first make a Wisdom '
       'save against your spell save DC. On a failure it must pick another '
       'target or lose the attack. On a success it is immune for 24 hours.'),

      -- ---- Circle of the Moon ---------------------------------------------
      (v_moon, 2, 'Combat Wild Shape',
       'You can use Wild Shape as a bonus action instead of an action. While '
       'transformed, you can spend a spell slot as a bonus action to regain 1d8 '
       'hit points per slot level.'),
      (v_moon, 2, 'Circle Forms',
       'Wild Shape can turn you into a beast of CR 1 (ignoring the base '
       'feature''s CR limit; flying and swimming limits still apply by level). '
       'From 6th level the maximum CR is your druid level divided by 3, rounded '
       'down.'),
      (v_moon, 6, 'Primal Strike',
       'Your attacks in beast form count as magical for overcoming resistance '
       'and immunity to nonmagical damage.'),
      (v_moon, 10, 'Elemental Wild Shape',
       'You can spend two Wild Shape uses at once to become an air, earth, fire '
       'or water elemental.'),
      (v_moon, 14, 'Thousand Forms',
       'You can cast alter self at will.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) filter (where subclass_id is null),
         count(*) filter (where subclass_id = v_land),
         count(*) filter (where subclass_id = v_moon),
         count(*) filter (where choice is not null)
    into v_base, v_la, v_mo, v_choices
  from public.class_features
  where class_id = v_class and campaign_id is null;

  if v_base <> c_expected_base then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_base, c_expected_base;
  elsif v_la <> c_expected_la then
    raise exception '% has % features (expected %). Rolled back.', c_land, v_la, c_expected_la;
  elsif v_mo <> c_expected_mo then
    raise exception '% has % features (expected %). Rolled back.', c_moon, v_mo, c_expected_mo;
  elsif v_choices <> 0 then
    raise exception '% % features carry a choice (expected 0). Rolled back.',
      v_choices, c_class;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 070 the Druid''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('087');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the rows and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

with f as (
  select s.name as subclass, f.*
    from public.class_features f
    join public.classes c on c.id = f.class_id
    left join public.subclasses s on s.id = f.subclass_id
   where c.name = 'Druid' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 2, 4, 18, 18, 20]::smallint[]
     from f where subclass is null)                                   as base_levels,
  (select count(*) = 6 from f where subclass = 'Circle of the Land')  as land_6,
  (select count(*) = 5 from f where subclass = 'Circle of the Moon')  as moon_5,
  (select count(*) = 0 from f where choice is not null)               as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '087')                                            as ledger_row;

rollback;

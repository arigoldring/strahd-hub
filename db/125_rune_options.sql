-- db/125_rune_options.sql
--
-- The Rune Knight's Rune Carver gets a picker: the 6 Tasha's runes, two at 3rd
-- level and one more at 7th, 10th and 15th. Hill and Storm carry "7th level"
-- as a display-only prerequisite. Texts are 106's, already in our own words.
--
-- 122's shape, one list per file: kind 'rune' joins the CHECK (one list
-- in two places with FEATURE_OPTION_KINDS, which shipped first so the client
-- could parse it), 6 shared options are seeded (6 tcoe),
-- Rune Carver links all of them, and its allowance steps are
-- (3,2) (7,3) (10,4) (15,5). Its text drops the option list, now that each
-- option carries its own. Text in our own words.
--
-- Prerequisites are display only (122's `prerequisite` column): the picker
-- shows them, nothing enforces them.
--
-- Run by Claude via `npx supabase db query --linked`; in the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

alter table public.feature_options drop constraint feature_options_kind_check;
alter table public.feature_options
  add constraint feature_options_kind_check check (kind in (
    'fighting_style', 'maneuver', 'metamagic', 'arcane_shot', 'rune'
  ));

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class    constant text := 'Fighter';
  c_subclass constant text := 'Rune Knight';
  c_feature  constant text := 'Rune Carver';
  c_kind     constant text := 'rune';
  c_expected constant int  := 6;

  v_seeking  text;
  v_class    uuid;
  v_subclass uuid;
  v_feature  uuid;
  v_count    int;
  v_updated  int;
begin
  v_seeking := format('shared class "%s"', c_class);
  select id into strict v_class
    from public.classes where name = c_class and campaign_id is null;

  v_seeking := format('%s subclass "%s"', c_class, c_subclass);
  select id into strict v_subclass
    from public.subclasses
   where class_id = v_class and name = c_subclass and campaign_id is null;

  v_seeking := format('%s feature "%s"', c_class, c_feature);
  select id into strict v_feature
    from public.class_features
   where class_id = v_class and subclass_id = v_subclass
     and name = c_feature and campaign_id is null;

  insert into public.feature_options (kind, key, name, source, prerequisite, description)
  values
    (c_kind, 'cloud', 'Cloud Rune', 'tcoe', null,
     'Advantage on Sleight of Hand and Deception. Reaction: redirect an '
     'attack that hits you or a creature within 30 feet to another '
     'creature within 30 feet, other than the attacker.'),
    (c_kind, 'fire', 'Fire Rune', 'tcoe', null,
     'Double proficiency bonus on tool checks. On a weapon hit, the '
     'target takes an extra 2d6 fire and makes a Strength save or is '
     'restrained for 1 minute, taking 2d6 fire each turn and repeating '
     'the save.'),
    (c_kind, 'frost', 'Frost Rune', 'tcoe', null,
     'Advantage on Animal Handling and Intimidation. Bonus action: +2 to '
     'Strength and Constitution checks and saves for 10 minutes.'),
    (c_kind, 'stone', 'Stone Rune', 'tcoe', null,
     'Advantage on Insight, and darkvision 120 feet. Reaction: a '
     'creature ending its turn within 30 feet makes a Wisdom save or is '
     'charmed for 1 minute, incapacitated with speed 0, repeating the '
     'save each turn.'),
    (c_kind, 'hill', 'Hill Rune', 'tcoe', '7th level',
     'Advantage on saves against poison, and resistance to poison '
     'damage. Bonus action: resistance to bludgeoning, piercing and '
     'slashing for 1 minute.'),
    (c_kind, 'storm', 'Storm Rune', 'tcoe', '7th level',
     'Advantage on Arcana, and you can''t be surprised unless '
     'incapacitated. Bonus action: for 1 minute, use your reaction to '
     'give advantage or disadvantage to an attack, save or check by a '
     'creature within 60 feet.');

  insert into public.class_feature_options (feature_id, option_id)
  select v_feature, o.id
    from public.feature_options o
   where o.kind = c_kind and o.campaign_id is null;

  insert into public.class_feature_picks (feature_id, level, total)
  values (v_feature, 3, 2), (v_feature, 7, 3), (v_feature, 10, 4), (v_feature, 15, 5);

  update public.class_features
     set description = 'Learn two runes (pick them below), and one more at 7th, 10th and '
       '15th level. Inscribe each on a weapon, armor, shield or jewelry '
       'you hold, one rune per object. Each rune''s active effect is once '
       'per short or long rest. Save DC 8 + proficiency bonus + '
       'Constitution modifier.'
   where id = v_feature;
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'Rewrote % % rows (expected 1). Rolled back.', v_updated, c_feature;
  end if;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
    from public.feature_options where kind = c_kind and campaign_id is null;
  if v_count <> c_expected then
    raise exception '% shared % options (expected %). Rolled back.', v_count, c_kind, c_expected;
  end if;

  select count(*) into v_count
    from public.class_feature_options where feature_id = v_feature;
  if v_count <> c_expected then
    raise exception '% links on % (expected %). Rolled back.', v_count, c_feature, c_expected;
  end if;

  if public.feature_picks_allowed(v_feature, 2) <> 0
     or public.feature_picks_allowed(v_feature, 3) <> 2
     or public.feature_picks_allowed(v_feature, 7) <> 3
     or public.feature_picks_allowed(v_feature, 10) <> 4
     or public.feature_picks_allowed(v_feature, 20) <> 5 then
    raise exception '%''s allowance is wrong. Rolled back.', c_feature;
  end if;
exception
  when no_data_found then
    raise exception 'Found no %. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('125');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the options, links, steps and ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

with f as (
  select f.id
    from public.class_features f
    join public.classes c on c.id = f.class_id
    join public.subclasses s on s.id = f.subclass_id
   where c.name = 'Fighter' and c.campaign_id is null
     and f.name = 'Rune Carver' and f.campaign_id is null
     and s.name = 'Rune Knight'
)
select
  (select count(*) = 6 from public.feature_options
    where kind = 'rune' and campaign_id is null)              as options_6,
  (select count(*) = 6 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as links_6,
  (select count(*) = 4 from public.class_feature_picks p
     join f on f.id = p.feature_id)                                   as steps_4,
  (select count(*) = 1 from public.schema_migrations
    where version = '125')                                           as ledger_row;

rollback;

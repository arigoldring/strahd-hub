-- db/123_metamagic_options.sql
--
-- The Sorcerer's Metamagic gets a picker: 8 PHB options and Tasha's 2 (Seeking
-- Spell, Transmuted Spell), labelled Tasha's. Two options at 3rd level, a
-- third at 10th, a fourth at 17th. The costs in brackets are sorcery points.
--
-- 122's shape, one list per file: kind 'metamagic' joins the CHECK (one list
-- in two places with FEATURE_OPTION_KINDS, which shipped first so the client
-- could parse it), 10 shared options are seeded (8 phb, 2 tcoe),
-- Metamagic links all of them, and its allowance steps are
-- (3,2) (10,3) (17,4). Its text drops the option list, now that each
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
    'fighting_style', 'maneuver', 'metamagic'
  ));

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class    constant text := 'Sorcerer';
  c_feature  constant text := 'Metamagic';
  c_kind     constant text := 'metamagic';
  c_expected constant int  := 10;

  v_seeking  text;
  v_class    uuid;
  v_feature  uuid;
  v_count    int;
  v_updated  int;
begin
  v_seeking := format('shared class "%s"', c_class);
  select id into strict v_class
    from public.classes where name = c_class and campaign_id is null;

  v_seeking := format('%s feature "%s"', c_class, c_feature);
  select id into strict v_feature
    from public.class_features
   where class_id = v_class and subclass_id is null
     and name = c_feature and campaign_id is null;

  insert into public.feature_options (kind, key, name, source, prerequisite, description)
  values
    (c_kind, 'careful', 'Careful Spell', 'phb', null,
     '(1 point) Up to your Charisma modifier creatures automatically '
     'succeed on the spell''s save.'),
    (c_kind, 'distant', 'Distant Spell', 'phb', null,
     '(1 point) Double the spell''s range, or make a touch spell reach 30 '
     'feet.'),
    (c_kind, 'empowered', 'Empowered Spell', 'phb', null,
     '(1 point) Reroll up to your Charisma modifier damage dice. Can be '
     'combined with another option.'),
    (c_kind, 'extended', 'Extended Spell', 'phb', null,
     '(1 point) Double a duration of 1 minute or longer, to a maximum of '
     '24 hours.'),
    (c_kind, 'heightened', 'Heightened Spell', 'phb', null,
     '(3 points) One target has disadvantage on its first save against '
     'the spell.'),
    (c_kind, 'quickened', 'Quickened Spell', 'phb', null,
     '(2 points) Cast a spell that takes an action as a bonus action.'),
    (c_kind, 'subtle', 'Subtle Spell', 'phb', null,
     '(1 point) Cast without verbal or somatic components.'),
    (c_kind, 'twinned', 'Twinned Spell', 'phb', null,
     '(Points equal to the spell''s level, 1 for a cantrip) A spell that '
     'targets one creature, and can''t target more, also targets a '
     'second.'),
    (c_kind, 'seeking', 'Seeking Spell', 'tcoe', null,
     '(2 points) When you miss with a spell attack, reroll the d20 and '
     'use the new roll. Usable even if another option is already on the '
     'spell.'),
    (c_kind, 'transmuted', 'Transmuted Spell', 'tcoe', null,
     '(1 point) Change the spell''s acid, cold, fire, lightning, poison '
     'or thunder damage to another of those types.');

  insert into public.class_feature_options (feature_id, option_id)
  select v_feature, o.id
    from public.feature_options o
   where o.kind = c_kind and o.campaign_id is null;

  insert into public.class_feature_picks (feature_id, level, total)
  values (v_feature, 3, 2), (v_feature, 10, 3), (v_feature, 17, 4);

  update public.class_features
     set description = 'Learn two Metamagic options (pick them below), one more at 10th '
       'and 17th level. Only one per spell, unless an option says '
       'otherwise.'
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
     or public.feature_picks_allowed(v_feature, 10) <> 3
     or public.feature_picks_allowed(v_feature, 17) <> 4 then
    raise exception '%''s allowance is wrong. Rolled back.', c_feature;
  end if;
exception
  when no_data_found then
    raise exception 'Found no %. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('123');

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
   where c.name = 'Sorcerer' and c.campaign_id is null
     and f.name = 'Metamagic' and f.campaign_id is null
     and f.subclass_id is null
)
select
  (select count(*) = 10 from public.feature_options
    where kind = 'metamagic' and campaign_id is null)              as options_10,
  (select count(*) = 10 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as links_10,
  (select count(*) = 3 from public.class_feature_picks p
     join f on f.id = p.feature_id)                                   as steps_3,
  (select count(*) = 1 from public.schema_migrations
    where version = '123')                                           as ledger_row;

rollback;

-- db/124_arcane_shot_options.sql
--
-- The Arcane Archer's Arcane Shot gets a picker: the 8 Xanathar's options, two
-- at 3rd level and one more at 7th, 10th, 15th and 18th. Texts are 105's,
-- already in our own words.
--
-- 122's shape, one list per file: kind 'arcane_shot' joins the CHECK (one list
-- in two places with FEATURE_OPTION_KINDS, which shipped first so the client
-- could parse it), 8 shared options are seeded (8 xgte),
-- Arcane Shot links all of them, and its allowance steps are
-- (3,2) (7,3) (10,4) (15,5) (18,6). Its text drops the option list, now that each
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
    'fighting_style', 'maneuver', 'metamagic', 'arcane_shot'
  ));

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class    constant text := 'Fighter';
  c_subclass constant text := 'Arcane Archer';
  c_feature  constant text := 'Arcane Shot';
  c_kind     constant text := 'arcane_shot';
  c_expected constant int  := 8;

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
    (c_kind, 'banishing', 'Banishing Arrow', 'xgte', null,
     'Charisma save or banished to the Feywild until the end of its next '
     'turn. 18th: +2d6 force.'),
    (c_kind, 'beguiling', 'Beguiling Arrow', 'xgte', null,
     '+2d6 psychic, and a Wisdom save or charmed by an ally of your '
     'choice within 30 feet of it until the start of your next turn. '
     '18th: 4d6.'),
    (c_kind, 'bursting', 'Bursting Arrow', 'xgte', null,
     'The target and everything within 10 feet of it take 2d6 force. '
     '18th: 4d6.'),
    (c_kind, 'enfeebling', 'Enfeebling Arrow', 'xgte', null,
     '+2d6 necrotic, and a Constitution save or its weapon attacks deal '
     'half damage until the start of your next turn. 18th: 4d6.'),
    (c_kind, 'grasping', 'Grasping Arrow', 'xgte', null,
     '+2d6 poison, its speed drops by 10 feet, and it takes 2d6 slashing '
     'the first time each turn it moves, for 1 minute or until an '
     'Athletics check against your DC pulls the brambles off. 18th: 4d6 '
     'each.'),
    (c_kind, 'piercing', 'Piercing Arrow', 'xgte', null,
     'No attack roll. The arrow passes through a 30-foot line; each '
     'creature in it makes a Dexterity save or takes the arrow''s damage '
     '+ 1d6 piercing, half on a success. 18th: 2d6.'),
    (c_kind, 'seeking', 'Seeking Arrow', 'xgte', null,
     'No attack roll. Aim at a creature you''ve seen in the past minute; '
     'it makes a Dexterity save or takes the arrow''s damage + 1d6 force '
     'and you learn where it is, half and no location on a success. '
     '18th: 2d6.'),
    (c_kind, 'shadow', 'Shadow Arrow', 'xgte', null,
     '+2d6 psychic, and a Wisdom save or it can''t see past 5 feet until '
     'the start of your next turn. 18th: 4d6.');

  insert into public.class_feature_options (feature_id, option_id)
  select v_feature, o.id
    from public.feature_options o
   where o.kind = c_kind and o.campaign_id is null;

  insert into public.class_feature_picks (feature_id, level, total)
  values (v_feature, 3, 2), (v_feature, 7, 3), (v_feature, 10, 4), (v_feature, 15, 5), (v_feature, 18, 6);

  update public.class_features
     set description = 'Once per turn, when you fire a magic arrow from a shortbow or '
       'longbow as part of the Attack action, you can apply one Arcane '
       'Shot option, deciding when the arrow hits unless the option has no '
       'attack roll. Two uses per short or long rest. Save DC 8 + '
       'proficiency bonus + Intelligence modifier. You know two options '
       '(pick them below), and learn another at 7th, 10th, 15th and 18th '
       'level. At 18th, each option''s damage grows as noted.'
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
     or public.feature_picks_allowed(v_feature, 15) <> 5
     or public.feature_picks_allowed(v_feature, 20) <> 6 then
    raise exception '%''s allowance is wrong. Rolled back.', c_feature;
  end if;
exception
  when no_data_found then
    raise exception 'Found no %. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('124');

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
     and f.name = 'Arcane Shot' and f.campaign_id is null
     and s.name = 'Arcane Archer'
)
select
  (select count(*) = 8 from public.feature_options
    where kind = 'arcane_shot' and campaign_id is null)              as options_8,
  (select count(*) = 8 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as links_8,
  (select count(*) = 5 from public.class_feature_picks p
     join f on f.id = p.feature_id)                                   as steps_5,
  (select count(*) = 1 from public.schema_migrations
    where version = '124')                                           as ledger_row;

rollback;

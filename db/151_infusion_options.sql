-- db/151_infusion_options.sql
--
-- The Artificer's Infuse Item gets a picker: Tasha's sixteen infusions.
-- Four known at 2nd level, rising to twelve at 18th. RUN 150 FIRST: it
-- seeds the Infuse Item row this file links to, already worded for a
-- picker.
--
-- 122's shape, one list per file (126 is the nearest copy): kind 'infusion'
-- joins the CHECK, which is one list in two places with
-- FEATURE_OPTION_KINDS in src/services/classes.ts. THAT SHIPPED FIRST:
-- toFeatureOption throws on a kind it doesn't know, and every sheet loads
-- every option. 16 shared options are seeded, all 'tcoe', Infuse Item links
-- all of them, and its allowance steps are (2,4) (6,6) (10,8) (14,10)
-- (18,12). Unlike 126, there is no description rewrite: 150 wrote the
-- final text.
--
-- The item an infusion goes on (and whether it needs attunement) leads the
-- description, because feature_options has no column for it, and a column
-- would serve this one kind.
--
-- Prerequisites are display only (122's `prerequisite` column): the picker
-- shows "6th level", nothing stops a 2nd-level artificer picking Radiant
-- Weapon.
--
-- REPLICATE MAGIC ITEM can be learned more than once in the book, a
-- different item each time. `unique (character_id, option_id)` (095) allows
-- it once (KNOWN_ISSUES). Its row says which item tables it reaches by
-- level; the tables themselves are referenced, not reproduced.
--
-- In the SQL editor, decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

alter table public.feature_options drop constraint feature_options_kind_check;
alter table public.feature_options
  add constraint feature_options_kind_check check (kind in (
    'fighting_style', 'maneuver', 'metamagic', 'arcane_shot', 'rune',
    'invocation', 'infusion'
  ));

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class    constant text := 'Artificer';
  c_feature  constant text := 'Infuse Item';
  c_kind     constant text := 'infusion';
  c_expected constant int  := 16;

  v_seeking  text;
  v_class    uuid;
  v_feature  uuid;
  v_count    int;
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
    (c_kind, 'arcane_propulsion_armor', 'Arcane Propulsion Armor', 'tcoe', '14th level',
     'Armour (attunement). +5 feet walking speed. Its gauntlets are magic '
     'melee weapons you''re proficient with, usable only with an empty '
     'hand: 1d8 force, thrown 20/60 feet, and they fly back after a '
     'throw. The armour can''t be removed against your will, and it '
     'replaces any missing limbs.'),
    (c_kind, 'armor_of_magical_strength', 'Armor of Magical Strength', 'tcoe', null,
     'Armour (attunement). 6 charges, regaining 1d6 at dawn. Spend one to '
     'add your Intelligence modifier to a Strength check or save, or as a '
     'reaction to avoid being knocked prone.'),
    (c_kind, 'boots_of_the_winding_path', 'Boots of the Winding Path', 'tcoe', '6th level',
     'Boots (attunement). Bonus action: teleport up to 15 feet to an '
     'unoccupied space you can see that you occupied earlier this turn.'),
    (c_kind, 'enhanced_arcane_focus', 'Enhanced Arcane Focus', 'tcoe', null,
     'Rod, staff or wand (attunement). +1 to spell attack rolls, +2 at '
     '10th level, and your spell attacks ignore half cover.'),
    (c_kind, 'enhanced_defense', 'Enhanced Defense', 'tcoe', null,
     'Armour or a shield. +1 AC, +2 at 10th level.'),
    (c_kind, 'enhanced_weapon', 'Enhanced Weapon', 'tcoe', null,
     'A simple or martial weapon. +1 to attack and damage rolls, +2 at '
     '10th level.'),
    (c_kind, 'helm_of_awareness', 'Helm of Awareness', 'tcoe', '10th level',
     'Helmet (attunement). Advantage on initiative rolls, and you can''t '
     'be surprised unless incapacitated.'),
    (c_kind, 'homunculus_servant', 'Homunculus Servant', 'tcoe', null,
     'A gem or crystal worth at least 100 gp. It becomes a Tiny construct '
     'that obeys you and acts after you: hit points 1 + your Intelligence '
     'modifier + your artificer level, flying speed 30 feet, evasion. '
     'Force Strike: ranged spell attack using your modifier, 1d4 + your '
     'proficiency bonus force. It can deliver your touch spells.'),
    (c_kind, 'mind_sharpener', 'Mind Sharpener', 'tcoe', null,
     'Armour or robes (attunement). 4 charges, regaining 1d4 at dawn. '
     'Reaction: when you fail a Constitution save to keep concentration, '
     'spend one to succeed instead.'),
    (c_kind, 'radiant_weapon', 'Radiant Weapon', 'tcoe', '6th level',
     'A simple or martial weapon (attunement). +1 to attack and damage '
     'rolls. Bonus action: it sheds bright light 30 feet and dim light 30 '
     'more, or stops. 4 charges, regaining 1d4 at dawn; reaction when an '
     'attacker you can see within 30 feet hits you: spend one, and it '
     'makes a Constitution save against your spell DC or is blinded until '
     'the end of its next turn.'),
    (c_kind, 'repeating_shot', 'Repeating Shot', 'tcoe', null,
     'A simple or martial weapon with the ammunition property (attunement). '
     '+1 to attack and damage rolls on ranged attacks with it. It ignores '
     'the loading property, and makes its own ammunition if none is '
     'loaded.'),
    (c_kind, 'replicate_magic_item', 'Replicate Magic Item', 'tcoe', null,
     'Learn the plans for one magic item from Tasha''s replicable-item '
     'tables: the 2nd-level table now, and the 6th-, 10th- and 14th-level '
     'tables once you reach those levels. Infusing it creates that item. '
     'The book lets you take this more than once, a different item each '
     'time; the sheet allows it once (KNOWN_ISSUES).'),
    (c_kind, 'repulsion_shield', 'Repulsion Shield', 'tcoe', '6th level',
     'Shield (attunement). +1 AC. 4 charges, regaining 1d4 at dawn; '
     'reaction when a melee attack hits you: spend one to push the '
     'attacker up to 15 feet away.'),
    (c_kind, 'resistant_armor', 'Resistant Armor', 'tcoe', '6th level',
     'Armour (attunement). Resistance to one damage type you choose when '
     'you infuse it: acid, cold, fire, force, lightning, necrotic, poison, '
     'psychic, radiant or thunder.'),
    (c_kind, 'returning_weapon', 'Returning Weapon', 'tcoe', null,
     'A simple or martial weapon with the thrown property. +1 to attack '
     'and damage rolls, and it flies back to your hand right after a '
     'thrown attack.'),
    (c_kind, 'spell_refueling_ring', 'Spell-Refueling Ring', 'tcoe', '6th level',
     'Ring (attunement). Action: recover one expended spell slot of 3rd '
     'level or lower. Once per dawn.');

  insert into public.class_feature_options (feature_id, option_id)
  select v_feature, o.id
    from public.feature_options o
   where o.kind = c_kind and o.campaign_id is null;

  insert into public.class_feature_picks (feature_id, level, total)
  values (v_feature, 2, 4), (v_feature, 6, 6), (v_feature, 10, 8),
         (v_feature, 14, 10), (v_feature, 18, 12);

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

  if public.feature_picks_allowed(v_feature, 1) <> 0
     or public.feature_picks_allowed(v_feature, 2) <> 4
     or public.feature_picks_allowed(v_feature, 5) <> 4
     or public.feature_picks_allowed(v_feature, 6) <> 6
     or public.feature_picks_allowed(v_feature, 13) <> 8
     or public.feature_picks_allowed(v_feature, 20) <> 12 then
    raise exception '%''s allowance is wrong. Rolled back.', c_feature;
  end if;
exception
  when no_data_found then
    raise exception 'Found no %. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('151');

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
   where c.name = 'Artificer' and c.campaign_id is null
     and f.name = 'Infuse Item' and f.campaign_id is null
     and f.subclass_id is null
)
select
  (select count(*) = 16 from public.feature_options
    where kind = 'infusion' and campaign_id is null)                as options_16,
  (select count(*) = 16 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as links_16,
  (select count(*) = 5 from public.class_feature_picks p
     join f on f.id = p.feature_id)                                   as steps_5,
  (select count(*) = 1 from public.schema_migrations
    where version = '151')                                           as ledger_row;

rollback;

-- db/105_class_features_xgte_fighter.sql
--
-- The Fighter's three Xanathar's archetypes: Arcane Archer, Cavalier and
-- Samurai. 18 rows, all subclass features (the base class is 081's).
--
-- Picks the player notes by hand: Arcane Shot options (two at 3rd, one more at
-- 7th, 10th, 15th and 18th) are a many-pick feature, the case KNOWN_ISSUES
-- says needs a picks-count table; all eight are listed in the row. Single
-- picks: Arcane Archer Lore's skill and cantrip, and the Cavalier's and
-- Samurai's Bonus Proficiency.
--
-- RULES EDITION: D&D 5e 2014 (Xanathar's Guide to Everything, 2014-era). Not the 2024
-- revision.
--
-- 084-094's shape, one file per book per class (CLAUDE.md): each subclass is
-- resolved once with `into strict`, one row per named feature at the level
-- it first arrives, later steps in its text. The subclasses themselves were
-- seeded by 071.
--
-- TEXT: every row is a short summary in our own words, mechanics intact, not
-- the book's wording. Tables are referenced, not reproduced.
--
-- NO PICKERS: no row here is linked to a feature option (095). The end-state
-- check counts class_feature_options links on these subclasses' features and
-- requires zero. Display only, like every feature row (KNOWN_ISSUES).
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
  c_class constant text := 'Fighter';
  c_arcane_archer        constant text := 'Arcane Archer';
  c_cavalier             constant text := 'Cavalier';
  c_samurai              constant text := 'Samurai';
  c_arcane_archer_n      constant int  := 5;
  c_cavalier_n           constant int  := 7;
  c_samurai_n            constant int  := 6;

  v_seeking text;
  v_class   uuid;
  v_arcane_archer        uuid;
  v_cavalier             uuid;
  v_samurai              uuid;
  v_count   int;
  v_links   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_arcane_archer;
  select id into strict v_arcane_archer
  from public.subclasses
  where class_id = v_class and name = c_arcane_archer and campaign_id is null;

  v_seeking := 'subclass ' || c_cavalier;
  select id into strict v_cavalier
  from public.subclasses
  where class_id = v_class and name = c_cavalier and campaign_id is null;

  v_seeking := 'subclass ' || c_samurai;
  select id into strict v_samurai
  from public.subclasses
  where class_id = v_class and name = c_samurai and campaign_id is null;

  insert into public.class_features (class_id, subclass_id, level, name, description)
  select v_class, v.subclass_id, v.level, v.name, v.description
  from (values
      -- ---- Arcane Archer -----------------------------------------------------
      -- The first row's cast is what types the column as uuid.
      (v_arcane_archer::uuid, 3, 'Arcane Archer Lore',
       'Proficiency in Arcana or Nature, and you learn prestidigitation or '
       'druidcraft (note your picks).'),
      (v_arcane_archer, 3, 'Arcane Shot',
       concat_ws(E'\n',
       'Once per turn, when you fire a magic arrow from a shortbow or '
       'longbow as part of the Attack action, you can apply one Arcane Shot '
       'option, deciding when the arrow hits unless the option has no attack '
       'roll. Two uses per short or long rest. Save DC 8 + proficiency bonus '
       '+ Intelligence modifier. You know two options, and learn another at '
       '7th, 10th, 15th and 18th level. At 18th, each option''s damage grows '
       'as noted (note your options):',
       '- Banishing Arrow: Charisma save or banished to the Feywild until '
       'the end of its next turn. 18th: +2d6 force.',
       '- Beguiling Arrow: +2d6 psychic, and a Wisdom save or charmed by an '
       'ally of your choice within 30 feet of it until the start of your '
       'next turn. 18th: 4d6.',
       '- Bursting Arrow: the target and everything within 10 feet of it '
       'take 2d6 force. 18th: 4d6.',
       '- Enfeebling Arrow: +2d6 necrotic, and a Constitution save or its '
       'weapon attacks deal half damage until the start of your next turn. '
       '18th: 4d6.',
       '- Grasping Arrow: +2d6 poison, its speed drops by 10 feet, and it '
       'takes 2d6 slashing the first time each turn it moves, for 1 minute '
       'or until an Athletics check against your DC pulls the brambles off. '
       '18th: 4d6 each.',
       '- Piercing Arrow: no attack roll. The arrow passes through a 30-foot '
       'line; each creature in it makes a Dexterity save or takes the '
       'arrow''s damage + 1d6 piercing, half on a success. 18th: 2d6.',
       '- Seeking Arrow: no attack roll. Aim at a creature you''ve seen in '
       'the past minute; it makes a Dexterity save or takes the arrow''s '
       'damage + 1d6 force and you learn where it is, half and no location '
       'on a success. 18th: 2d6.',
       '- Shadow Arrow: +2d6 psychic, and a Wisdom save or it can''t see past '
       '5 feet until the start of your next turn. 18th: 4d6.')),
      (v_arcane_archer, 7, 'Curving Shot',
       'Bonus action: when you miss with a magic arrow, reroll the attack '
       'against a different target within 60 feet of the first.'),
      (v_arcane_archer, 7, 'Magic Arrow',
       'Any nonmagical arrow you fire from a shortbow or longbow counts as '
       'magical for overcoming resistance and immunity, until it hits or '
       'misses.'),
      (v_arcane_archer, 15, 'Ever-Ready Shot',
       'When you roll initiative with no Arcane Shot uses left, you regain '
       'one.'),
      -- ---- Cavalier ----------------------------------------------------------
      (v_cavalier, 3, 'Bonus Proficiency',
       'Proficiency in one of Animal Handling, History, Insight, Performance '
       'or Persuasion, or one language (note your pick).'),
      (v_cavalier, 3, 'Born to the Saddle',
       'Advantage on saves against falling off your mount. Falling 10 feet '
       'or less from it, you land on your feet unless incapacitated. '
       'Mounting or dismounting costs only 5 feet of movement.'),
      (v_cavalier, 3, 'Unwavering Mark',
       'When you hit a creature with a melee weapon, it is marked until the '
       'end of your next turn. While within 5 feet of you, it has '
       'disadvantage on attacks against anyone else. If it damages anyone '
       'else, you can make a bonus action melee attack against it on your '
       'next turn, with advantage and extra damage equal to half your '
       'fighter level. Bonus attacks equal to your Strength modifier '
       '(minimum 1) per long rest.'),
      (v_cavalier, 7, 'Warding Maneuver',
       'Reaction, while holding a melee weapon or shield: when you or a '
       'creature within 5 feet is hit, add a d8 to the target''s AC against '
       'that attack. If it still hits, the target has resistance to its '
       'damage. Uses equal to your Constitution modifier (minimum 1) per '
       'long rest.'),
      (v_cavalier, 10, 'Hold the Line',
       'Creatures provoke an opportunity attack from you when they move 5 '
       'feet or more within your reach, and a hit drops the target''s speed '
       'to 0 for the rest of the turn.'),
      (v_cavalier, 15, 'Ferocious Charger',
       'Once per turn, if you move at least 10 feet in a straight line right '
       'before hitting a creature, it makes a Strength save (DC 8 + '
       'proficiency bonus + Strength modifier) or is knocked prone.'),
      (v_cavalier, 18, 'Vigilant Defender',
       'On every creature''s turn but your own, you have a special reaction '
       'for an opportunity attack. You can''t use it on a turn you''ve used '
       'your normal reaction.'),
      -- ---- Samurai -----------------------------------------------------------
      (v_samurai, 3, 'Bonus Proficiency',
       'Proficiency in one of History, Insight, Performance or Persuasion, '
       'or one language (note your pick).'),
      (v_samurai, 3, 'Fighting Spirit',
       'Bonus action: advantage on weapon attacks until the end of the turn, '
       'and 5 temporary hit points (10 at 10th level, 15 at 15th). Three '
       'uses per long rest.'),
      (v_samurai, 7, 'Elegant Courtier',
       'Add your Wisdom modifier to Charisma (Persuasion) checks. Gain '
       'proficiency in Wisdom saves, or in Intelligence or Charisma saves if '
       'you already have it (note your pick).'),
      (v_samurai, 10, 'Tireless Spirit',
       'When you roll initiative with no Fighting Spirit uses left, you '
       'regain one.'),
      (v_samurai, 15, 'Rapid Strike',
       'Once per turn, when you take the Attack action and have advantage on '
       'an attack, you can give up the advantage on that roll to make an '
       'extra weapon attack against the same target.'),
      (v_samurai, 18, 'Strength before Death',
       'When damage drops you to 0 hit points without killing you, use your '
       'reaction to take an extra turn at once. Damage during it causes '
       'death save failures as normal. If you are still at 0 hit points when '
       'it ends, you fall unconscious. Once per long rest.')
  ) as v(subclass_id, level, name, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_arcane_archer and campaign_id is null;
  if v_count <> c_arcane_archer_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_arcane_archer, v_count, c_arcane_archer_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_cavalier and campaign_id is null;
  if v_count <> c_cavalier_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_cavalier, v_count, c_cavalier_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_samurai and campaign_id is null;
  if v_count <> c_samurai_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_samurai, v_count, c_samurai_n;
  end if;

  select count(*) into v_links
  from public.class_feature_options l
  join public.class_features f on f.id = l.feature_id
  where f.subclass_id in (v_arcane_archer, v_cavalier, v_samurai);
  if v_links <> 0 then
    raise exception '% option links on these features (expected 0). Rolled back.', v_links;
  end if;
exception
  when no_data_found then
    raise exception
      'No shared % found. 055 seeds classes, 071 the Fighter''s subclasses.',
      v_seeking;
  when too_many_rows then
    raise exception
      'More than one shared % found. Resolve the duplicate before seeding.',
      v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('105');

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
    join public.subclasses s on s.id = f.subclass_id
   where c.name = 'Fighter' and c.campaign_id is null
     and f.campaign_id is null
     and s.name in ('Arcane Archer', 'Cavalier', 'Samurai')
)
select
  (select array_agg(level order by level, name)
          = array[3, 3, 7, 7, 15]::smallint[]
     from f where subclass = 'Arcane Archer')                 as arcane_archer_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 7, 10, 15, 18]::smallint[]
     from f where subclass = 'Cavalier')                      as cavalier_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 7, 10, 15, 18]::smallint[]
     from f where subclass = 'Samurai')                       as samurai_levels,
  (select count(*) = 0 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as no_pickers,
  (select count(*) = 1 from public.schema_migrations
    where version = '105')                                            as ledger_row;

rollback;

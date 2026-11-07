-- db/150_class_features_artificer.sql
--
-- The Artificer's base-class features (levels 1-20) and Battle Smith's. 20
-- rows: 13 base, 7 Battle Smith. RUN 149 FIRST: it seeds the class and the
-- subclass this file resolves.
--
-- RULES EDITION: D&D 5e 2014-era (Tasha's Cauldron of Everything). Not the
-- 2024 revision, and not Eberron: Rising from the Last War's earlier draft.
--
-- ONE FILE, NOT TWO. 084-094 hold a PHB class's base rows and its PHB
-- subclasses together; 097-120 add a file per later book. The Artificer is
-- all one book, so its base rows and its one seeded subclass sit together,
-- 084's shape. A later Alchemist, Armorer or Artillerist file is 098's
-- shape (subclass rows only), and must not repeat the base rows here.
--
-- A NEW EFFECT KEY, battle_ready. The CHECK on class_features.effect is
-- rebuilt with it, the way 122-126 rebuild feature_options' kind CHECK.
-- FEATURE_EFFECTS in src/data/rules.ts is the other half of that list and
-- SHIPPED FIRST: toClassFeature throws on an unknown key, which would fail
-- every sheet's load. Its maths is `weaponTraining` (martial weapons) and
-- `battleReadyAbility` (INT on a magic weapon), both tested in
-- rules.test.ts. Battle Smith's Extra Attack carries the existing
-- extra_attack key; 121's rule takes the better of two sources, so a
-- Fighter/Battle Smith multiclass doesn't get a third attack from it.
--
-- KNOWN GAP (KNOWN_ISSUES): "magic weapon" is `items.rarity is not null`,
-- and every seeded magic item is kind 'general' (130-137), so no seeded
-- magic weapon is ever on the attack table. The INT swap only reaches a
-- homebrew weapon-kind item with a rarity. The martial half works always.
--
-- Spellcasting is one row with the slot table as text: half caster, rounded
-- UP, so slots start at 1st level (unlike Paladin and Ranger). Battle Smith
-- Spells is its own row at 3rd, the domain-spells rule (CLAUDE.md).
--
-- Infuse Item's text points at the picker 151 adds; it doesn't list the
-- sixteen infusions, because each option carries its own text.
--
-- Ability Score Improvement is one row at 4th with the later levels in the
-- text (081's rule), as in every other class file.
--
-- Steel Defender's stat block is summarised in its row, not tabled.
--
-- TEXT: short summaries in our own words, mechanics intact.
--
-- In the SQL editor, decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

alter table public.class_features drop constraint class_features_effect_check;
alter table public.class_features
  add constraint class_features_effect_check check (effect in (
    'extra_attack', 'extra_attack_fighter', 'improved_critical',
    'superior_critical', 'sneak_attack', 'martial_arts',
    'jack_of_all_trades', 'remarkable_athlete', 'dread_ambusher',
    'tactical_wit', 'rakish_audacity', 'aura_of_protection',
    'fast_movement', 'unarmored_movement', 'draconic_resilience',
    'battle_ready'
  ));

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class      constant text := 'Artificer';
  c_smith      constant text := 'Battle Smith';
  c_base_n     constant int  := 13;
  c_smith_n    constant int  := 7;

  v_seeking text;
  v_class   uuid;
  v_smith   uuid;
  v_count   int;
begin
  v_seeking := 'class ' || c_class;
  select id into strict v_class
  from public.classes
  where name = c_class and campaign_id is null;

  v_seeking := 'subclass ' || c_smith;
  select id into strict v_smith
  from public.subclasses
  where class_id = v_class and name = c_smith and campaign_id is null;

  insert into public.class_features
    (class_id, subclass_id, level, name, effect, description)
  select v_class, v.subclass_id, v.level, v.name, v.effect, v.description
  from (values
      -- ---- Base class -----------------------------------------------------
      -- The first row's casts are what type the uuid and text columns.
      (null::uuid, 1, 'Magical Tinkering', null::text,
       'Action, with thieves'' tools or artisan''s tools in hand: touch a '
       'Tiny nonmagical object and give it one property: it sheds bright '
       'light 5 feet and dim light 5 more; it plays a recorded message of up '
       'to 6 seconds when tapped; it gives off a constant smell or '
       'nonverbal sound; or it shows a still image or up to 25 words of text '
       'on one surface. You can keep up to your Intelligence modifier '
       '(minimum 1) objects this way, and end one as an action.'),
      (null, 1, 'Spellcasting', null, concat_ws(E'\n',
       'Intelligence is your spellcasting ability. Spell save DC = 8 + '
       'proficiency bonus + Intelligence modifier; spell attack = '
       'proficiency bonus + Intelligence modifier. You must hold a focus to '
       'cast: thieves'' tools, artisan''s tools you''re proficient with, or '
       'an item you have infused. Ritual casting for prepared ritual spells.',
       '',
       'Cantrips known: 2, 3 at 10th, 4 at 14th. Prepared spells: '
       'Intelligence modifier + half your artificer level (round down, '
       'minimum 1), chosen from the artificer list after each long rest.',
       '',
       'Spell slots (1st/.../5th), regained on a long rest:',
       '1-2: 2 | 3-4: 3 | 5-6: 4/2 | 7-8: 4/3 | 9-10: 4/3/2 | 11-12: 4/3/3 | '
       '13-14: 4/3/3/1 | 15-16: 4/3/3/2 | 17-18: 4/3/3/3/1 | 19-20: 4/3/3/3/2')),
      (null, 2, 'Infuse Item', null, concat_ws(E'\n',
       'Learn four infusions (pick them below); 6 at 6th, 8 at 10th, 10 at '
       '14th, 12 at 18th. On each artificer level you may swap one.',
       '',
       'After a long rest, touch a nonmagical object and infuse it with one '
       'infusion you know, making it a magic item. An object holds one '
       'infusion, and you can''t have the same infusion on two objects. '
       'Infused items at once: 2, 3 at 6th, 4 at 10th, 5 at 14th, 6 at '
       '18th; infusing past the limit ends the oldest. An infusion lasts '
       'until you end it, or until 4 days after you die.')),
      (null, 3, 'Artificer Specialist', null,
       'Choose your specialty. It grants features at 3rd, 5th, 9th and 15th '
       'level.'),
      (null, 3, 'The Right Tool for the Job', null,
       'With thieves'' tools or artisan''s tools in hand, spend 1 hour '
       '(which can be part of a rest) to create one set of artisan''s tools '
       'within 5 feet. It lasts until you use this feature again.'),
      (null, 4, 'Ability Score Improvement', null,
       'At 4th, 8th, 12th, 16th and 19th level: +2 to one ability score or +1 '
       'to two (maximum 20), or a feat if your DM allows them.'),
      (null, 6, 'Tool Expertise', null,
       'Your proficiency bonus is doubled for any ability check that uses a '
       'tool you are proficient with.'),
      (null, 7, 'Flash of Genius', null,
       'Reaction: when you or a creature you can see within 30 feet makes an '
       'ability check or saving throw, add your Intelligence modifier to the '
       'roll. Uses equal to your Intelligence modifier (minimum 1) per long '
       'rest.'),
      (null, 10, 'Magic Item Adept', null,
       'You can attune to up to four magic items at once. Crafting a common '
       'or uncommon magic item takes you a quarter of the normal time and '
       'half the gold.'),
      (null, 11, 'Spell-Storing Item', null,
       'After a long rest, touch a simple or martial weapon or an item you '
       'can use as a spellcasting focus, and store in it a 1st- or 2nd-level '
       'artificer spell with a casting time of 1 action (it needn''t be '
       'prepared). While holding it, any creature can use an action to '
       'produce the spell''s effect, using your spellcasting modifier. Uses: '
       'twice your Intelligence modifier (minimum 2), or until you store a '
       'new spell.'),
      (null, 14, 'Magic Item Savant', null,
       'You can attune to up to five magic items at once, and you ignore all '
       'class, race, spell and level requirements on attuning to or using a '
       'magic item.'),
      (null, 18, 'Magic Item Master', null,
       'You can attune to up to six magic items at once.'),
      (null, 20, 'Soul of Artifice', null,
       '+1 to all saving throws for each magic item you are attuned to. When '
       'you drop to 0 hit points but aren''t killed outright, you can use '
       'your reaction to end one of your infusions and drop to 1 hit point '
       'instead.'),
      -- ---- Battle Smith -----------------------------------------------------
      (v_smith, 3, 'Tool Proficiency', null,
       'You gain proficiency with smith''s tools, or with another type of '
       'artisan''s tools if you already have it.'),
      (v_smith, 3, 'Battle Smith Spells', null, concat_ws(E'\n',
       'Always prepared, and not counted against your prepared spells:',
       '3rd: heroism, shield | 5th: branding smite, warding bond | 9th: aura '
       'of vitality, conjure barrage | 13th: aura of purity, fire shield | '
       '17th: banishing smite, mass cure wounds')),
      (v_smith, 3, 'Battle Ready', 'battle_ready',
       'You gain proficiency with martial weapons. When you attack with a '
       'magic weapon, you can use your Intelligence modifier instead of '
       'Strength or Dexterity for the attack and damage rolls.'),
      (v_smith, 3, 'Steel Defender', null, concat_ws(E'\n',
       'You build a Medium construct companion that is friendly to you and '
       'your allies and obeys you. AC 15; hit points 2 + your Intelligence '
       'modifier + five times your artificer level; speed 40 feet; '
       'proficient in Dexterity and Constitution saves, Athletics and '
       'Perception (doubled); immune to poison damage and to the charmed, '
       'exhausted and poisoned conditions. It uses your proficiency bonus.',
       '',
       'It acts on your initiative, right after you. It moves and reacts on '
       'its own, but only takes the Dodge action unless you spend a bonus '
       'action to command it (any action in its stat block, or another '
       'action). If you are incapacitated it acts freely.',
       '',
       '- Force-Empowered Rend: melee attack using your spell attack '
       'modifier, reach 5 feet, 1d8 + your proficiency bonus force damage.',
       '- Repair (3 per day): action, restore 2d8 + your proficiency bonus '
       'hit points to itself or a construct or object within 5 feet.',
       '- Deflect Attack: reaction, give disadvantage to an attack it can '
       'see against a creature within 5 feet of it other than itself.',
       '',
       'If it died within the last hour, an action with smith''s tools and a '
       'spell slot brings it back after 1 minute at full hit points. After a '
       'long rest you can build a new one with smith''s tools; the old one '
       'perishes.')),
      (v_smith, 5, 'Extra Attack', 'extra_attack',
       'You attack twice when you take the Attack action on your turn.'),
      (v_smith, 9, 'Arcane Jolt', null,
       'Once per turn, when you hit with a magic weapon or your steel '
       'defender hits with Force-Empowered Rend, pick one: the target takes '
       'an extra 2d6 force damage, or a creature or object you can see '
       'within 30 feet of the target regains 2d6 hit points. Uses equal to '
       'your Intelligence modifier (minimum 1) per long rest.'),
      (v_smith, 15, 'Improved Defender', null,
       'Arcane Jolt''s damage and healing become 4d6. Your steel defender '
       'gains +2 AC, and whenever it uses Deflect Attack, the attacker takes '
       'force damage equal to 1d4 + your Intelligence modifier.')
  ) as v(subclass_id, level, name, effect, description);

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id is null and campaign_id is null;
  if v_count <> c_base_n then
    raise exception '% has % shared base features (expected %). Rolled back.',
      c_class, v_count, c_base_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_smith and campaign_id is null;
  if v_count <> c_smith_n then
    raise exception '% has % shared features (expected %). Rolled back.',
      c_smith, v_count, c_smith_n;
  end if;

  select count(*) into v_count
  from public.class_features
  where class_id = v_class and subclass_id = v_smith and campaign_id is null
    and ((name = 'Battle Ready' and effect = 'battle_ready')
      or (name = 'Extra Attack' and effect = 'extra_attack'));
  if v_count <> 2 then
    raise exception '% of 2 Battle Smith effect keys in place. Rolled back.', v_count;
  end if;
exception
  when no_data_found then
    raise exception 'No shared % found. 149 seeds the Artificer and Battle Smith.', v_seeking;
  when too_many_rows then
    raise exception 'More than one shared % found. Resolve the duplicate before seeding.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('150');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the rows, the effects and the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

with f as (
  select f.*
    from public.class_features f
    join public.classes c on c.id = f.class_id
   where c.name = 'Artificer' and c.campaign_id is null
     and f.campaign_id is null
)
select
  (select array_agg(level order by level, name)
          = array[1, 1, 2, 3, 3, 4, 6, 7, 10, 11, 14, 18, 20]::smallint[]
     from f where subclass_id is null)                                as base_levels,
  (select array_agg(level order by level, name)
          = array[3, 3, 3, 3, 5, 9, 15]::smallint[]
     from f where subclass_id is not null)                            as smith_levels,
  (select array_agg(effect order by effect)
          = array['battle_ready', 'extra_attack']
     from f where effect is not null)                                 as effects,
  (select count(*) = 23 from public.class_features
    where effect is not null and campaign_id is null)                 as twenty_three_keyed,
  (select count(*) = 1 from public.schema_migrations
    where version = '150')                                            as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the rebuilt CHECK still refuses an unknown key
-- ---------------------------------------------------------------------------
--
-- 039's shape: the refusal is caught and reported as a row.
-- CORRECT OUTPUT: one row, result 'refused (23514)'.

begin;

do $$
begin
  update public.class_features set effect = 'not_an_effect'
   where id = (select id from public.class_features limit 1);
  perform set_config('verification.unknown_effect', 'ACCEPTED', true);
exception when check_violation then
  perform set_config('verification.unknown_effect', 'refused (23514)', true);
end
$$;

select 'an unknown effect key' as check,
       current_setting('verification.unknown_effect') as result;

rollback;

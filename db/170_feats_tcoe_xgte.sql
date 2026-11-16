-- db/170_feats_tcoe_xgte.sql
--
-- Thirty feats added to the shared catalogue: Tasha's Cauldron of Everything's
-- fifteen and Xanathar's Guide to Everything's fifteen racial feats. 040
-- seeded the 2014 PHB's forty-two and nothing has added a shared feat since,
-- while the class features went on to cover both books (097-120). A player
-- asking for Crusher or Telekinetic found nothing to pick. Scope decided
-- 2026-11-13: these two books, the ones the subclasses already come from.
--
-- Shared rows (campaign_id omitted, so null), 040's precedent: a published
-- feat belongs in every campaign's picker. As in 040, only a migration can
-- write one, because it runs as the table owner outside RLS.
--
-- CATEGORIES ARE THE EXISTING SIX, so neither the CHECK nor featCategories in
-- src/services/feats.ts changes. Racial feats are filed by what they do
-- (Elven Accuracy is combat, Dragon Hide is defense), not grouped under a new
-- 'racial' category. A category is exclusive (052), so a 'racial' one would
-- take that grouping away from fifteen feats. Racial feats instead get the
-- tag 'racial', and every row gets a source tag, 'tcoe' or 'xgte'. Tags are
-- not searchable or filterable yet (useSearchBar matches names only), so they
-- record the fact for later rather than doing anything today. If a "Racial"
-- button is wanted, 052 is the shape to copy.
--
-- Counts this file adds, and the shared totals afterwards (BLOCK 0):
--
--             added   total
--   combat        9      24
--   defense       5      12
--   general       2       5
--   magic        11      17
--   skill         3      12
--   social        0       2
--                30      72
--
-- PREREQUISITES: eighteen of the thirty have one, the fifteen racial feats
-- and three from Tasha's (Eldritch Adept, Fighting Initiate, Metamagic
-- Adept), so 29 of 72 shared feats now carry one. Still display only: see
-- 039 and KNOWN_ISSUES. None of the thirty is repeatable.
--
-- No effect keys: none of 159's keys fits any of these feats, so `effect` is
-- left null and the sheet shows them as text. Use counters are 171's job,
-- 040/157's split.
--
-- Descriptions follow 040's rule: a lead paragraph in our own words, with the
-- mechanics as bullets and every number kept. Half-feat ability increases are
-- their own bullet. Written from memory on 2026-11-13; check against the books,
-- especially Poisoner's DC and dose rules and Chef's creature count.
--
-- No schema change, so no reload and no gen:types.
--
-- RUN THE MIGRATION BLOCK BELOW ON ITS OWN, then the verification blocks one
-- at a time. Per 036 the ledger insert is unguarded, so a second run fails on
-- the primary key and rolls back, taking the thirty inserts with it.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

insert into public.feats (name, category, prerequisite, description, benefits, repeatable, tags) values

-- ---------------------------------------------------------------------------
-- Tasha's Cauldron of Everything
-- ---------------------------------------------------------------------------

($$Artificer Initiate$$, $$magic$$, null,
 $$You have picked up a little of an artificer's craft: a cantrip, a spell, and a feel for one set of tools.$$,
 array[
   $$You learn one cantrip of your choice from the artificer spell list.$$,
   $$You learn one 1st-level artificer spell of your choice. You can cast it once without a spell slot, regaining the ability on a long rest, and you can also cast it using any spell slots you have.$$,
   $$Intelligence is your spellcasting ability for these spells.$$,
   $$You gain proficiency with one type of artisan's tools of your choice, and you can use them as a spellcasting focus for any spell that uses Intelligence.$$
 ], false, array[$$tcoe$$, $$spells$$]),

($$Chef$$, $$general$$, null,
 $$Time in a kitchen has taught you to make food that mends as well as it fills.$$,
 array[
   $$Increase your Constitution or Wisdom by 1, to a maximum of 20.$$,
   $$You gain proficiency with cook's utensils.$$,
   $$As part of a short rest, you can cook special food if you have ingredients and cook's utensils. At the end of the rest, up to 4 + your proficiency bonus creatures who eat it and spend Hit Dice regain an extra 1d8 hit points.$$,
   $$With 1 hour of work, or when you finish a long rest, you can cook a number of treats equal to your proficiency bonus. A creature can eat one as a bonus action to gain temporary hit points equal to your proficiency bonus. Treats go stale after 8 hours.$$
 ], false, array[$$tcoe$$, $$healing$$, $$half-feat$$]),

($$Crusher$$, $$combat$$, null,
 $$Your blunt blows shove foes where you want them and leave them reeling.$$,
 array[
   $$Increase your Strength or Constitution by 1, to a maximum of 20.$$,
   $$Once per turn, when you hit a creature with an attack that deals bludgeoning damage, you can move it 5 feet to an unoccupied space, if the target is no more than one size larger than you.$$,
   $$When you score a critical hit that deals bludgeoning damage, attack rolls against that creature have advantage until the start of your next turn.$$
 ], false, array[$$tcoe$$, $$damage$$, $$half-feat$$]),

($$Eldritch Adept$$, $$magic$$, $$Spellcasting or Pact Magic feature$$,
 $$Studying occult lore has unlocked one of the eldritch invocations warlocks use.$$,
 array[
   $$You learn one Eldritch Invocation of your choice from the warlock class. If it has a prerequisite, you can choose it only if you are a warlock and meet the prerequisite.$$,
   $$Whenever you gain a level, you can replace the invocation with another one.$$
 ], false, array[$$tcoe$$, $$invocations$$]),

($$Fey Touched$$, $$magic$$, null,
 $$Contact with the Feywild has left a trace of its magic in you.$$,
 array[
   $$Increase your Intelligence, Wisdom or Charisma by 1, to a maximum of 20.$$,
   $$You learn misty step and one 1st-level spell of your choice from the divination or enchantment school.$$,
   $$You can cast each of these spells once without a spell slot, regaining the ability on a long rest, and you can also cast them using any spell slots you have.$$,
   $$The spellcasting ability for these spells is the ability increased by this feat.$$
 ], false, array[$$tcoe$$, $$spells$$, $$half-feat$$]),

($$Fighting Initiate$$, $$combat$$, $$Proficiency with a martial weapon$$,
 $$Your martial training has given you a fighting style of your own.$$,
 array[
   $$You learn one Fighting Style option of your choice from the fighter class. You can't take one you already have from another feature.$$,
   $$Whenever you reach a level that grants the Ability Score Improvement feature, you can replace it with another fighting style you don't have.$$
 ], false, array[$$tcoe$$, $$fighting style$$]),

($$Gunner$$, $$combat$$, null,
 $$You have a quick hand and a keen eye with firearms.$$,
 array[
   $$Increase your Dexterity by 1, to a maximum of 20.$$,
   $$You gain proficiency with firearms.$$,
   $$You ignore the loading property of firearms.$$,
   $$Being within 5 feet of a hostile creature doesn't impose disadvantage on your ranged attack rolls.$$
 ], false, array[$$tcoe$$, $$ranged$$, $$half-feat$$]),

($$Metamagic Adept$$, $$magic$$, $$Spellcasting or Pact Magic feature$$,
 $$You have learned to bend spells the way a sorcerer does.$$,
 array[
   $$You learn two Metamagic options of your choice from the sorcerer class. You can use only one per spell, unless an option says otherwise.$$,
   $$You gain 2 sorcery points to spend on Metamagic, and you regain them on a long rest.$$,
   $$Whenever you reach a level that grants the Ability Score Improvement feature, you can replace one of these options with another.$$
 ], false, array[$$tcoe$$, $$metamagic$$]),

($$Piercer$$, $$combat$$, null,
 $$You have learned to find the gap and drive the point home.$$,
 array[
   $$Increase your Strength or Dexterity by 1, to a maximum of 20.$$,
   $$Once per turn, when you hit a creature with an attack that deals piercing damage, you can reroll one of the attack's damage dice, and you must use the new roll.$$,
   $$When you score a critical hit that deals piercing damage, you can roll one additional damage die when determining the extra piercing damage.$$
 ], false, array[$$tcoe$$, $$damage$$, $$half-feat$$]),

($$Poisoner$$, $$combat$$, null,
 $$You can prepare and deliver deadly poisons.$$,
 array[
   $$When you make a damage roll, you ignore resistance to poison damage.$$,
   $$You can apply poison to a weapon or piece of ammunition as a bonus action instead of an action.$$,
   $$You gain proficiency with the poisoner's kit. With 1 hour of work and 50 gp of materials, you can make a number of doses of potent poison equal to your proficiency bonus.$$,
   $$A creature hit by a weapon or ammunition coated with the poison must succeed on a DC 14 Constitution saving throw or take 2d8 poison damage and be poisoned until the end of your next turn. Once applied, the poison lasts 1 minute or until you hit with it.$$
 ], false, array[$$tcoe$$, $$damage$$, $$tools$$]),

($$Shadow Touched$$, $$magic$$, null,
 $$Exposure to the Shadowfell has left a trace of its magic in you.$$,
 array[
   $$Increase your Intelligence, Wisdom or Charisma by 1, to a maximum of 20.$$,
   $$You learn invisibility and one 1st-level spell of your choice from the illusion or necromancy school.$$,
   $$You can cast each of these spells once without a spell slot, regaining the ability on a long rest, and you can also cast them using any spell slots you have.$$,
   $$The spellcasting ability for these spells is the ability increased by this feat.$$
 ], false, array[$$tcoe$$, $$spells$$, $$half-feat$$]),

($$Skill Expert$$, $$skill$$, null,
 $$You have honed one talent until it is something more than trained.$$,
 array[
   $$Increase one ability score of your choice by 1, to a maximum of 20.$$,
   $$You gain proficiency in one skill of your choice.$$,
   $$Choose one skill you are proficient in. You gain expertise with it, doubling your proficiency bonus for any ability check that uses it.$$
 ], false, array[$$tcoe$$, $$expertise$$, $$half-feat$$]),

($$Slasher$$, $$combat$$, null,
 $$Your cuts hamper the people you hit.$$,
 array[
   $$Increase your Strength or Dexterity by 1, to a maximum of 20.$$,
   $$Once per turn, when you hit a creature with an attack that deals slashing damage, you can reduce its speed by 10 feet until the start of your next turn.$$,
   $$When you score a critical hit that deals slashing damage, the creature has disadvantage on attack rolls until the start of your next turn.$$
 ], false, array[$$tcoe$$, $$damage$$, $$half-feat$$]),

($$Telekinetic$$, $$magic$$, null,
 $$You can move things, and people, with your mind.$$,
 array[
   $$Increase your Intelligence, Wisdom or Charisma by 1, to a maximum of 20.$$,
   $$You learn mage hand. You can cast it without verbal or somatic components, and the hand is invisible. If you already know it, its range increases by 30 feet. Its spellcasting ability is the one increased by this feat.$$,
   $$As a bonus action, you can try to shove one creature you can see within 30 feet. It must succeed on a Strength saving throw (DC 8 + your proficiency bonus + the modifier of the ability increased by this feat) or be moved 5 feet toward or away from you. A creature can willingly fail.$$
 ], false, array[$$tcoe$$, $$movement$$, $$half-feat$$]),

($$Telepathic$$, $$magic$$, null,
 $$You can speak into the minds of others and catch the edges of their thoughts.$$,
 array[
   $$Increase your Intelligence, Wisdom or Charisma by 1, to a maximum of 20.$$,
   $$You can speak telepathically to any creature you can see within 60 feet. It understands you only if it knows a language you know, and it can't reply telepathically.$$,
   $$You can cast detect thoughts without a spell slot or components once, regaining the ability on a long rest, and you can also cast it using any spell slots you have. Its spellcasting ability is the one increased by this feat.$$
 ], false, array[$$tcoe$$, $$spells$$, $$half-feat$$]),

-- ---------------------------------------------------------------------------
-- Xanathar's Guide to Everything: racial feats
-- ---------------------------------------------------------------------------

($$Bountiful Luck$$, $$general$$, $$Halfling$$,
 $$Your people's luck spills over onto the friends beside you.$$,
 array[
   $$When an ally you can see within 30 feet rolls a 1 on the d20 for an attack roll, ability check or saving throw, you can use your reaction to let them reroll the die. They must use the new roll.$$,
   $$When you use this ability, you can't use your Lucky racial trait before the end of your next turn.$$
 ], false, array[$$xgte$$, $$racial$$, $$reaction$$]),

($$Dragon Fear$$, $$combat$$, $$Dragonborn$$,
 $$When angered, you radiate a dragon's menace.$$,
 array[
   $$Increase your Strength, Constitution or Charisma by 1, to a maximum of 20.$$,
   $$Instead of exhaling destructive energy, you can spend a use of your Breath Weapon to roar. Each creature of your choice within 30 feet must succeed on a Wisdom saving throw (DC 8 + your proficiency bonus + your Charisma modifier) or be frightened of you for 1 minute. A frightened creature repeats the save at the end of each of its turns, ending the effect on a success.$$
 ], false, array[$$xgte$$, $$racial$$, $$half-feat$$]),

($$Dragon Hide$$, $$defense$$, $$Dragonborn$$,
 $$Your scales harden and your nails grow into claws.$$,
 array[
   $$Increase your Strength, Constitution or Charisma by 1, to a maximum of 20.$$,
   $$While you aren't wearing armour, your AC is 13 + your Dexterity modifier. You can still use a shield.$$,
   $$Your retractable claws make your unarmed strikes deal 1d4 + your Strength modifier slashing damage instead of the normal damage.$$
 ], false, array[$$xgte$$, $$racial$$, $$half-feat$$]),

($$Drow High Magic$$, $$magic$$, $$Elf (drow)$$,
 $$You have learned more of the magic of the drow.$$,
 array[
   $$You can cast detect magic at will, without a spell slot.$$,
   $$You can cast levitate and dispel magic once each without a spell slot, regaining the ability on a long rest.$$,
   $$Charisma is your spellcasting ability for these spells.$$
 ], false, array[$$xgte$$, $$racial$$, $$spells$$]),

($$Dwarven Fortitude$$, $$defense$$, $$Dwarf$$,
 $$You have the blood of dwarf heroes in your veins.$$,
 array[
   $$Increase your Constitution by 1, to a maximum of 20.$$,
   $$Whenever you take the Dodge action in combat, you can spend one Hit Die to heal. Roll it, add your Constitution modifier, and regain that many hit points (minimum 0).$$
 ], false, array[$$xgte$$, $$racial$$, $$healing$$, $$half-feat$$]),

($$Elven Accuracy$$, $$combat$$, $$Elf or half-elf$$,
 $$Your aim borders on the uncanny.$$,
 array[
   $$Increase your Dexterity, Intelligence, Wisdom or Charisma by 1, to a maximum of 20.$$,
   $$Whenever you have advantage on an attack roll using Dexterity, Intelligence, Wisdom or Charisma, you can reroll one of the dice once.$$
 ], false, array[$$xgte$$, $$racial$$, $$half-feat$$]),

($$Fade Away$$, $$defense$$, $$Gnome$$,
 $$Your people's knack for illusion lets you vanish when hurt.$$,
 array[
   $$Increase your Dexterity or Intelligence by 1, to a maximum of 20.$$,
   $$Immediately after you take damage, you can use your reaction to become invisible until the end of your next turn, or until you attack, deal damage or force someone to make a saving throw. Once used, you can't do so again until you finish a short or long rest.$$
 ], false, array[$$xgte$$, $$racial$$, $$reaction$$, $$half-feat$$]),

($$Fey Teleportation$$, $$magic$$, $$Elf (high)$$,
 $$Study of high elven lore has given you a sliver of fey power.$$,
 array[
   $$Increase your Intelligence or Charisma by 1, to a maximum of 20.$$,
   $$You learn to speak, read and write Sylvan.$$,
   $$You learn misty step and can cast it once without a spell slot, regaining the ability on a short or long rest. Intelligence is your spellcasting ability for it.$$
 ], false, array[$$xgte$$, $$racial$$, $$spells$$, $$half-feat$$]),

($$Flames of Phlegethos$$, $$magic$$, $$Tiefling$$,
 $$You can call on the fires of the Nine Hells to burn your foes.$$,
 array[
   $$Increase your Intelligence or Charisma by 1, to a maximum of 20.$$,
   $$When you roll fire damage for a spell you cast, you can reroll any 1 on the fire damage dice, and you must use the new roll.$$,
   $$Whenever you cast a spell that deals fire damage, you can wreathe yourself in flames until the end of your next turn. They shed bright light for 30 feet and dim light for 30 more, and a creature within 5 feet of you that hits you with a melee attack takes 1d4 fire damage.$$
 ], false, array[$$xgte$$, $$racial$$, $$fire$$, $$half-feat$$]),

($$Infernal Constitution$$, $$defense$$, $$Tiefling$$,
 $$Your fiendish blood makes you hardy against cold and venom.$$,
 array[
   $$Increase your Constitution by 1, to a maximum of 20.$$,
   $$You have resistance to cold and poison damage.$$,
   $$You have advantage on saving throws against being poisoned.$$
 ], false, array[$$xgte$$, $$racial$$, $$resistance$$, $$half-feat$$]),

($$Orcish Fury$$, $$combat$$, $$Half-orc$$,
 $$Your fury burns tirelessly.$$,
 array[
   $$Increase your Strength or Constitution by 1, to a maximum of 20.$$,
   $$When you hit with a simple or martial weapon, you can roll one of the weapon's damage dice an additional time and add it as extra damage. Once used, you can't do so again until you finish a short or long rest.$$,
   $$Immediately after you use your Relentless Endurance trait, you can use your reaction to make one weapon attack.$$
 ], false, array[$$xgte$$, $$racial$$, $$damage$$, $$half-feat$$]),

($$Prodigy$$, $$skill$$, $$Half-elf, half-orc, or human$$,
 $$You have a knack for learning new things.$$,
 array[
   $$You gain one skill proficiency, one tool proficiency and fluency in one language, each of your choice.$$,
   $$Choose one skill you are proficient in. You gain expertise with it, doubling your proficiency bonus for any ability check that uses it.$$
 ], false, array[$$xgte$$, $$racial$$, $$expertise$$]),

($$Second Chance$$, $$defense$$, $$Halfling$$,
 $$Fortune favours you when someone tries to strike you.$$,
 array[
   $$Increase your Dexterity, Constitution or Charisma by 1, to a maximum of 20.$$,
   $$When a creature you can see hits you with an attack roll, you can use your reaction to force it to reroll. Once used, you can't do so again until you roll initiative at the start of combat or finish a short or long rest.$$
 ], false, array[$$xgte$$, $$racial$$, $$reaction$$, $$half-feat$$]),

($$Squat Nimbleness$$, $$skill$$, $$Dwarf or a Small race$$,
 $$You are uncommonly quick and nimble for your size.$$,
 array[
   $$Increase your Strength or Dexterity by 1, to a maximum of 20.$$,
   $$Your walking speed increases by 5 feet.$$,
   $$You gain proficiency in Acrobatics or Athletics (your choice).$$,
   $$You have advantage on any Strength (Athletics) or Dexterity (Acrobatics) check you make to escape from being grappled.$$
 ], false, array[$$xgte$$, $$racial$$, $$movement$$, $$half-feat$$]),

($$Wood Elf Magic$$, $$magic$$, $$Elf (wood)$$,
 $$You have learned the magic of the primeval woods.$$,
 array[
   $$You learn one druid cantrip of your choice.$$,
   $$You can cast longstrider and pass without trace once each without a spell slot, regaining the ability on a long rest.$$,
   $$Wisdom is your spellcasting ability for all three spells.$$
 ], false, array[$$xgte$$, $$racial$$, $$spells$$]);

-- ---- Assert the end state, not the work. Do not demote to a notice. -------
-- The thirty names appear here once. Every one must now be exactly one
-- shared row, and the shared total must be 72. If a shared feat of the same
-- name was already added by hand, that shows up here as a 2 and rolls back.
do $$
declare
  c_total constant int := 72;
  c_feats constant text[] := array[
    'Artificer Initiate', 'Chef', 'Crusher', 'Eldritch Adept', 'Fey Touched',
    'Fighting Initiate', 'Gunner', 'Metamagic Adept', 'Piercer', 'Poisoner',
    'Shadow Touched', 'Skill Expert', 'Slasher', 'Telekinetic', 'Telepathic',
    'Bountiful Luck', 'Dragon Fear', 'Dragon Hide', 'Drow High Magic',
    'Dwarven Fortitude', 'Elven Accuracy', 'Fade Away', 'Fey Teleportation',
    'Flames of Phlegethos', 'Infernal Constitution', 'Orcish Fury', 'Prodigy',
    'Second Chance', 'Squat Nimbleness', 'Wood Elf Magic'
  ];
  v_name  text;
  v_count int;
begin
  if cardinality(c_feats) <> 30 then
    raise exception 'c_feats lists % names (expected 30). Rolled back.', cardinality(c_feats);
  end if;

  foreach v_name in array c_feats loop
    select count(*) into v_count
      from public.feats
     where name = v_name and campaign_id is null;
    if v_count <> 1 then
      raise exception '% shared rows named % (expected 1). Rolled back.', v_count, v_name;
    end if;
  end loop;

  select count(*) into v_count from public.feats where campaign_id is null;
  if v_count <> c_total then
    raise exception '% shared feats (expected %). Rolled back.', v_count, c_total;
  end if;
end
$$;

insert into public.schema_migrations (version) values ('170');

commit;


-- ===========================================================================
-- VERIFICATION -- run each block on its own
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOCK 0: the counts are the ones the header claims
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: six rows -- combat 24, defense 12, general 5, magic 17,
--                 skill 12, social 2.

begin;
select category, count(*)
  from public.feats
 where campaign_id is null
 group by category
 order by category;
rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: seventy-two shared feats, every one of them well-formed
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, total 72 and every other column `t`.

begin;
select
  count(*)                                                    as total,
  count(*) = 72                                               as all_present,
  bool_and(name = trim(name) and name <> '')                  as names_clean,
  bool_and(description <> '')                                 as descriptions_present,
  bool_and(cardinality(benefits) > 0)                         as benefits_present,
  count(*) filter (where prerequisite is not null) = 29       as twenty_nine_prereqs,
  count(*) filter (where repeatable) = 2                      as two_repeatable,
  count(*) filter (where 'racial' = any(tags)) = 15           as fifteen_racial,
  count(*) filter (where 'tcoe' = any(tags)) = 15             as fifteen_tcoe,
  count(distinct name) = count(*)                             as names_unique
from public.feats
where campaign_id is null;
rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: the two feats that prompted this
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: two rows -- Crusher (combat, 3 benefits) and Telekinetic
--                 (magic, 3 benefits), neither with a prerequisite.

begin;
select name, category, prerequisite, cardinality(benefits) as benefits
  from public.feats
 where campaign_id is null and name in ('Crusher', 'Telekinetic')
 order by name;
rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 3: the ledger
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, `t`.

begin;
select count(*) = 1 as ledger_row
  from public.schema_migrations where version = '170';
rollback;

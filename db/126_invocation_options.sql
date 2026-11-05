-- db/126_invocation_options.sql
--
-- The Warlock's Eldritch Invocations get a picker: 32 PHB, 14 Xanathar's and 8
-- Tasha's invocations (54), labelled by book. Two at 2nd level, rising to
-- eight at 18th. The PHB texts are 093's, already in our own words; the
-- Xanathar's and Tasha's ones are new, same style.
--
-- Prerequisites (a level, a pact boon, the eldritch blast cantrip, a curse)
-- are display only. The picker shows them; nothing stops a 2nd-level warlock
-- picking Witch Sight. Pact of the Talisman is itself Tasha's optional rule,
-- so its three invocations are only useful at a table that allows it.
--
-- 122's shape, one list per file: kind 'invocation' joins the CHECK (one list
-- in two places with FEATURE_OPTION_KINDS, which shipped first so the client
-- could parse it), 54 shared options are seeded (32 phb, 14 xgte, 8 tcoe),
-- Eldritch Invocations links all of them, and its allowance steps are
-- (2,2) (5,3) (7,4) (9,5) (12,6) (15,7) (18,8). Its text drops the option list, now that each
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
    'fighting_style', 'maneuver', 'metamagic', 'arcane_shot', 'rune', 'invocation'
  ));

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class    constant text := 'Warlock';
  c_feature  constant text := 'Eldritch Invocations';
  c_kind     constant text := 'invocation';
  c_expected constant int  := 54;

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
    (c_kind, 'agonizing_blast', 'Agonizing Blast', 'phb', 'eldritch blast cantrip',
     'Add your Charisma modifier to eldritch blast''s damage.'),
    (c_kind, 'armor_of_shadows', 'Armor of Shadows', 'phb', null,
     'Mage armor on yourself at will.'),
    (c_kind, 'ascendant_step', 'Ascendant Step', 'phb', '9th level',
     'Levitate on yourself at will.'),
    (c_kind, 'beast_speech', 'Beast Speech', 'phb', null,
     'Speak with animals at will.'),
    (c_kind, 'beguiling_influence', 'Beguiling Influence', 'phb', null,
     'Proficiency in Deception and Persuasion.'),
    (c_kind, 'bewitching_whispers', 'Bewitching Whispers', 'phb', '7th level',
     'Compulsion once per long rest, with a warlock spell slot.'),
    (c_kind, 'book_of_ancient_secrets', 'Book of Ancient Secrets', 'phb', 'Pact of the Tome',
     'Two 1st-level rituals in your book, and you can copy more you '
     'find.'),
    (c_kind, 'chains_of_carceri', 'Chains of Carceri', 'phb', '15th level, Pact of the Chain',
     'Hold monster at will on a celestial, fiend or elemental; once per '
     'long rest per creature.'),
    (c_kind, 'devils_sight', 'Devil''s Sight', 'phb', null,
     'See normally in darkness, magical or not, to 120 feet.'),
    (c_kind, 'dreadful_word', 'Dreadful Word', 'phb', '7th level',
     'Confusion once per long rest, with a warlock spell slot.'),
    (c_kind, 'eldritch_sight', 'Eldritch Sight', 'phb', null,
     'Detect magic at will.'),
    (c_kind, 'eldritch_spear', 'Eldritch Spear', 'phb', 'eldritch blast cantrip',
     'Eldritch blast''s range becomes 300 feet.'),
    (c_kind, 'eyes_of_the_rune_keeper', 'Eyes of the Rune Keeper', 'phb', null,
     'You can read all writing.'),
    (c_kind, 'fiendish_vigor', 'Fiendish Vigor', 'phb', null,
     'False life on yourself at will, as a 1st-level spell.'),
    (c_kind, 'gaze_of_two_minds', 'Gaze of Two Minds', 'phb', null,
     'Action: perceive through a willing humanoid''s senses until your '
     'next turn.'),
    (c_kind, 'lifedrinker', 'Lifedrinker', 'phb', '12th level, Pact of the Blade',
     'Pact weapon hits add your Charisma modifier (minimum 1) necrotic '
     'damage.'),
    (c_kind, 'mask_of_many_faces', 'Mask of Many Faces', 'phb', null,
     'Disguise self at will.'),
    (c_kind, 'master_of_myriad_forms', 'Master of Myriad Forms', 'phb', '15th level',
     'Alter self at will.'),
    (c_kind, 'minions_of_chaos', 'Minions of Chaos', 'phb', '9th level',
     'Conjure elemental once per long rest, with a warlock spell slot.'),
    (c_kind, 'mire_the_mind', 'Mire the Mind', 'phb', '5th level',
     'Slow once per long rest, with a warlock spell slot.'),
    (c_kind, 'misty_visions', 'Misty Visions', 'phb', null,
     'Silent image at will.'),
    (c_kind, 'one_with_shadows', 'One with Shadows', 'phb', '5th level',
     'In dim light or darkness, an action makes you invisible until you '
     'move or act.'),
    (c_kind, 'otherworldly_leap', 'Otherworldly Leap', 'phb', '9th level',
     'Jump on yourself at will.'),
    (c_kind, 'repelling_blast', 'Repelling Blast', 'phb', 'eldritch blast cantrip',
     'A beam of eldritch blast that hits pushes the target up to 10 '
     'feet.'),
    (c_kind, 'sculptor_of_flesh', 'Sculptor of Flesh', 'phb', '7th level',
     'Polymorph once per long rest, with a warlock spell slot.'),
    (c_kind, 'sign_of_ill_omen', 'Sign of Ill Omen', 'phb', '5th level',
     'Bestow curse once per long rest, with a warlock spell slot.'),
    (c_kind, 'thief_of_five_fates', 'Thief of Five Fates', 'phb', null,
     'Bane once per long rest, with a warlock spell slot.'),
    (c_kind, 'thirsting_blade', 'Thirsting Blade', 'phb', '5th level, Pact of the Blade',
     'Attack twice with your pact weapon when you take the Attack '
     'action.'),
    (c_kind, 'visions_of_distant_realms', 'Visions of Distant Realms', 'phb', '15th level',
     'Arcane eye at will.'),
    (c_kind, 'voice_of_the_chain_master', 'Voice of the Chain Master', 'phb', 'Pact of the Chain',
     'Talk telepathically with your familiar, and perceive and speak '
     'through it, on the same plane.'),
    (c_kind, 'whispers_of_the_grave', 'Whispers of the Grave', 'phb', '9th level',
     'Speak with dead at will.'),
    (c_kind, 'witch_sight', 'Witch Sight', 'phb', '15th level',
     'See the true form of shapechangers and creatures hidden by '
     'illusion or transmutation within 30 feet.'),
    (c_kind, 'aspect_of_the_moon', 'Aspect of the Moon', 'xgte', 'Pact of the Tome',
     'You don''t need sleep and can''t be magically put to sleep; 8 hours '
     'of light activity gives you a long rest.'),
    (c_kind, 'cloak_of_flies', 'Cloak of Flies', 'xgte', '5th level',
     'Bonus action: a 5-foot aura of flies until you dismiss it or are '
     'incapacitated. Advantage on Intimidation, disadvantage on other '
     'Charisma checks, and a creature starting its turn in it takes '
     'poison damage equal to your Charisma modifier (minimum 0). Once '
     'per short or long rest.'),
    (c_kind, 'eldritch_smite', 'Eldritch Smite', 'xgte', '5th level, Pact of the Blade',
     'Once per turn, when your pact weapon hits, spend a warlock spell '
     'slot for an extra 1d8 force, plus 1d8 per slot level, and knock a '
     'Huge or smaller target prone if you wish.'),
    (c_kind, 'ghostly_gaze', 'Ghostly Gaze', 'xgte', '7th level',
     'Action: for 1 minute (concentration), see through solid objects to '
     '30 feet, with darkvision there. Once per short or long rest.'),
    (c_kind, 'gift_of_the_depths', 'Gift of the Depths', 'xgte', '5th level',
     'Breathe underwater, with a swimming speed equal to your walking '
     'speed. Water breathing once per long rest without a slot.'),
    (c_kind, 'gift_of_the_ever_living_ones', 'Gift of the Ever-Living Ones', 'xgte', 'Pact of the Chain',
     'While your familiar is within 100 feet, healing dice you roll for '
     'yourself count as their maximum.'),
    (c_kind, 'grasp_of_hadar', 'Grasp of Hadar', 'xgte', 'eldritch blast cantrip',
     'Once per turn, when eldritch blast hits a creature, pull it up to '
     '10 feet toward you.'),
    (c_kind, 'improved_pact_weapon', 'Improved Pact Weapon', 'xgte', 'Pact of the Blade',
     'Your pact weapon can be a spellcasting focus, gets +1 to attack '
     'and damage if it isn''t already magical, and can be a shortbow, '
     'longbow or crossbow.'),
    (c_kind, 'lance_of_lethargy', 'Lance of Lethargy', 'xgte', 'eldritch blast cantrip',
     'Once per turn, when eldritch blast hits a creature, its speed '
     'drops by 10 feet until the end of your next turn.'),
    (c_kind, 'maddening_hex', 'Maddening Hex', 'xgte', '5th level, hex spell or a warlock curse feature',
     'Bonus action: the target of your hex or curse, and creatures of '
     'your choice within 5 feet of it, take psychic damage equal to your '
     'Charisma modifier (minimum 1).'),
    (c_kind, 'relentless_hex', 'Relentless Hex', 'xgte', '7th level, hex spell or a warlock curse feature',
     'Bonus action: teleport up to 30 feet to a space within 5 feet of '
     'the target of your hex or curse.'),
    (c_kind, 'shroud_of_shadow', 'Shroud of Shadow', 'xgte', '15th level',
     'Invisibility at will.'),
    (c_kind, 'tomb_of_levistus', 'Tomb of Levistus', 'xgte', '5th level',
     'Reaction: when you take damage, encase yourself in ice until the '
     'end of your next turn, gaining 10 temporary hit points per warlock '
     'level against that damage. Meanwhile you are vulnerable to fire, '
     'have speed 0 and are incapacitated. Once per short or long rest.'),
    (c_kind, 'tricksters_escape', 'Trickster''s Escape', 'xgte', '7th level',
     'Freedom of movement on yourself once per long rest without a slot.'),
    (c_kind, 'bond_of_the_talisman', 'Bond of the Talisman', 'tcoe', '12th level, Pact of the Talisman',
     'Action: while you and your talisman''s wearer are on the same '
     'plane, teleport to a space next to them, or they to you. Uses '
     'equal to your proficiency bonus per long rest.'),
    (c_kind, 'eldritch_mind', 'Eldritch Mind', 'tcoe', null,
     'Advantage on Constitution saves to keep concentration.'),
    (c_kind, 'far_scribe', 'Far Scribe', 'tcoe', '5th level, Pact of the Tome',
     'Up to your proficiency bonus creatures can sign a page of your '
     'book. You can cast sending to any of them without a slot or '
     'material component.'),
    (c_kind, 'gift_of_the_protectors', 'Gift of the Protectors', 'tcoe', '9th level, Pact of the Tome',
     'Up to your proficiency bonus creatures can sign a page of your '
     'book. When one drops to 0 hit points without dying outright, it '
     'drops to 1 instead; once this happens, not again until your next '
     'long rest.'),
    (c_kind, 'investment_of_the_chain_master', 'Investment of the Chain Master', 'tcoe', 'Pact of the Chain',
     'Your familiar gains a 40-foot flying or swimming speed, attacks as '
     'a bonus action on your command, deals magical damage, and uses '
     'your spell DC. Reaction: give it resistance to damage it takes.'),
    (c_kind, 'protection_of_the_talisman', 'Protection of the Talisman', 'tcoe', '7th level, Pact of the Talisman',
     'When your talisman''s wearer fails a saving throw, they can add a '
     'd4. Uses equal to your proficiency bonus per long rest.'),
    (c_kind, 'rebuke_of_the_talisman', 'Rebuke of the Talisman', 'tcoe', 'Pact of the Talisman',
     'Reaction: when an attacker within 30 feet that you can see hits '
     'the talisman''s wearer, it takes psychic damage equal to your '
     'proficiency bonus and is pushed up to 10 feet away.'),
    (c_kind, 'undying_servitude', 'Undying Servitude', 'tcoe', '5th level',
     'Animate dead once per long rest without a slot.');

  insert into public.class_feature_options (feature_id, option_id)
  select v_feature, o.id
    from public.feature_options o
   where o.kind = c_kind and o.campaign_id is null;

  insert into public.class_feature_picks (feature_id, level, total)
  values (v_feature, 2, 2), (v_feature, 5, 3), (v_feature, 7, 4), (v_feature, 9, 5), (v_feature, 12, 6), (v_feature, 15, 7), (v_feature, 18, 8);

  update public.class_features
     set description = 'Learn two invocations (pick them below); 3 at 5th, 4 at 7th, 5 at '
       '9th, 6 at 12th, 7 at 15th, 8 at 18th. On each warlock level you '
       'may swap one. Each option shows its prerequisite in brackets; "at '
       'will" means without a slot.'
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

  if public.feature_picks_allowed(v_feature, 1) <> 0
     or public.feature_picks_allowed(v_feature, 2) <> 2
     or public.feature_picks_allowed(v_feature, 5) <> 3
     or public.feature_picks_allowed(v_feature, 11) <> 5
     or public.feature_picks_allowed(v_feature, 12) <> 6
     or public.feature_picks_allowed(v_feature, 20) <> 8 then
    raise exception '%''s allowance is wrong. Rolled back.', c_feature;
  end if;
exception
  when no_data_found then
    raise exception 'Found no %. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one %. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('126');

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
   where c.name = 'Warlock' and c.campaign_id is null
     and f.name = 'Eldritch Invocations' and f.campaign_id is null
     and f.subclass_id is null
)
select
  (select count(*) = 54 from public.feature_options
    where kind = 'invocation' and campaign_id is null)              as options_54,
  (select count(*) = 54 from public.class_feature_options l
     join f on f.id = l.feature_id)                                   as links_54,
  (select count(*) = 7 from public.class_feature_picks p
     join f on f.id = p.feature_id)                                   as steps_7,
  (select count(*) = 1 from public.schema_migrations
    where version = '126')                                           as ledger_row;

rollback;

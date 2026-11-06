-- db/134_magic_items_dmg_q_s.sql
--
-- The DMG's magic items, Q-S: the rings, robes, rods, staffs and named swords.
-- Fifth of eight seed files on 129's columns; 130's header carries the
-- reasoning for all eight. Only what differs:
--
-- Spell Scroll is 'varies' (common for a cantrip or 1st level, up to
-- legendary for 9th) and one row; the spell is the DM's to name when it's
-- handed out. Rod of the Pact Keeper and Shield are one row per bonus. Ring
-- of Elemental Command and Sword of Answering are one row each, since all
-- their variants share a rarity. Quaal's Feather Token uses the book's name.
--
-- RUN AS ONE BLOCK. CORRECT OUTPUT: "Success. No rows returned."

begin;

create temp table _seed (
  name                text primary key,
  rarity              text not null,
  requires_attunement boolean not null,
  attunement_note     text,
  tags                text[] not null,
  description         text not null
) on commit drop;

insert into _seed values
($$Quaal's Feather Token$$, 'rare', false, null, array['wondrous item','consumable','DMG'],
 $$A single-use token in one of six forms: anchor, bird, fan, swan boat, tree or whip, each with its own effect (holding a ship, a flying mount, a sailing wind, a boat, a sudden oak, a floating attacking whip).$$),
($$Ring of Animal Influence$$, 'rare', false, null, array['ring','DMG'],
 $$3 charges. Spend one to cast animal friendship, fear (beasts only) or speak with animals. Regains 1d3 at dawn.$$),
($$Ring of Djinni Summoning$$, 'legendary', true, null, array['ring','DMG'],
 $$Speak its command word to summon a bound djinni that obeys you for up to 1 hour, once per day. If the djinni dies, the ring loses its magic.$$),
($$Ring of Elemental Command$$, 'legendary', true, null, array['ring','DMG'],
 $$Linked to air, earth, fire or water. Advantage against that plane's elementals, which can't attack you without a save, plus the plane's language, spells from the ring's charges, and a resistance or movement gift of its element.$$),
($$Ring of Evasion$$, 'rare', true, null, array['ring','DMG'],
 $$3 charges. When you fail a Dexterity save, spend one with your reaction to succeed instead. Regains 1d3 at dawn.$$),
($$Ring of Feather Falling$$, 'rare', true, null, array['ring','DMG'],
 $$When you fall, you descend 60 feet per round and take no falling damage.$$),
($$Ring of Free Action$$, 'rare', true, null, array['ring','DMG'],
 $$Difficult terrain costs no extra movement, and magic can't reduce your speed or paralyze or restrain you.$$),
($$Ring of Invisibility$$, 'legendary', true, null, array['ring','DMG'],
 $$As an action, turn invisible until you attack, cast a spell or end it as a bonus action.$$),
($$Ring of Jumping$$, 'uncommon', true, null, array['ring','DMG'],
 $$As a bonus action, cast jump on yourself at will.$$),
($$Ring of Mind Shielding$$, 'uncommon', true, null, array['ring','DMG'],
 $$Immune to magic that reads your thoughts, detects lies, learns your alignment or creature type, and telepathy only reaches you if you allow it. Your soul can dwell in the ring after death.$$),
($$Ring of Protection$$, 'rare', true, null, array['ring','DMG'],
 $$+1 bonus to AC and to saving throws.$$),
($$Ring of Regeneration$$, 'very rare', true, null, array['ring','DMG'],
 $$Regain 1d6 hit points every 10 minutes if you have at least 1. Lost body parts regrow over 1d6+1 days.$$),
($$Ring of Resistance$$, 'rare', true, null, array['ring','DMG'],
 $$Resistance to one damage type, set by the ring's gem (the DM picks or rolls).$$),
($$Ring of Shooting Stars$$, 'very rare', true, $$outdoors at night$$, array['ring','DMG'],
 $$In dim light or darkness: cast dancing lights and light at will, faerie fire once per dawn, and spend its 6 charges on ball lightning or a burst of shooting stars. Regains 1d6 at dawn.$$),
($$Ring of Spell Storing$$, 'rare', true, null, array['ring','DMG'],
 $$Stores up to 5 levels of spells, cast into it by anyone. While wearing it you can cast any stored spell, using the original caster's DC and modifiers.$$),
($$Ring of Spell Turning$$, 'legendary', true, null, array['ring','DMG'],
 $$Advantage on saves against spells that target only you. If you roll a 20 on the save against a spell of 7th level or lower, it is turned back on its caster.$$),
($$Ring of Swimming$$, 'uncommon', false, null, array['ring','DMG'],
 $$A swimming speed of 40 feet.$$),
($$Ring of Telekinesis$$, 'very rare', true, null, array['ring','DMG'],
 $$Cast telekinesis at will, targeting only objects that aren't being worn or carried.$$),
($$Ring of the Ram$$, 'rare', true, null, array['ring','DMG'],
 $$3 charges. Spend 1-3 to fire a spectral ram (+7 to hit, 2d10 force per charge, pushing the target back), or to try to burst an object. Regains 1d3 at dawn.$$),
($$Ring of Three Wishes$$, 'legendary', false, null, array['ring','DMG'],
 $$3 charges. Spend one to cast wish. Becomes nonmagical when the last is used.$$),
($$Ring of Warmth$$, 'uncommon', true, null, array['ring','DMG'],
 $$Resistance to cold damage, and you stay comfortable in temperatures as low as -50 F.$$),
($$Ring of Water Walking$$, 'uncommon', false, null, array['ring','DMG'],
 $$Stand on and move across any liquid surface as if it were solid ground.$$),
($$Ring of X-ray Vision$$, 'rare', true, null, array['ring','DMG'],
 $$As an action, see through solid matter within 30 feet for 1 minute. Using it again before a long rest risks a level of exhaustion (DC 15 Constitution).$$),
($$Robe of Eyes$$, 'rare', true, null, array['wondrous item','DMG'],
 $$See in all directions, with advantage on sight-based Perception, darkvision 120 feet, and sight of invisible and ethereal things within 120 feet. Light or daylight cast on it blinds you for a minute.$$),
($$Robe of Scintillating Colors$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$3 charges. Spend one to make the robe shimmer for a minute: it sheds light, attacks against you have disadvantage, and creatures that see you may be stunned (DC 15 Wisdom). Regains 1d3 at dawn.$$),
($$Robe of Stars$$, 'very rare', true, null, array['wondrous item','DMG'],
 $$+1 to saving throws. Six stars on it can each be pulled off to cast magic missile at 5th level, regaining 1d6 at dusk. As an action, you can enter the Astral Plane with your belongings.$$),
($$Robe of the Archmagi$$, 'legendary', true, $$by a sorcerer, warlock, or wizard$$, array['wondrous item','DMG'],
 $$Unarmoured AC 15 + Dexterity, advantage on saves against spells, and +2 to your spell save DC and spell attack bonus. Its colour matches an alignment.$$),
($$Robe of Useful Items$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$Covered in cloth patches that become real objects when detached: daggers, lanterns, mirrors, poles, rope, sacks, plus 4d4 random extras from its table such as a rowboat or a pit.$$),
($$Rod of Absorption$$, 'very rare', true, null, array['rod','DMG'],
 $$Your reaction absorbs a spell targeting only you, storing its levels (up to 50 over its life). You can spend stored levels as spell slots.$$),
($$Rod of Alertness$$, 'very rare', true, null, array['rod','DMG'],
 $$Advantage on Perception and initiative. Cast detect evil and good, detect magic, detect poison and disease and see invisibility from it. Once per dawn, plant it to create a 120-foot aura of alertness for 10 minutes.$$),
($$Rod of Lordly Might$$, 'legendary', true, null, array['rod','DMG'],
 $$+3 mace with three once-per-dawn powers (drain life, paralyze, terrify) and six buttons that turn it into a flame blade, battleaxe, spear, climbing pole, battering ram or compass.$$),
($$Rod of Resurrection$$, 'legendary', true, $$by a cleric, druid, or paladin$$, array['rod','DMG'],
 $$5 charges. Spend one to cast heal, or five to cast resurrection. Regains 1 at dawn; a 1 in 20 chance at zero that it vanishes.$$),
($$Rod of Rulership$$, 'rare', true, null, array['rod','DMG'],
 $$Once per dawn, creatures of your choice within 120 feet make a DC 15 Wisdom save or are charmed by you for 8 hours.$$),
($$Rod of Security$$, 'very rare', false, null, array['rod','DMG'],
 $$Transports you and up to 199 others to a paradise demiplane, where time spent heals and sustains you, for up to 200 days divided among you. Once per 10 days.$$),
($$Rod of the Pact Keeper, +1$$, 'uncommon', true, $$by a warlock$$, array['rod','DMG'],
 $$+1 to your warlock spell attacks and spell save DC. Once per long rest, regain one warlock spell slot as an action.$$),
($$Rod of the Pact Keeper, +2$$, 'rare', true, $$by a warlock$$, array['rod','DMG'],
 $$+2 to your warlock spell attacks and spell save DC. Once per long rest, regain one warlock spell slot as an action.$$),
($$Rod of the Pact Keeper, +3$$, 'very rare', true, $$by a warlock$$, array['rod','DMG'],
 $$+3 to your warlock spell attacks and spell save DC. Once per long rest, regain one warlock spell slot as an action.$$),
($$Rope of Climbing$$, 'uncommon', false, null, array['wondrous item','DMG'],
 $$60 feet of silk rope that moves on command: it snakes up to fasten itself, knots itself every foot for climbing, and unfastens when told. Has AC 20 and regains lost hit points over time.$$),
($$Rope of Entanglement$$, 'rare', false, null, array['wondrous item','DMG'],
 $$30 feet. On its command word it lashes out at a creature within 20 feet, restraining it (DC 15 Dexterity to avoid, DC 15 Strength or Dexterity to escape).$$),
($$Scarab of Protection$$, 'legendary', true, null, array['wondrous item','DMG'],
 $$Advantage on saves against spells. 12 charges: if you fail a save against necromancy or an undead creature's harmful effect, spend one to succeed instead. Crumbles when empty.$$),
($$Scimitar of Speed$$, 'very rare', true, null, array['weapon','DMG'],
 $$+2 scimitar. You can make one attack with it as a bonus action on each of your turns.$$),
($$Sentinel Shield$$, 'uncommon', false, null, array['armor','DMG'],
 $$Advantage on initiative rolls and on Wisdom (Perception) checks.$$),
($$Shield, +1$$, 'uncommon', false, null, array['armor','DMG'],
 $$+1 to AC on top of the shield's normal bonus.$$),
($$Shield, +2$$, 'rare', false, null, array['armor','DMG'],
 $$+2 to AC on top of the shield's normal bonus.$$),
($$Shield, +3$$, 'very rare', false, null, array['armor','DMG'],
 $$+3 to AC on top of the shield's normal bonus.$$),
($$Shield of Missile Attraction$$, 'rare', true, null, array['armor','DMG'],
 $$Resistance to damage from ranged weapon attacks. Cursed: ranged attacks against targets within 10 feet of you are redirected at you, and you can't let go of it.$$),
($$Slippers of Spider Climbing$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$You can climb walls and ceilings hands-free at your walking speed. Doesn't work on slippery surfaces.$$),
($$Sovereign Glue$$, 'legendary', false, null, array['wondrous item','consumable','DMG'],
 $$1d6+1 ounces of glue that bonds any two objects permanently. Only universal solvent, oil of etherealness or a wish can undo it.$$),
($$Spell Scroll$$, 'varies', false, null, array['scroll','consumable','DMG'],
 $$Holds one spell. A caster with that spell on their class list reads it to cast it without components; a higher-level spell than they can cast needs an ability check. Rarity, DC and attack bonus scale with the spell's level.$$),
($$Spellguard Shield$$, 'very rare', true, null, array['armor','DMG'],
 $$Advantage on saves against spells and magical effects, and spell attacks against you have disadvantage.$$),
($$Sphere of Annihilation$$, 'legendary', false, null, array['wondrous item','DMG'],
 $$A 2-foot sphere of nothingness that destroys any matter it touches. A creature within 60 feet can try to move it with an Intelligence (Arcana) check; failure may pull the sphere toward them.$$),
($$Staff of Charming$$, 'rare', true, $$by a bard, cleric, druid, sorcerer, warlock, or wizard$$, array['staff','DMG'],
 $$10 charges: cast charm person, command or comprehend languages. Once per dawn, when you succeed on a save against enchantment, turn it back on the caster. Regains 1d8+2 at dawn.$$),
($$Staff of Fire$$, 'very rare', true, $$by a druid, sorcerer, warlock, or wizard$$, array['staff','DMG'],
 $$Resistance to fire. 10 charges: burning hands, fireball or wall of fire. Regains 1d6+4 at dawn.$$),
($$Staff of Frost$$, 'very rare', true, $$by a druid, sorcerer, warlock, or wizard$$, array['staff','DMG'],
 $$Resistance to cold. 10 charges: cone of cold, fog cloud, ice storm or wall of ice. Regains 1d6+4 at dawn.$$),
($$Staff of Healing$$, 'rare', true, $$by a bard, cleric, or druid$$, array['staff','DMG'],
 $$10 charges: cure wounds (higher with more charges), lesser restoration or mass cure wounds. Regains 1d6+4 at dawn.$$),
($$Staff of Power$$, 'very rare', true, $$by a sorcerer, warlock, or wizard$$, array['staff','DMG'],
 $$+2 quarterstaff, +2 to AC, saves and spell attacks. 20 charges for a range of attack and control spells. Can be broken in a retributive strike that devastates everything nearby.$$),
($$Staff of Striking$$, 'very rare', true, null, array['staff','DMG'],
 $$+3 quarterstaff. 10 charges: on a hit, spend up to 3 for an extra 1d6 force per charge. Regains 1d6+4 at dawn.$$),
($$Staff of Swarming Insects$$, 'rare', true, $$by a bard, cleric, druid, sorcerer, warlock, or wizard$$, array['staff','DMG'],
 $$10 charges: giant insect, insect plague, or a cloud of insects around you that heavily obscures the area for 10 minutes. Regains 1d6+4 at dawn.$$),
($$Staff of the Magi$$, 'legendary', true, $$by a sorcerer, warlock, or wizard$$, array['staff','DMG'],
 $$+2 quarterstaff, +2 spell attacks, advantage on saves against spells. 50 charges for a deep list of spells, can absorb spells aimed at you, and can be broken in a retributive strike.$$),
($$Staff of the Python$$, 'uncommon', true, $$by a cleric, druid, or warlock$$, array['staff','DMG'],
 $$Thrown to the ground, it becomes a giant constrictor snake under your command. If the snake dies, the staff is destroyed.$$),
($$Staff of the Woodlands$$, 'rare', true, $$by a druid$$, array['staff','DMG'],
 $$+2 quarterstaff and +2 spell attacks. 10 charges: animal friendship, awaken, barkskin, locate animals or plants, speak with animals, speak with plants, wall of thorns; can also become a tree. Regains 1d6+4 at dawn.$$),
($$Staff of Thunder and Lightning$$, 'very rare', true, null, array['staff','DMG'],
 $$+2 quarterstaff with five once-per-dawn powers: lightning on a hit, thunder on a hit, a lightning bolt, a thunderclap, and both at once.$$),
($$Staff of Withering$$, 'rare', true, $$by a cleric, druid, or warlock$$, array['staff','DMG'],
 $$Quarterstaff with 3 charges. On a hit, spend one for an extra 2d10 necrotic, and the target makes a DC 15 Constitution save or has disadvantage on Strength and Constitution checks and saves for an hour.$$),
($$Stone of Controlling Earth Elementals$$, 'rare', false, null, array['wondrous item','DMG'],
 $$Touched to the ground with its command word, it summons an earth elemental, as conjure elemental. Once per dawn.$$),
($$Stone of Good Luck (Luckstone)$$, 'uncommon', true, null, array['wondrous item','DMG'],
 $$+1 to ability checks and saving throws while it is on your person.$$),
($$Sun Blade$$, 'rare', true, null, array['weapon','DMG'],
 $$A hilt that grows a blade of radiance: a +2 longsword with finesse, dealing radiant instead of slashing, +1d8 more against undead. Its light radius can be adjusted.$$),
($$Sword of Answering$$, 'legendary', true, $$by a creature with the same alignment as the sword$$, array['weapon','DMG'],
 $$Longsword, one of nine named blades each tied to an alignment. +3 to attack and damage, and when a creature within reach damages you, your reaction makes an attack against it that ignores its immunities and resistances.$$),
($$Sword of Life Stealing$$, 'rare', true, null, array['weapon','DMG'],
 $$Any sword. On a natural 20 against a creature that isn't a construct or undead, it takes an extra 10 necrotic and you gain 10 temporary hit points.$$),
($$Sword of Sharpness$$, 'very rare', true, null, array['weapon','DMG'],
 $$Any slashing sword. Maximum damage against objects, and on a natural 20 an extra 4d6 slashing and a roll for a severed limb. Can shed light on command.$$),
($$Sword of Vengeance$$, 'uncommon', true, null, array['weapon','DMG'],
 $$Any sword. +1 to attack and damage. Cursed: possessed by a vengeful spirit, it won't leave you, gives disadvantage with other weapons, and compels you to attack whoever damaged you (DC 15 Wisdom).$$),
($$Sword of Wounding$$, 'rare', true, null, array['weapon','DMG'],
 $$Any sword. Hit points it takes can only be regained by resting. Once per turn on a hit, the wound bleeds for an extra 1d4 necrotic per turn until healed (DC 15 Constitution ends it).$$);

insert into public.items
  (name, description, price_cp, tags, kind,
   rarity, requires_attunement, attunement_note)
select s.name, s.description, 0, s.tags, 'general',
       s.rarity, s.requires_attunement, s.attunement_note
  from _seed s
 where not exists (
   select 1 from public.items i
    where i.campaign_id is null and i.name = s.name
 );

do $do$
declare
  v_expected int := (select count(*) from _seed);
  v_found    int;
begin
  select count(*) into v_found
    from _seed s
    join public.items i
      on i.campaign_id is null
     and i.name = s.name
     and i.rarity = s.rarity
     and i.requires_attunement = s.requires_attunement;
  if v_found <> v_expected then
    raise exception 'magic item seed incomplete: % of % rows present', v_found, v_expected;
  end if;
end
$do$;

insert into public.schema_migrations (version) values ('134');

commit;

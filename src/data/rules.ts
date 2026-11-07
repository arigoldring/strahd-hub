/**
 * The handful of 5e rules the full-sheet mock-up computes from. Code-side
 * reference data, like maps.ts beside it: the six abilities and eighteen skills
 * are fixed by the rules, not by a campaign, so there is nothing here a table
 * would make more flexible.
 *
 * Pure functions only — no React, no Supabase — so the page can derive every
 * number on render from the handful of values a player actually types.
 */

export const ABILITIES = ["str", "dex", "con", "int", "wis", "cha"] as const;
export type Ability = (typeof ABILITIES)[number];

export const ABILITY_LABELS: Record<Ability, string> = {
  str: "Strength",
  dex: "Dexterity",
  con: "Constitution",
  int: "Intelligence",
  wis: "Wisdom",
  cha: "Charisma",
};

// ABILITIES, SPELL_ABILITIES and SKILLS below are mirrored by CHECK constraints
// in 054 (classes) and 056 (character_proficiencies). One list in two places:
// change them together, as with featCategories and 039.

/** The only abilities any class casts with. */
export const SPELL_ABILITIES = ["int", "wis", "cha"] as const;
export type SpellAbility = (typeof SPELL_ABILITIES)[number];

/** Average HP: max die at 1st level, then the rounded-up average per level. */
export function averageHp(hitDie: number, level: number, conMod: number) {
  const perLevel = hitDie / 2 + 1;
  return Math.max(1, hitDie + conMod + (level - 1) * (perLevel + conMod));
}

export const SKILLS = [
  { key: "acrobatics", label: "Acrobatics", ability: "dex" },
  { key: "animalHandling", label: "Animal Handling", ability: "wis" },
  { key: "arcana", label: "Arcana", ability: "int" },
  { key: "athletics", label: "Athletics", ability: "str" },
  { key: "deception", label: "Deception", ability: "cha" },
  { key: "history", label: "History", ability: "int" },
  { key: "insight", label: "Insight", ability: "wis" },
  { key: "intimidation", label: "Intimidation", ability: "cha" },
  { key: "investigation", label: "Investigation", ability: "int" },
  { key: "medicine", label: "Medicine", ability: "wis" },
  { key: "nature", label: "Nature", ability: "int" },
  { key: "perception", label: "Perception", ability: "wis" },
  { key: "performance", label: "Performance", ability: "cha" },
  { key: "persuasion", label: "Persuasion", ability: "cha" },
  { key: "religion", label: "Religion", ability: "int" },
  { key: "sleightOfHand", label: "Sleight of Hand", ability: "dex" },
  { key: "stealth", label: "Stealth", ability: "dex" },
  { key: "survival", label: "Survival", ability: "wis" },
] as const satisfies readonly { key: string; label: string; ability: Ability }[];
export type SkillKey = (typeof SKILLS)[number]["key"];

/**
 * A fighting style as the maths sees it: feature_options.key (095), such as
 * 'defense'. The styles themselves, their names and text, are rows in that
 * table. Code knows only the keys it gives an effect to, below. A homebrew
 * style has no key and so no automatic effect.
 */
export type FightingStyleKey = string;

/** 0 = untrained, 1 = proficient, 2 = expertise (proficiency bonus doubled). */
export type ProficiencyLevel = 0 | 1 | 2;

export function abilityModifier(score: number): number {
  return Math.floor((score - 10) / 2);
}

/** +2 at 1st level, +1 every four levels after, +6 at 17th. */
export function proficiencyBonus(level: number): number {
  const clamped = Math.min(20, Math.max(1, Math.trunc(level) || 1));
  return Math.ceil(clamped / 4) + 1;
}

export function skillBonus(
  mod: number,
  pb: number,
  prof: ProficiencyLevel,
): number {
  return mod + pb * prof;
}

/** "+3", "+0", "−1" — a real minus sign, so the column lines up in serif type. */
export function formatModifier(n: number): string {
  return n < 0 ? `−${Math.abs(n)}` : `+${n}`;
}

// ---------- armour class & attacks ----------
//
// Structural parameter types rather than imports of services/items' Armor and
// Weapon, so this file stays free of the services layer. The real items
// satisfy these shapes as they are.

export interface ArmorLike {
  name: string;
  category: "light" | "medium" | "heavy" | "shield";
  baseArmorClass: number;
}

/**
 * AC from what's worn. Light adds all of DEX, medium caps it at +2, heavy adds
 * none. A shield adds its own value (+2 for the PHB shield). With no armour,
 * Unarmored Defense (Barbarian CON, Monk WIS) adds its ability on top of the
 * plain 10 + DEX, unless the class loses it with a shield (the Monk). The
 * caller says which: whether a shield breaks it is not a column on classes.
 *
 * Defense adds +1 only while body armour is worn. A shield alone doesn't
 * count, and neither does Unarmored Defense. `styles` is every fighting style
 * the character holds, across all their classes, so a style picked twice
 * still adds once.
 *
 * Effects (159): Medium Armor Master raises the medium cap to +3, and
 * Integrated Protection (Warforged) adds +1 whatever is worn.
 *
 * Returns the parts as well as the total, so the sheet can say where the
 * number came from rather than just print it.
 */
export function armorClass(opts: {
  armor: ArmorLike | null;
  shield: ArmorLike | null;
  dexMod: number;
  unarmored: { ability: Ability; mod: number; allowsShield: boolean } | null;
  styles: readonly FightingStyleKey[];
  bonus: number;
  /**
   * A fixed base that replaces 10 with no armour on, shield or not: Draconic
   * Resilience's 13 + DEX. When a character also has Unarmored Defense, the
   * higher of the two applies; they never stack.
   */
  natural?: { name: string; base: number } | null;
  effects?: EffectLevels;
}): { total: number; parts: string[] } {
  const {
    armor,
    shield,
    dexMod,
    unarmored,
    styles,
    bonus,
    natural = null,
    effects = new Map(),
  } = opts;
  const parts: string[] = [];
  let total: number;

  if (armor) {
    const mediumCap = effects.has("medium_armor_master") ? 3 : 2;
    const dex =
      armor.category === "heavy"
        ? 0
        : armor.category === "medium"
          ? Math.min(dexMod, mediumCap)
          : dexMod;
    total = armor.baseArmorClass + dex;
    parts.push(`${armor.name} ${armor.baseArmorClass}`);
    if (armor.category !== "heavy") parts.push(`DEX ${formatModifier(dex)}`);
  } else {
    const ud = unarmored && (unarmored.allowsShield || !shield) ? unarmored : null;
    const udTotal = 10 + dexMod + (ud?.mod ?? 0);
    if (natural && natural.base + dexMod > udTotal) {
      total = natural.base + dexMod;
      parts.push(`${natural.name} ${natural.base}`, `DEX ${formatModifier(dexMod)}`);
    } else {
      total = udTotal;
      parts.push("10", `DEX ${formatModifier(dexMod)}`);
      if (ud) parts.push(`${ud.ability.toUpperCase()} ${formatModifier(ud.mod)}`);
    }
  }

  if (shield) {
    total += shield.baseArmorClass;
    parts.push(`${shield.name} +${shield.baseArmorClass}`);
  }
  if (armor && styles.includes("defense")) {
    total += 1;
    parts.push("Defense +1");
  }
  if (effects.has("integrated_protection")) {
    total += 1;
    parts.push("Integrated Protection +1");
  }
  if (bonus) {
    total += bonus;
    parts.push(`other ${formatModifier(bonus)}`);
  }
  return { total, parts };
}

export interface WeaponLike {
  damageDice: string;
  properties: readonly string[];
  rangeNormal?: number;
}

/**
 * A ranged weapon has a range and is not merely thrown. A dagger has a range
 * too, but it's a melee weapon you can throw. The one this gets wrong is the
 * Dart: it is a ranged weapon with the thrown property, and nothing in the
 * item's columns tells it apart from a dagger (see KNOWN_ISSUES).
 *
 * weaponAbility and the Archery bonus both ask this, so they can't disagree
 * about what counts as ranged.
 */
export function isRangedWeapon(weapon: WeaponLike): boolean {
  return weapon.rangeNormal != null && !weapon.properties.includes("thrown");
}

/**
 * Which ability a weapon attacks with. Ranged weapons use DEX; finesse
 * weapons use whichever of STR and DEX is better; everything else is STR.
 */
export function weaponAbility(
  weapon: WeaponLike,
  strMod: number,
  dexMod: number,
): Ability {
  if (isRangedWeapon(weapon)) return "dex";
  if (weapon.properties.includes("finesse")) {
    return dexMod > strMod ? "dex" : "str";
  }
  return "str";
}

/**
 * The to-hit bonus a fighting style gives this weapon: Archery's +2 on ranged
 * weapons, otherwise 0. Dueling and Thrown Weapon Fighting add damage, not
 * to-hit. Dueling depends on what's in the other hand, which the sheet doesn't
 * track, so both stay manual for now.
 */
export function styleAttackBonus(
  weapon: WeaponLike,
  styles: readonly FightingStyleKey[],
): number {
  return styles.includes("archery") && isRangedWeapon(weapon) ? 2 : 0;
}

/** "1d8" + 3 → "1d8+3"; a zero modifier is left off. */
export function damageString(dice: string, mod: number): string {
  if (mod === 0) return dice;
  return `${dice}${mod > 0 ? "+" : "−"}${Math.abs(mod)}`;
}

/** A character's level is the sum of their class levels; 1 before any class. */
export function totalLevel(classes: readonly { level: number }[]): number {
  return Math.max(1, classes.reduce((sum, c) => sum + c.level, 0));
}

// ---------- class feature effects (121) ----------
//
// A feature row that changes a derived number carries an `effect` key
// (class_features.effect). The sheet collects the keys of every feature a
// character has, with the level of the class that grants each one, and the
// functions below turn that into numbers. A feature with no key is display
// only. Conditions the sheet can't see (advantage, an ally beside the target,
// being conscious) are left to the player.
//
// Since 159 a race and a feat carry a key the same way (races.effect,
// feats.effect), and theirs read the character's total level.

/**
 * One list in two places with 159's effect_key domain, which all three
 * effect columns use.
 */
export const FEATURE_EFFECTS = [
  "extra_attack",
  "extra_attack_fighter",
  "improved_critical",
  "superior_critical",
  "sneak_attack",
  "martial_arts",
  "jack_of_all_trades",
  "remarkable_athlete",
  "dread_ambusher",
  "tactical_wit",
  "rakish_audacity",
  "aura_of_protection",
  "fast_movement",
  "unarmored_movement",
  "draconic_resilience",
  "battle_ready",
  // 159: one more class key, then the race's and the feats'.
  "brutal_critical",
  "integrated_protection",
  "alert",
  "observant",
  "mobile",
  "tough",
  "medium_armor_master",
] as const;
export type FeatureEffect = (typeof FEATURE_EFFECTS)[number];

/** Each effect the character has, with the level of the class granting it. */
export type EffectLevels = ReadonlyMap<FeatureEffect, number>;

/**
 * The effects a character has: every class entry's features up to that
 * class's own level, plus its subclass's (the sheet's level rule). The value
 * is the granting class's level, which the scaling effects read (Sneak
 * Attack by rogue level, not total level). If two entries grant the same
 * key, the higher level wins.
 *
 * `others` are the race's and the feats' keys (159). Those apply from 1st
 * level, and their value is the character's total level (Tough's +2 per
 * level), the rule 153 uses for feat counters.
 */
export function collectEffects(
  entries: readonly { classId: string; subclassId: string | null; level: number }[],
  features: readonly {
    classId: string;
    subclassId: string | null;
    level: number;
    effect: FeatureEffect | null;
  }[],
  others: readonly (FeatureEffect | null)[] = [],
): Map<FeatureEffect, number> {
  const out = new Map<FeatureEffect, number>();
  const total = entries.reduce((sum, e) => sum + e.level, 0);
  for (const effect of others) {
    if (effect) out.set(effect, Math.max(out.get(effect) ?? 0, total));
  }
  for (const e of entries) {
    for (const f of features) {
      if (
        f.effect &&
        f.classId === e.classId &&
        f.level <= e.level &&
        (f.subclassId == null || f.subclassId === e.subclassId)
      ) {
        out.set(f.effect, Math.max(out.get(f.effect) ?? 0, e.level));
      }
    }
  }
  return out;
}

/**
 * Attacks per Attack action. Extra Attack from two classes doesn't stack
 * (PHB multiclassing), so this is the best single source: 2 for Extra
 * Attack, or the Fighter's 3 at 11th and 4 at 20th.
 */
export function attacksPerAction(effects: EffectLevels): number {
  const fighter = effects.get("extra_attack_fighter");
  const fromFighter = fighter == null ? 1 : fighter >= 20 ? 4 : fighter >= 11 ? 3 : 2;
  return Math.max(fromFighter, effects.has("extra_attack") ? 2 : 1);
}

/** The lowest d20 roll that crits with a weapon: 20, 19 or 18 (Champion). */
export function critThreshold(effects: EffectLevels): number {
  if (effects.has("superior_critical")) return 18;
  if (effects.has("improved_critical")) return 19;
  return 20;
}

/** Sneak Attack d6s: half the rogue level, rounded up. 0 without it. */
export function sneakAttackDice(effects: EffectLevels): number {
  const rogue = effects.get("sneak_attack");
  return rogue == null ? 0 : Math.ceil(rogue / 2);
}

/**
 * Brutal Critical: extra weapon damage dice on a melee crit. 1 at barbarian
 * 9th, 2 at 13th, 3 at 17th. 0 without it.
 */
export function brutalCriticalDice(effects: EffectLevels): number {
  const barbarian = effects.get("brutal_critical");
  if (barbarian == null) return 0;
  return barbarian >= 17 ? 3 : barbarian >= 13 ? 2 : 1;
}

/**
 * The weapon training a character attacks with: the class's own, raised to
 * martial by Battle Ready (Battle Smith), which grants martial weapons on
 * top of the Artificer's simple ones.
 */
export function weaponTraining(
  classTraining: "simple" | "martial" | null,
  effects: EffectLevels,
): "simple" | "martial" | null {
  return effects.has("battle_ready") ? "martial" : classTraining;
}

/**
 * Battle Ready's other half: a magic weapon may attack with INT instead of
 * STR or DEX. `base` is the ability the weapon would use otherwise
 * (weaponAbility, or Martial Arts' choice); INT replaces it only when INT's
 * modifier is higher. A mundane weapon never changes. "Magic" means the item
 * has a rarity (129), which no seeded weapon-kind row has (KNOWN_ISSUES).
 */
export function battleReadyAbility(
  base: Ability,
  mods: { readonly [A in Ability]?: number },
  isMagic: boolean,
  effects: EffectLevels,
): Ability {
  if (!isMagic || !effects.has("battle_ready")) return base;
  return (mods.int ?? 0) > (mods[base] ?? 0) ? "int" : base;
}

/** The Martial Arts die's size: d4, d6 at 5th, d8 at 11th, d10 at 17th. */
export function martialArtsDie(effects: EffectLevels): number | null {
  const monk = effects.get("martial_arts");
  if (monk == null) return null;
  return monk >= 17 ? 10 : monk >= 11 ? 8 : monk >= 5 ? 6 : 4;
}

export interface MonkWeaponLike extends WeaponLike {
  name: string;
  category: string;
}

/**
 * A monk weapon: the shortsword, or a simple melee weapon that is neither
 * heavy nor two-handed. The shortsword is matched by name because the PHB
 * names it; nothing else in a weapon's columns sets it apart.
 */
export function isMonkWeapon(weapon: MonkWeaponLike): boolean {
  if (weapon.name === "Shortsword") return true;
  return (
    weapon.category === "simple" &&
    !isRangedWeapon(weapon) &&
    !weapon.properties.includes("heavy") &&
    !weapon.properties.includes("two-handed")
  );
}

/**
 * Martial Arts on one weapon: whether it may use DEX, and the damage dice to
 * show. Applies only while the monk wears no armour and holds no shield.
 * The die replaces a weapon's own when it is bigger ("1d6" vs d8).
 */
export function martialArtsWeapon(
  weapon: MonkWeaponLike,
  die: number | null,
  unarmored: boolean,
): { finesse: boolean; dice: string } {
  if (die == null || !unarmored || !isMonkWeapon(weapon)) {
    return { finesse: false, dice: weapon.damageDice };
  }
  const own = /^1d(\d+)$/.exec(weapon.damageDice);
  const bigger = own == null || die > Number(own[1]);
  return { finesse: true, dice: bigger ? `1d${die}` : weapon.damageDice };
}

/**
 * The bonus an untrained ability check gets: Jack of All Trades' half
 * proficiency (rounded down) on any check, or Remarkable Athlete's half
 * (rounded up) on STR, DEX and CON checks. They don't stack; the better one
 * applies. Callers add it only where the check has no proficiency already.
 */
export function untrainedCheckBonus(
  ability: Ability,
  pb: number,
  effects: EffectLevels,
): { bonus: number; source: string | null } {
  const jack = effects.has("jack_of_all_trades") ? Math.floor(pb / 2) : 0;
  const athlete =
    effects.has("remarkable_athlete") && ["str", "dex", "con"].includes(ability)
      ? Math.ceil(pb / 2)
      : 0;
  if (athlete === 0 && jack === 0) return { bonus: 0, source: null };
  return athlete >= jack
    ? { bonus: athlete, source: "Remarkable Athlete" }
    : { bonus: jack, source: "Jack of All Trades" };
}

/**
 * Initiative is a DEX check: DEX, plus Jack of All Trades or Remarkable
 * Athlete, plus any ability a subclass adds (Dread Ambusher WIS, Tactical
 * Wit INT, Rakish Audacity CHA). Parts name each piece for the tooltip.
 */
export function initiative(
  mods: Record<Ability, number>,
  pb: number,
  effects: EffectLevels,
): { total: number; parts: string[] } {
  const parts = [`DEX ${formatModifier(mods.dex)}`];
  let total = mods.dex;
  const untrained = untrainedCheckBonus("dex", pb, effects);
  if (untrained.source) {
    total += untrained.bonus;
    parts.push(`${untrained.source} ${formatModifier(untrained.bonus)}`);
  }
  const added: [FeatureEffect, Ability, string][] = [
    ["dread_ambusher", "wis", "Dread Ambusher"],
    ["tactical_wit", "int", "Tactical Wit"],
    ["rakish_audacity", "cha", "Rakish Audacity"],
  ];
  for (const [effect, ability, name] of added) {
    if (effects.has(effect)) {
      total += mods[ability];
      parts.push(`${name} ${formatModifier(mods[ability])}`);
    }
  }
  if (effects.has("alert")) {
    total += 5;
    parts.push("Alert +5");
  }
  return { total, parts };
}

/**
 * What a feature adds to a passive score on top of its skill: Observant's +5
 * to passive Perception and Investigation.
 */
export function passiveBonus(skill: SkillKey, effects: EffectLevels): number {
  return effects.has("observant") && (skill === "perception" || skill === "investigation")
    ? 5
    : 0;
}

/** Aura of Protection: CHA modifier, minimum +1, on every saving throw. */
export function saveAura(chaMod: number, effects: EffectLevels): number {
  return effects.has("aura_of_protection") ? Math.max(1, chaMod) : 0;
}

/**
 * Speed from features. Fast Movement: +10 ft without heavy armour.
 * Unarmored Movement: +10 ft at 2nd, rising by 5 every four monk levels to
 * +30 at 18th, with no armour and no shield.
 */
export function speedBonus(
  effects: EffectLevels,
  worn: { armorCategory: ArmorLike["category"] | null; shield: boolean },
): { bonus: number; parts: string[] } {
  let bonus = 0;
  const parts: string[] = [];
  if (effects.has("fast_movement") && worn.armorCategory !== "heavy") {
    bonus += 10;
    parts.push("Fast Movement +10");
  }
  const monk = effects.get("unarmored_movement");
  if (monk != null && worn.armorCategory == null && !worn.shield) {
    const ft = monk >= 18 ? 30 : monk >= 14 ? 25 : monk >= 10 ? 20 : monk >= 6 ? 15 : 10;
    bonus += ft;
    parts.push(`Unarmored Movement +${ft}`);
  }
  if (effects.has("mobile")) {
    bonus += 10;
    parts.push("Mobile +10");
  }
  return { bonus, parts };
}

/**
 * Hit points features add to the maximum: Draconic Resilience, +1 per
 * sorcerer level, and Tough, +2 per character level. They stack: different
 * sources, and the books never say otherwise.
 */
export function hpBonus(effects: EffectLevels): { bonus: number; parts: string[] } {
  let bonus = 0;
  const parts: string[] = [];
  const sorcerer = effects.get("draconic_resilience");
  if (sorcerer != null) {
    bonus += sorcerer;
    parts.push(`Draconic Resilience +${sorcerer}`);
  }
  const level = effects.get("tough");
  if (level != null) {
    bonus += 2 * level;
    parts.push(`Tough +${2 * level}`);
  }
  return { bonus, parts };
}

// ---------- feature pick allowances (122) ----------

/**
 * How many picks a feature allows at a class level. No allowance rows means
 * one pick (a Fighting Style). Otherwise the total of the highest row at or
 * below the level, or 0 before the first. One rule in two places with 122's
 * feature_picks_allowed(); change them together.
 */
export function picksAllowed(
  steps: readonly { level: number; total: number }[],
  classLevel: number,
): number {
  if (steps.length === 0) return 1;
  const reached = steps.filter((s) => s.level <= classLevel);
  if (reached.length === 0) return 0;
  return reached.reduce((a, b) => (b.level > a.level ? b : a)).total;
}

// ---------------------------------------------------------------------------
// Use counters (153)
// ---------------------------------------------------------------------------

/**
 * How a counter's maximum is worked out. One list in two places with the
 * CHECK on feature_resources.formula (153). resourceMax is the maths.
 */
export const RESOURCE_FORMULAS = ["steps", "proficiency", "level", "ability"] as const;
export type ResourceFormula = (typeof RESOURCE_FORMULAS)[number];

export const RESOURCE_RECHARGES = ["short", "long"] as const;
/** 'short' recharges on a short or a long rest; 'long' on a long rest only. */
export type ResourceRecharge = (typeof RESOURCE_RECHARGES)[number];

/** The rule for one counter, as feature_resources stores it. */
export interface ResourceRule {
  formula: ResourceFormula;
  /** Set exactly when formula is 'ability' (153's CHECK). */
  ability: Ability | null;
  multiplier: number;
  bonus: number;
  /** For 'steps': from each level on, this many uses. */
  steps: readonly { level: number; total: number }[];
  recharge: ResourceRecharge;
  /** From this class level on, a 'long' counter recharges on a short rest. */
  shortRestFrom: number | null;
}

/**
 * A counter's maximum for one character. `level` is the granting class's
 * level for a class feature, the character's total level for a feat.
 *
 * 'steps' uses picksAllowed's step rule: the highest step at or below the
 * level, or 0 before the first. A 0 means the counter isn't shown yet.
 * Every other formula has a floor of 1, the book's "(minimum of once)".
 */
export function resourceMax(
  rule: Pick<ResourceRule, "formula" | "ability" | "multiplier" | "bonus" | "steps">,
  ctx: { level: number; pb: number; mods: Readonly<Record<Ability, number>> },
): number {
  switch (rule.formula) {
    case "steps": {
      const reached = rule.steps.filter((s) => s.level <= ctx.level);
      if (reached.length === 0) return 0;
      return reached.reduce((a, b) => (b.level > a.level ? b : a)).total;
    }
    case "proficiency":
      return Math.max(1, ctx.pb * rule.multiplier + rule.bonus);
    case "level":
      return Math.max(1, ctx.level * rule.multiplier + rule.bonus);
    case "ability":
      // 153's CHECK means a null here can't come from the database.
      return Math.max(1, (rule.ability ? ctx.mods[rule.ability] : 0) * rule.multiplier + rule.bonus);
  }
}

/** Which rest refills a counter at this level (Font of Inspiration, 5th). */
export function resourceRecharge(
  rule: Pick<ResourceRule, "recharge" | "shortRestFrom">,
  level: number,
): ResourceRecharge {
  return rule.shortRestFrom != null && level >= rule.shortRestFrom ? "short" : rule.recharge;
}

/**
 * The counters a rest clears. A long rest clears every counter, since each
 * recharges on one. A short rest clears only the short-rest ones.
 */
export function keysClearedByRest(
  counters: readonly { key: string; recharge: ResourceRecharge }[],
  rest: ResourceRecharge,
): string[] {
  return counters.filter((c) => rest === "long" || c.recharge === "short").map((c) => c.key);
}

// ---------------------------------------------------------------------------
// Spell slots (158)
// ---------------------------------------------------------------------------

/** One list in two places with the CHECK on classes/subclasses.caster_type. */
export const CASTER_TYPES = ["full", "half", "half_up", "third", "pact"] as const;
export type CasterType = (typeof CASTER_TYPES)[number];

// The PHB's Spellcaster table: slots per spell level (index 0 = 1st) for a
// full caster of each level (index 0 = 1st).
const FULL_CASTER_SLOTS: readonly (readonly number[])[] = [
  [2],
  [3],
  [4, 2],
  [4, 3],
  [4, 3, 2],
  [4, 3, 3],
  [4, 3, 3, 1],
  [4, 3, 3, 2],
  [4, 3, 3, 3, 1],
  [4, 3, 3, 3, 2],
  [4, 3, 3, 3, 2, 1],
  [4, 3, 3, 3, 2, 1],
  [4, 3, 3, 3, 2, 1, 1],
  [4, 3, 3, 3, 2, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 2, 1, 1],
];

/**
 * Spell slots for a single-class caster of a class level, index 0 = 1st
 * level. Empty for no slots (a non-caster, a Paladin at 1st, Pact Magic,
 * which is pactSlots).
 *
 * The half and third tables in the PHB and Tasha's are the full table read at
 * the level divided and rounded up, from the level each class starts casting:
 * a Paladin 5 has a full caster 3's slots, an Eldritch Knight 7 a full
 * caster 3's. rules.test.ts checks this against the printed tables.
 */
export function spellSlots(type: CasterType | null, classLevel: number): readonly number[] {
  const at = (n: number) => FULL_CASTER_SLOTS[Math.min(20, n) - 1] ?? [];
  switch (type) {
    case "full":
      return classLevel >= 1 ? at(classLevel) : [];
    case "half":
      return classLevel >= 2 ? at(Math.ceil(classLevel / 2)) : [];
    case "half_up":
      return classLevel >= 1 ? at(Math.ceil(classLevel / 2)) : [];
    case "third":
      return classLevel >= 3 ? at(Math.ceil(classLevel / 3)) : [];
    case "pact":
    case null:
      return [];
  }
}

/**
 * Pact Magic (Warlock): how many slots, all of one level, back on a short
 * rest. Null below 1st level.
 */
export function pactSlots(warlockLevel: number): { count: number; slotLevel: number } | null {
  if (warlockLevel < 1) return null;
  const count = warlockLevel >= 17 ? 4 : warlockLevel >= 11 ? 3 : warlockLevel >= 2 ? 2 : 1;
  const slotLevel = Math.min(5, Math.ceil(warlockLevel / 2));
  return { count, slotLevel };
}

/** "1st", "2nd", "3rd", "4th"... for a spell level. */
export function ordinal(n: number): string {
  return n === 1 ? "1st" : n === 2 ? "2nd" : n === 3 ? "3rd" : `${n}th`;
}

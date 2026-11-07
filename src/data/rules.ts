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
  // 164: Hill Dwarf (on its subrace), Half-Orc and Dwarf (on the race).
  "dwarven_toughness",
  "savage_attacks",
  "heavy_armor_speed",
  // 167: the Battle Smith's companion (steelDefender below).
  "steel_defender",
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
 * Every extra weapon die a melee crit rolls: Brutal Critical's, plus one for
 * Savage Attacks (Half-Orc). They stack: different sources, and the books
 * never say otherwise. `parts` names each for the attack legend.
 */
export function meleeCritExtraDice(effects: EffectLevels): { dice: number; parts: string[] } {
  const parts: string[] = [];
  const brutal = brutalCriticalDice(effects);
  if (brutal > 0) parts.push(`Brutal Critical +${brutal}`);
  const savage = effects.has("savage_attacks") ? 1 : 0;
  if (savage) parts.push("Savage Attacks +1");
  return { dice: brutal + savage, parts };
}

// ---------- weapon proficiency (161) ----------
//
// A class knows a whole category ('simple', 'martial', or 'none') plus a list
// of named weapons (a Rogue's rapier, a Wizard's five). Names are the shared
// weapon rows' names; a magic weapon is matched by its base weapon's name, so
// the caller passes that (proficiencyName in services/items.ts).

export type WeaponTrainingLevel = "none" | "simple" | "martial";

const TRAINING_RANK: Record<WeaponTrainingLevel, number> = {
  none: 0,
  simple: 1,
  martial: 2,
};

export interface ClassWeaponsLike {
  name: string;
  weaponTraining: WeaponTrainingLevel;
  weaponProficiencies: readonly string[];
  /** The PHB multiclass table grants this class's weapons to a second class. */
  multiclassGrantsWeapons: boolean;
}

export interface WeaponProficiencies {
  /** The widest whole category known, and what gave it. */
  category: WeaponTrainingLevel;
  categorySource: string | null;
  /** Named weapons, each with its source: a class name, or "added". */
  named: ReadonlyMap<string, string>;
}

/**
 * Every weapon a character is proficient with. The starting class gives its
 * whole list. A later class gives its list only when the PHB's multiclass
 * table says so (Barbarian, Fighter, Paladin, Ranger, Monk, Warlock); a Rogue
 * dip gives no rapiers. Battle Ready raises the category to martial.
 * `extras` are the character's own 'weapon' proficiency rows (a feat, a race,
 * the DM's say-so), keyed by weapon name.
 *
 * When two sources grant the same thing, the first one named wins: classes
 * before extras, so an extra that a class already covers reads as the class.
 */
export function weaponProficiencies(
  classes: readonly { cls: ClassWeaponsLike; isStarting: boolean }[],
  extras: readonly string[],
  effects: EffectLevels,
  /** The race's and subrace's weapons (164), each with its source: raceGrants. */
  racial: ReadonlyMap<string, string> = new Map(),
): WeaponProficiencies {
  let category: WeaponTrainingLevel = "none";
  let categorySource: string | null = null;
  const named = new Map<string, string>();
  const raise = (to: WeaponTrainingLevel, source: string) => {
    if (TRAINING_RANK[to] > TRAINING_RANK[category]) {
      category = to;
      categorySource = source;
    }
  };

  for (const { cls, isStarting } of classes) {
    if (!isStarting && !cls.multiclassGrantsWeapons) continue;
    raise(cls.weaponTraining, cls.name);
    for (const w of cls.weaponProficiencies) if (!named.has(w)) named.set(w, cls.name);
  }
  if (effects.has("battle_ready")) raise("martial", "Battle Ready");
  for (const [w, source] of racial) if (!named.has(w)) named.set(w, source);
  for (const w of extras) if (!named.has(w)) named.set(w, "added");
  return { category, categorySource, named };
}

/** Whether a whole category covers this weapon: martial covers simple too. */
export function categoryCovers(
  training: WeaponTrainingLevel,
  weaponCategory: "simple" | "martial",
): boolean {
  return TRAINING_RANK[training] >= TRAINING_RANK[weaponCategory];
}

/**
 * Proficiency with one weapon, and where it comes from. `name` is the name
 * proficiency is with: the base weapon's for a magic one. The category is
 * asked first, so a Fighter's longsword reads "Fighter", not "added".
 */
export function weaponProficiency(
  weapon: { name: string; category: "simple" | "martial" },
  profs: WeaponProficiencies,
): { proficient: boolean; source: string | null } {
  if (categoryCovers(profs.category, weapon.category)) {
    return { proficient: true, source: profs.categorySource };
  }
  const source = profs.named.get(weapon.name) ?? null;
  return { proficient: source != null, source };
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
 * One weapon's attack: the ability it uses, to-hit, the damage modifier and
 * the dice. Martial Arts may swap in DEX and its die; Battle Ready may swap
 * in INT on a magic weapon; Archery adds to a ranged weapon's to-hit; a
 * magic weapon's bonus (161) adds to both to-hit and damage.
 *
 * `weapon.name` is the base weapon's name, as for proficiency, so a +1
 * Shortsword is still a monk weapon. `hitParts` says where the to-hit came
 * from, as armorClass's parts do for AC.
 */
export function weaponAttack(opts: {
  weapon: MonkWeaponLike & { isMagic: boolean; magicBonus?: number };
  mods: { readonly str: number; readonly dex: number; readonly int: number };
  pb: number;
  proficient: boolean;
  styles: readonly FightingStyleKey[];
  effects: EffectLevels;
  /** No body armour and no shield: the condition Martial Arts needs. */
  unarmored: boolean;
}): {
  ability: Ability;
  toHit: number;
  damageMod: number;
  dice: string;
  hitParts: string[];
} {
  const { weapon, mods, pb, proficient, styles, effects, unarmored } = opts;
  const ma = martialArtsWeapon(weapon, martialArtsDie(effects), unarmored);
  const base: Ability = ma.finesse
    ? mods.dex > mods.str
      ? "dex"
      : "str"
    : weaponAbility(weapon, mods.str, mods.dex);
  const ability = battleReadyAbility(base, mods, weapon.isMagic, effects);
  const abilityMod = ability === "int" ? mods.int : ability === "dex" ? mods.dex : mods.str;
  const style = styleAttackBonus(weapon, styles);
  const magic = weapon.magicBonus ?? 0;

  const hitParts = [`${ability.toUpperCase()} ${formatModifier(abilityMod)}`];
  if (proficient) hitParts.push(`proficiency ${formatModifier(pb)}`);
  if (style) hitParts.push(`Archery ${formatModifier(style)}`);
  if (magic) hitParts.push(`magic ${formatModifier(magic)}`);

  return {
    ability,
    toHit: abilityMod + (proficient ? pb : 0) + style + magic,
    damageMod: abilityMod + magic,
    dice: ma.dice,
    hitParts,
  };
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
  const dwarf = effects.get("dwarven_toughness");
  if (dwarf != null) {
    bonus += dwarf;
    parts.push(`Dwarven Toughness +${dwarf}`);
  }
  return { bonus, parts };
}

/**
 * Whether heavy armour slows this character: worn without the Strength it
 * asks for (−10 ft, PHB), unless they're a Dwarf (heavy_armor_speed).
 */
export function heavyArmorSlows(
  strengthRequirement: number | null | undefined,
  strScore: number,
  effects: EffectLevels,
): boolean {
  if (strengthRequirement == null || effects.has("heavy_armor_speed")) return false;
  return strScore < strengthRequirement;
}

// ---------- racial grants (164) ----------
//
// What a race and its subrace give, read off the catalogue every render the
// way class weapon lists are (161). Nothing is written to the character, so
// changing race needs no cleanup. A subrace only adds: its lists are unioned
// with the race's, its speed replaces the race's when set, and the better
// darkvision wins (Drow's 120 over the Elf's 60).

export interface RaceGrantsLike {
  name: string;
  /** Null on a subrace means "the race's". */
  speed: number | null;
  darkvision: number | null;
  skillProficiencies: readonly string[];
  weaponProficiencies: readonly string[];
  armorProficiencies: readonly string[];
  toolProficiencies: readonly string[];
  languages: readonly string[];
  resistances: readonly string[];
}

export interface RaceGrants {
  speed: number | null;
  darkvision: number | null;
  /** Each granted skill with the race or subrace that grants it. */
  skills: ReadonlyMap<SkillKey, string>;
  /** Each weapon name with its source, for weaponProficiencies. */
  weapons: ReadonlyMap<string, string>;
  armor: readonly string[];
  tools: readonly string[];
  languages: readonly string[];
  resistances: readonly string[];
}

const SKILL_KEYS: ReadonlySet<string> = new Set(SKILLS.map((s) => s.key));

export function raceGrants(
  race: RaceGrantsLike | null,
  subrace: RaceGrantsLike | null,
): RaceGrants {
  const sources = [race, subrace].filter((s): s is RaceGrantsLike => s != null);
  const union = (pick: (s: RaceGrantsLike) => readonly string[]) => [
    ...new Set(sources.flatMap(pick)),
  ];
  const sourced = <K extends string>(pick: (s: RaceGrantsLike) => readonly string[]) => {
    const out = new Map<K, string>();
    for (const s of sources) for (const k of pick(s)) if (!out.has(k as K)) out.set(k as K, s.name);
    return out;
  };
  const vision = sources.map((s) => s.darkvision).filter((d): d is number => d != null);

  const skills = sourced<SkillKey>((s) => s.skillProficiencies);
  // 164's CHECK keeps unknown codes out; this keeps a stray one off the map.
  for (const k of skills.keys()) if (!SKILL_KEYS.has(k)) skills.delete(k);

  return {
    speed: subrace?.speed ?? race?.speed ?? null,
    darkvision: vision.length > 0 ? Math.max(...vision) : null,
    skills,
    weapons: sourced((s) => s.weaponProficiencies),
    armor: union((s) => s.armorProficiencies),
    tools: union((s) => s.toolProficiencies),
    languages: union((s) => s.languages),
    resistances: union((s) => s.resistances),
  };
}

/**
 * A skill's level once the race is counted: a granted skill is at least
 * proficient. A stored row can still raise it to expertise.
 */
export function effectiveSkillLevel(stored: ProficiencyLevel, granted: boolean): ProficiencyLevel {
  return granted && stored === 0 ? 1 : stored;
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
// Companions (167)
// ---------------------------------------------------------------------------

/** One entry in a companion's stat block: what it can do, and when. */
export interface CompanionAction {
  timing: "Action" | "Reaction" | "Trait";
  name: string;
  detail: string;
}

/**
 * Every number a steel defender's stat block derives. Only its name, damage
 * and temp HP are stored (character_companions); the rest is this.
 */
export interface SteelDefenderBlock {
  maxHp: number;
  ac: number;
  acNote: string;
  speed: number;
  hitDice: string;
  scores: Readonly<Record<Ability, number>>;
  saves: readonly { ability: Ability; bonus: number }[];
  skills: readonly { name: string; bonus: number }[];
  passivePerception: number;
  senses: string;
  damageImmunities: string;
  conditionImmunities: string;
  languages: string;
  actions: readonly CompanionAction[];
}

// Tasha's stat block. The scores are fixed; everything that grows reads the
// artificer's level, Intelligence and proficiency bonus.
const STEEL_DEFENDER_SCORES: Readonly<Record<Ability, number>> = {
  str: 14,
  dex: 12,
  con: 14,
  int: 4,
  wis: 10,
  cha: 6,
};

/**
 * The steel defender of an artificer at `artificerLevel` (the steel_defender
 * effect's level: the Artificer class's own level, not total level, so a
 * multiclass character's defender is the right size). `pb` is the
 * character's proficiency bonus, which "it uses", and its attack uses the
 * artificer's spell attack, which is always INT.
 *
 * Improved Defender (15th) and Arcane Jolt (9th) are Battle Smith features at
 * fixed levels of the same class, so they're read off the same level rather
 * than off their own keys, the way Extra Attack's later steps are.
 */
export function steelDefender(
  artificerLevel: number,
  ctx: { intMod: number; pb: number },
): SteelDefenderBlock {
  const { intMod, pb } = ctx;
  const improved = artificerLevel >= 15;
  const mods = Object.fromEntries(
    ABILITIES.map((a) => [a, abilityModifier(STEEL_DEFENDER_SCORES[a])]),
  ) as Record<Ability, number>;
  const perception = mods.wis + pb * 2;
  const jolt = improved ? "4d6" : "2d6";

  const actions: CompanionAction[] = [
    { timing: "Trait", name: "Vigilant", detail: "It can't be surprised." },
    {
      timing: "Trait",
      name: "Mending",
      detail: "It regains 2d6 hit points when the mending spell is cast on it.",
    },
    {
      timing: "Action",
      name: "Force-Empowered Rend",
      detail:
        `${formatModifier(pb + intMod)} to hit, reach 5 ft, one target it can see. ` +
        `Hit: ${damageString("1d8", pb)} force damage.` +
        (artificerLevel >= 9
          ? ` Arcane Jolt, once per turn on a hit: +${jolt} force damage, or a ` +
            `creature or object within 30 ft of the target regains ${jolt} HP.`
          : ""),
    },
    {
      timing: "Action",
      name: "Repair (3/day)",
      detail:
        `Restores ${damageString("2d8", pb)} hit points to itself or to one ` +
        "construct or object within 5 ft. Uses are counted under Resources.",
    },
    {
      timing: "Reaction",
      name: "Deflect Attack",
      detail:
        "Imposes disadvantage on one attack roll it can see against a creature " +
        "within 5 ft of it, other than itself." +
        (improved
          ? ` The attacker takes ${damageString("1d4", intMod)} force damage.`
          : ""),
    },
  ];

  return {
    maxHp: Math.max(1, 2 + intMod + 5 * artificerLevel),
    ac: improved ? 17 : 15,
    acNote: improved ? "Natural armor 15 · Improved Defender +2" : "Natural armor",
    speed: 40,
    hitDice: `${artificerLevel}d8`,
    scores: STEEL_DEFENDER_SCORES,
    saves: [
      { ability: "dex", bonus: mods.dex + pb },
      { ability: "con", bonus: mods.con + pb },
    ],
    skills: [
      { name: "Athletics", bonus: mods.str + pb },
      { name: "Perception", bonus: perception },
    ],
    passivePerception: 10 + perception,
    senses: "Darkvision 60 ft",
    damageImmunities: "Poison",
    conditionImmunities: "Charmed, exhaustion, poisoned",
    languages: "Understands the languages you speak",
    actions,
  };
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

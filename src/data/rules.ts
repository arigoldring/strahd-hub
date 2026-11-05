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
}): { total: number; parts: string[] } {
  const { armor, shield, dexMod, unarmored, styles, bonus } = opts;
  const parts: string[] = [];
  let total: number;

  if (armor) {
    const dex =
      armor.category === "heavy"
        ? 0
        : armor.category === "medium"
          ? Math.min(dexMod, 2)
          : dexMod;
    total = armor.baseArmorClass + dex;
    parts.push(`${armor.name} ${armor.baseArmorClass}`);
    if (armor.category !== "heavy") parts.push(`DEX ${formatModifier(dex)}`);
  } else {
    const ud = unarmored && (unarmored.allowsShield || !shield) ? unarmored : null;
    total = 10 + dexMod + (ud?.mod ?? 0);
    parts.push("10", `DEX ${formatModifier(dexMod)}`);
    if (ud) parts.push(`${ud.ability.toUpperCase()} ${formatModifier(ud.mod)}`);
  }

  if (shield) {
    total += shield.baseArmorClass;
    parts.push(`${shield.name} +${shield.baseArmorClass}`);
  }
  if (armor && styles.includes("defense")) {
    total += 1;
    parts.push("Defense +1");
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

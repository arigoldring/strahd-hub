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

/** The only abilities any class casts with. */
export const SPELL_ABILITIES = ["int", "wis", "cha"] as const;
export type SpellAbility = (typeof SPELL_ABILITIES)[number];

/**
 * The twelve PHB classes.
 *
 * - saves: the two saving throws the class is proficient in.
 * - spellAbility: what it casts with. Null for the non-casters, including
 *   Fighter and Rogue, whose casting comes from a subclass.
 * - hitDie: the die size, for hit dice and the average-HP hint.
 * - weapons: "martial" means simple + martial. An approximation — Rogues get
 *   rapiers, Monks shortswords, Wizards only a short list — which is why the
 *   sheet lets each weapon's proficiency be toggled by hand.
 * - unarmored: the ability a class adds to 10 + DEX with no armour on
 *   (Unarmored Defense). Strictly a class feature, but it changes the AC
 *   number, so it lives here rather than waiting for features.
 */
export const CLASSES = [
  { name: "Barbarian", saves: ["str", "con"], spellAbility: null, hitDie: 12, weapons: "martial", unarmored: "con" },
  { name: "Bard", saves: ["dex", "cha"], spellAbility: "cha", hitDie: 8, weapons: "simple", unarmored: null },
  { name: "Cleric", saves: ["wis", "cha"], spellAbility: "wis", hitDie: 8, weapons: "simple", unarmored: null },
  { name: "Druid", saves: ["int", "wis"], spellAbility: "wis", hitDie: 8, weapons: "simple", unarmored: null },
  { name: "Fighter", saves: ["str", "con"], spellAbility: null, hitDie: 10, weapons: "martial", unarmored: null },
  { name: "Monk", saves: ["str", "dex"], spellAbility: null, hitDie: 8, weapons: "simple", unarmored: "wis" },
  { name: "Paladin", saves: ["wis", "cha"], spellAbility: "cha", hitDie: 10, weapons: "martial", unarmored: null },
  { name: "Ranger", saves: ["str", "dex"], spellAbility: "wis", hitDie: 10, weapons: "martial", unarmored: null },
  { name: "Rogue", saves: ["dex", "int"], spellAbility: null, hitDie: 8, weapons: "simple", unarmored: null },
  { name: "Sorcerer", saves: ["con", "cha"], spellAbility: "cha", hitDie: 6, weapons: "simple", unarmored: null },
  { name: "Warlock", saves: ["wis", "cha"], spellAbility: "cha", hitDie: 8, weapons: "simple", unarmored: null },
  { name: "Wizard", saves: ["int", "wis"], spellAbility: "int", hitDie: 6, weapons: "simple", unarmored: null },
] as const satisfies readonly {
  name: string;
  saves: readonly [Ability, Ability];
  spellAbility: SpellAbility | null;
  hitDie: 6 | 8 | 10 | 12;
  weapons: "simple" | "martial";
  unarmored: Ability | null;
}[];
export type ClassName = (typeof CLASSES)[number]["name"];
export type ClassInfo = (typeof CLASSES)[number];

/**
 * The nine PHB (2014) races and their base walking speed. Picking one sets
 * the sheet's speed; it stays editable for subraces (Wood Elf, 35 ft) and
 * feats (Mobile). Ability score increases are deliberately not applied — the
 * scores are typed in as final values.
 */
export const RACES = [
  { name: "Dragonborn", speed: 30 },
  { name: "Dwarf", speed: 25 },
  { name: "Elf", speed: 30 },
  { name: "Gnome", speed: 25 },
  { name: "Half-Elf", speed: 30 },
  { name: "Half-Orc", speed: 30 },
  { name: "Halfling", speed: 25 },
  { name: "Human", speed: 30 },
  { name: "Tiefling", speed: 30 },
] as const satisfies readonly { name: string; speed: number }[];
export type RaceName = (typeof RACES)[number]["name"];

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
 * Unarmored Defense (Barbarian CON, Monk WIS) replaces the plain 10 + DEX —
 * except a Monk loses it with a shield.
 *
 * Returns the parts as well as the total, so the sheet can say where the
 * number came from rather than just print it.
 */
export function armorClass(opts: {
  armor: ArmorLike | null;
  shield: ArmorLike | null;
  dexMod: number;
  cls: ClassInfo | null;
  unarmoredMod: number;
  bonus: number;
}): { total: number; parts: string[] } {
  const { armor, shield, dexMod, cls, unarmoredMod, bonus } = opts;
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
    const unarmored =
      cls?.unarmored && !(cls.name === "Monk" && shield) ? unarmoredMod : null;
    total = 10 + dexMod + (unarmored ?? 0);
    parts.push("10", `DEX ${formatModifier(dexMod)}`);
    if (unarmored !== null) {
      parts.push(`${cls!.unarmored!.toUpperCase()} ${formatModifier(unarmored)}`);
    }
  }

  if (shield) {
    total += shield.baseArmorClass;
    parts.push(`${shield.name} +${shield.baseArmorClass}`);
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
 * Which ability a weapon attacks with. Ranged weapons use DEX; finesse
 * weapons use whichever of STR and DEX is better; everything else is STR.
 * "Ranged" means it has a range and is not merely thrown — a dagger has a
 * range too, but it's a melee weapon you can throw.
 */
export function weaponAbility(
  weapon: WeaponLike,
  strMod: number,
  dexMod: number,
): Ability {
  const ranged =
    weapon.rangeNormal != null && !weapon.properties.includes("thrown");
  if (ranged) return "dex";
  if (weapon.properties.includes("finesse")) {
    return dexMod > strMod ? "dex" : "str";
  }
  return "str";
}

/** "1d8" + 3 → "1d8+3"; a zero modifier is left off. */
export function damageString(dice: string, mod: number): string {
  if (mod === 0) return dice;
  return `${dice}${mod > 0 ? "+" : "−"}${Math.abs(mod)}`;
}

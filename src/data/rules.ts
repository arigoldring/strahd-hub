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
 * The Fighting Style options (079). One list in two places with the CHECK on
 * character_classes.fighting_style: change them together, as with SKILLS.
 * Display only for now: nothing below feeds armorClass or the attack rows yet.
 */
export const FIGHTING_STYLES = [
  {
    key: "archery",
    name: "Archery",
    source: "phb",
    description: "You gain a +2 bonus to attack rolls you make with ranged weapons.",
  },
  {
    key: "defense",
    name: "Defense",
    source: "phb",
    description: "While you are wearing armor, you gain a +1 bonus to AC.",
  },
  {
    key: "dueling",
    name: "Dueling",
    source: "phb",
    description:
      "When you are wielding a melee weapon in one hand and no other weapons, you gain a +2 bonus to damage rolls with that weapon.",
  },
  {
    key: "great_weapon",
    name: "Great Weapon Fighting",
    source: "phb",
    description:
      "When you roll a 1 or 2 on a damage die for an attack you make with a melee weapon that you are wielding with two hands, you can reroll the die and must use the new roll. The weapon must have the two-handed or versatile property.",
  },
  {
    key: "protection",
    name: "Protection",
    source: "phb",
    description:
      "When a creature you can see attacks a target other than you that is within 5 feet of you, you can use your reaction to impose disadvantage on the attack roll. You must be wielding a shield.",
  },
  {
    key: "two_weapon",
    name: "Two-Weapon Fighting",
    source: "phb",
    description:
      "When you engage in two-weapon fighting, you can add your ability modifier to the damage of the second attack.",
  },
  {
    key: "blind_fighting",
    name: "Blind Fighting",
    source: "tcoe",
    description:
      "You have blindsight with a range of 10 feet. Within that range, you can effectively see anything that isn't behind total cover, even if you're blinded or in darkness, and you can see an invisible creature unless it successfully hides from you.",
  },
  {
    key: "interception",
    name: "Interception",
    source: "tcoe",
    description:
      "When a creature you can see hits a target, other than you, within 5 feet of you with an attack, you can use your reaction to reduce the damage by 1d10 + your proficiency bonus. You must be wielding a shield or a simple or martial weapon.",
  },
  {
    key: "superior_technique",
    name: "Superior Technique",
    source: "tcoe",
    description:
      "You learn one maneuver from the Battle Master archetype (save DC 8 + proficiency bonus + Strength or Dexterity modifier). You gain one superiority die, a d6, regained on a short or long rest.",
  },
  {
    key: "thrown_weapon",
    name: "Thrown Weapon Fighting",
    source: "tcoe",
    description:
      "You can draw a weapon that has the thrown property as part of the attack you make with it. When you hit with a ranged attack using a thrown weapon, you gain a +2 bonus to the damage roll.",
  },
  {
    key: "unarmed",
    name: "Unarmed Fighting",
    source: "tcoe",
    description:
      "Your unarmed strikes deal 1d6 + Strength bludgeoning damage on a hit, or 1d8 if you aren't wielding any weapons or a shield. At the start of each of your turns, you can deal 1d4 bludgeoning damage to one creature grappled by you.",
  },
] as const satisfies readonly {
  key: string;
  name: string;
  source: "phb" | "tcoe";
  description: string;
}[];
export type FightingStyle = (typeof FIGHTING_STYLES)[number]["key"];
export const FIGHTING_STYLE_KEYS = FIGHTING_STYLES.map((s) => s.key);

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
 * Returns the parts as well as the total, so the sheet can say where the
 * number came from rather than just print it.
 */
export function armorClass(opts: {
  armor: ArmorLike | null;
  shield: ArmorLike | null;
  dexMod: number;
  unarmored: { ability: Ability; mod: number; allowsShield: boolean } | null;
  bonus: number;
}): { total: number; parts: string[] } {
  const { armor, shield, dexMod, unarmored, bonus } = opts;
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

/** A character's level is the sum of their class levels; 1 before any class. */
export function totalLevel(classes: readonly { level: number }[]): number {
  return Math.max(1, classes.reduce((sum, c) => sum + c.level, 0));
}

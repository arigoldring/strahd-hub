// The derived numbers on the sheet. rules.ts is pure (no React, no Supabase),
// which is why it's the first file with tests: each case is inputs in,
// number out, with nothing to mock.
import { describe, expect, it } from "vitest";
import {
  armorClass,
  attacksPerAction,
  battleReadyAbility,
  collectEffects,
  critThreshold,
  hpBonus,
  initiative,
  isMonkWeapon,
  isRangedWeapon,
  keysClearedByRest,
  martialArtsDie,
  martialArtsWeapon,
  picksAllowed,
  resourceMax,
  resourceRecharge,
  saveAura,
  sneakAttackDice,
  speedBonus,
  styleAttackBonus,
  untrainedCheckBonus,
  weaponAbility,
  weaponTraining,
  type ArmorLike,
  type EffectLevels,
  type FeatureEffect,
  type ResourceRule,
  type WeaponLike,
} from "./rules";

const chainMail: ArmorLike = { name: "Chain Mail", category: "heavy", baseArmorClass: 16 };
const leather: ArmorLike = { name: "Leather", category: "light", baseArmorClass: 11 };
const shield: ArmorLike = { name: "Shield", category: "shield", baseArmorClass: 2 };

const longbow: WeaponLike = { damageDice: "1d8", properties: ["ammunition", "heavy", "two-handed"], rangeNormal: 150 };
const dagger: WeaponLike = { damageDice: "1d4", properties: ["finesse", "light", "thrown"], rangeNormal: 20 };
const longsword: WeaponLike = { damageDice: "1d8", properties: ["versatile"] };

const ac = (opts: Partial<Parameters<typeof armorClass>[0]>) =>
  armorClass({ armor: null, shield: null, dexMod: 2, unarmored: null, styles: [], bonus: 0, ...opts });

describe("armorClass", () => {
  it("adds Defense's +1 while body armour is worn", () => {
    const { total, parts } = ac({ armor: chainMail, styles: ["defense"] });
    expect(total).toBe(17);
    expect(parts).toContain("Defense +1");
  });

  it("gives no Defense bonus for a shield alone", () => {
    expect(ac({ shield, styles: ["defense"] }).total).toBe(14);
  });

  it("gives no Defense bonus with Unarmored Defense", () => {
    const unarmored = { ability: "con" as const, mod: 3, allowsShield: true };
    expect(ac({ unarmored, styles: ["defense"] }).total).toBe(15);
  });

  it("counts a style held twice once", () => {
    expect(ac({ armor: chainMail, styles: ["defense", "defense"] }).total).toBe(17);
  });

  it("ignores styles with no AC effect", () => {
    expect(ac({ armor: leather, styles: ["archery"] }).total).toBe(13);
  });

  it("stacks armour, shield, Defense and the manual bonus", () => {
    const { total, parts } = ac({ armor: chainMail, shield, styles: ["defense"], bonus: 1 });
    expect(total).toBe(20);
    expect(parts).toEqual(["Chain Mail 16", "Shield +2", "Defense +1", "other +1"]);
  });
});

describe("ranged weapons", () => {
  it("treats a bow as ranged and a thrown dagger as melee", () => {
    expect(isRangedWeapon(longbow)).toBe(true);
    expect(isRangedWeapon(dagger)).toBe(false);
    expect(isRangedWeapon(longsword)).toBe(false);
  });

  it("gives Archery's +2 to ranged weapons only", () => {
    expect(styleAttackBonus(longbow, ["archery"])).toBe(2);
    expect(styleAttackBonus(dagger, ["archery"])).toBe(0);
    expect(styleAttackBonus(longsword, ["archery"])).toBe(0);
    expect(styleAttackBonus(longbow, ["defense"])).toBe(0);
  });

  it("agrees with weaponAbility about what is ranged", () => {
    // STR 3, DEX 1: a ranged weapon still uses DEX, finesse takes the better.
    expect(weaponAbility(longbow, 3, 1)).toBe("dex");
    expect(weaponAbility(dagger, 3, 1)).toBe("str");
    expect(weaponAbility(dagger, 1, 3)).toBe("dex");
    expect(weaponAbility(longsword, 1, 3)).toBe("str");
  });
});

// ---------- class feature effects (121) ----------

const fx = (pairs: [FeatureEffect, number][]): EffectLevels => new Map(pairs);
const none = fx([]);
const mods = { str: 3, dex: 2, con: 1, int: 0, wis: 4, cha: -1 };

describe("collectEffects", () => {
  const features = [
    { classId: "fighter", subclassId: null, level: 5, effect: "extra_attack_fighter" as const },
    { classId: "fighter", subclassId: "champion", level: 3, effect: "improved_critical" as const },
    { classId: "rogue", subclassId: null, level: 1, effect: "sneak_attack" as const },
    { classId: "fighter", subclassId: null, level: 1, effect: null },
  ];

  it("takes only features at or below the class's own level", () => {
    const e = collectEffects([{ classId: "fighter", subclassId: null, level: 4 }], features);
    expect(e.size).toBe(0);
  });

  it("takes subclass features only for the picked subclass", () => {
    const e = collectEffects(
      [{ classId: "fighter", subclassId: "battle_master", level: 5 }],
      features,
    );
    expect([...e.keys()]).toEqual(["extra_attack_fighter"]);
  });

  it("records the granting class's level, not the total", () => {
    const e = collectEffects(
      [
        { classId: "fighter", subclassId: "champion", level: 5 },
        { classId: "rogue", subclassId: null, level: 3 },
      ],
      features,
    );
    expect(e.get("sneak_attack")).toBe(3);
    expect(e.get("extra_attack_fighter")).toBe(5);
    expect(e.get("improved_critical")).toBe(5);
  });
});

describe("attacks", () => {
  it("counts the Fighter's tiers, and doesn't stack Extra Attack", () => {
    expect(attacksPerAction(none)).toBe(1);
    expect(attacksPerAction(fx([["extra_attack", 5]]))).toBe(2);
    expect(attacksPerAction(fx([["extra_attack_fighter", 11]]))).toBe(3);
    expect(attacksPerAction(fx([["extra_attack_fighter", 20]]))).toBe(4);
    expect(attacksPerAction(fx([["extra_attack", 5], ["extra_attack_fighter", 5]]))).toBe(2);
  });

  it("widens the crit range for the Champion", () => {
    expect(critThreshold(none)).toBe(20);
    expect(critThreshold(fx([["improved_critical", 3]]))).toBe(19);
    expect(critThreshold(fx([["improved_critical", 15], ["superior_critical", 15]]))).toBe(18);
  });

  it("scales Sneak Attack with rogue level", () => {
    expect(sneakAttackDice(none)).toBe(0);
    expect(sneakAttackDice(fx([["sneak_attack", 1]]))).toBe(1);
    expect(sneakAttackDice(fx([["sneak_attack", 6]]))).toBe(3);
    expect(sneakAttackDice(fx([["sneak_attack", 19]]))).toBe(10);
  });

  it("grows the Martial Arts die at 5th, 11th and 17th", () => {
    expect(martialArtsDie(none)).toBeNull();
    expect([1, 5, 11, 17].map((l) => martialArtsDie(fx([["martial_arts", l]])))).toEqual([4, 6, 8, 10]);
  });
});

describe("Martial Arts on weapons", () => {
  const shortsword = { name: "Shortsword", category: "martial", damageDice: "1d6", properties: ["finesse", "light"] };
  const quarterstaff = { name: "Quarterstaff", category: "simple", damageDice: "1d6", properties: ["versatile"] };
  const greatclub = { name: "Greatclub", category: "simple", damageDice: "1d8", properties: ["two-handed"] };
  const longsword = { name: "Longsword", category: "martial", damageDice: "1d8", properties: ["versatile"] };
  const shortbow = { name: "Shortbow", category: "simple", damageDice: "1d6", properties: ["ammunition", "two-handed"], rangeNormal: 80 };

  it("knows which weapons are monk weapons", () => {
    expect([shortsword, quarterstaff, greatclub, longsword, shortbow].map(isMonkWeapon)).toEqual([
      true, true, false, false, false,
    ]);
  });

  it("swaps in the die only when it is bigger, and only unarmoured", () => {
    expect(martialArtsWeapon(quarterstaff, 4, true)).toEqual({ finesse: true, dice: "1d6" });
    expect(martialArtsWeapon(quarterstaff, 8, true)).toEqual({ finesse: true, dice: "1d8" });
    expect(martialArtsWeapon(quarterstaff, 8, false)).toEqual({ finesse: false, dice: "1d6" });
    expect(martialArtsWeapon(longsword, 8, true)).toEqual({ finesse: false, dice: "1d8" });
    expect(martialArtsWeapon(quarterstaff, null, true)).toEqual({ finesse: false, dice: "1d6" });
  });
});

describe("Battle Ready", () => {
  const ready = fx([["battle_ready", 3]]);
  const smith = { str: 1, dex: 2, int: 4 };

  it("raises the class's training to martial", () => {
    expect(weaponTraining("simple", none)).toBe("simple");
    expect(weaponTraining("simple", ready)).toBe("martial");
    expect(weaponTraining(null, ready)).toBe("martial");
  });

  it("uses INT on a magic weapon only when INT is higher", () => {
    expect(battleReadyAbility("str", smith, true, ready)).toBe("int");
    expect(battleReadyAbility("dex", { str: 0, dex: 5, int: 4 }, true, ready)).toBe("dex");
    expect(battleReadyAbility("str", { str: 4, dex: 0, int: 4 }, true, ready)).toBe("str");
  });

  it("never touches a mundane weapon, or a character without the feature", () => {
    expect(battleReadyAbility("str", smith, false, ready)).toBe("str");
    expect(battleReadyAbility("str", smith, true, none)).toBe("str");
  });
});

describe("checks and initiative", () => {
  it("gives Jack of All Trades half proficiency, rounded down, on any check", () => {
    expect(untrainedCheckBonus("int", 3, fx([["jack_of_all_trades", 2]]))).toEqual({
      bonus: 1, source: "Jack of All Trades",
    });
  });

  it("gives Remarkable Athlete half, rounded up, on STR, DEX and CON only", () => {
    const e = fx([["remarkable_athlete", 7]]);
    expect(untrainedCheckBonus("str", 3, e).bonus).toBe(2);
    expect(untrainedCheckBonus("wis", 3, e).bonus).toBe(0);
  });

  it("doesn't stack the two; the better applies", () => {
    const e = fx([["jack_of_all_trades", 2], ["remarkable_athlete", 7]]);
    expect(untrainedCheckBonus("dex", 3, e)).toEqual({ bonus: 2, source: "Remarkable Athlete" });
    expect(untrainedCheckBonus("cha", 3, e)).toEqual({ bonus: 1, source: "Jack of All Trades" });
  });

  it("adds each subclass ability to initiative", () => {
    expect(initiative(mods, 2, none)).toEqual({ total: 2, parts: ["DEX +2"] });
    const e = fx([["dread_ambusher", 3], ["jack_of_all_trades", 2]]);
    expect(initiative(mods, 2, e)).toEqual({
      total: 7,
      parts: ["DEX +2", "Jack of All Trades +1", "Dread Ambusher +4"],
    });
    expect(initiative(mods, 2, fx([["rakish_audacity", 3]])).total).toBe(1);
  });
});

describe("saves, speed and hit points", () => {
  it("gives Aura of Protection CHA, minimum +1", () => {
    expect(saveAura(3, fx([["aura_of_protection", 6]]))).toBe(3);
    expect(saveAura(-1, fx([["aura_of_protection", 6]]))).toBe(1);
    expect(saveAura(3, none)).toBe(0);
  });

  it("gives Fast Movement +10 without heavy armour", () => {
    const e = fx([["fast_movement", 5]]);
    expect(speedBonus(e, { armorCategory: "medium", shield: true }).bonus).toBe(10);
    expect(speedBonus(e, { armorCategory: "heavy", shield: false }).bonus).toBe(0);
  });

  it("scales Unarmored Movement, and loses it to armour or a shield", () => {
    const at = (l: number) => speedBonus(fx([["unarmored_movement", l]]), { armorCategory: null, shield: false }).bonus;
    expect([2, 6, 10, 14, 18].map(at)).toEqual([10, 15, 20, 25, 30]);
    expect(speedBonus(fx([["unarmored_movement", 2]]), { armorCategory: null, shield: true }).bonus).toBe(0);
  });

  it("adds a hit point per sorcerer level for Draconic Resilience", () => {
    expect(hpBonus(fx([["draconic_resilience", 4]]))).toBe(4);
    expect(hpBonus(none)).toBe(0);
  });

  it("takes the better of Draconic Resilience and Unarmored Defense", () => {
    expect(ac({ natural: { name: "Draconic Resilience", base: 13 } }).total).toBe(15);
    expect(ac({ natural: { name: "Draconic Resilience", base: 13 }, shield }).total).toBe(17);
    const unarmored = { ability: "con" as const, mod: 3, allowsShield: true };
    expect(ac({ natural: { name: "Draconic Resilience", base: 13 }, unarmored }).total).toBe(15);
    expect(ac({ natural: { name: "Draconic Resilience", base: 13 }, armor: chainMail }).total).toBe(16);
  });
});

describe("picksAllowed", () => {
  const combatSuperiority = [
    { level: 3, total: 3 },
    { level: 7, total: 5 },
    { level: 10, total: 7 },
    { level: 15, total: 9 },
  ];
  it("allows one pick when a feature has no steps", () => {
    expect(picksAllowed([], 1)).toBe(1);
  });
  it("follows the steps, and allows none before the first", () => {
    expect([2, 3, 6, 7, 10, 14, 15, 20].map((l) => picksAllowed(combatSuperiority, l))).toEqual([
      0, 3, 3, 5, 7, 7, 9, 9,
    ]);
  });
});

describe("resourceMax", () => {
  const mods = { str: 3, dex: 1, con: -1, int: 0, wis: 2, cha: 4 };
  const ctx = (level: number, pb: number) => ({ level, pb, mods });
  const rule = (r: Partial<ResourceRule>): ResourceRule => ({
    formula: "steps",
    ability: null,
    multiplier: 1,
    bonus: 0,
    steps: [],
    recharge: "short",
    shortRestFrom: null,
    ...r,
  });

  it("follows steps, with none before the first (Action Surge)", () => {
    const actionSurge = rule({ steps: [{ level: 2, total: 1 }, { level: 17, total: 2 }] });
    expect([1, 2, 16, 17, 20].map((l) => resourceMax(actionSurge, ctx(l, 2)))).toEqual([
      0, 1, 1, 2, 2,
    ]);
  });

  it("reads steps in any order", () => {
    const indomitable = rule({
      steps: [{ level: 17, total: 3 }, { level: 9, total: 1 }, { level: 13, total: 2 }],
    });
    expect([9, 13, 17].map((l) => resourceMax(indomitable, ctx(l, 4)))).toEqual([1, 2, 3]);
  });

  it("scales proficiency with a multiplier (Psionic Energy dice)", () => {
    expect(resourceMax(rule({ formula: "proficiency", multiplier: 2 }), ctx(5, 3))).toBe(6);
  });

  it("scales class level (ki, Lay on Hands)", () => {
    expect(resourceMax(rule({ formula: "level" }), ctx(7, 3))).toBe(7);
    expect(resourceMax(rule({ formula: "level", multiplier: 5 }), ctx(7, 3))).toBe(35);
  });

  it("uses an ability modifier plus a bonus (Divine Sense)", () => {
    expect(resourceMax(rule({ formula: "ability", ability: "cha", bonus: 1 }), ctx(1, 2))).toBe(5);
  });

  it("floors every formula but steps at 1", () => {
    expect(resourceMax(rule({ formula: "ability", ability: "con" }), ctx(3, 2))).toBe(1);
    expect(resourceMax(rule({ formula: "ability", ability: "int" }), ctx(3, 2))).toBe(1);
  });
});

describe("resourceRecharge", () => {
  it("moves a long-rest counter to short rests from its level (Font of Inspiration)", () => {
    const bardic = { recharge: "long" as const, shortRestFrom: 5 };
    expect(resourceRecharge(bardic, 4)).toBe("long");
    expect(resourceRecharge(bardic, 5)).toBe("short");
  });
  it("leaves a counter with no such level alone", () => {
    expect(resourceRecharge({ recharge: "long", shortRestFrom: null }, 20)).toBe("long");
    expect(resourceRecharge({ recharge: "short", shortRestFrom: null }, 1)).toBe("short");
  });
});

describe("keysClearedByRest", () => {
  const counters = [
    { key: "a", recharge: "short" as const },
    { key: "b", recharge: "long" as const },
  ];
  it("clears short-rest counters on a short rest", () => {
    expect(keysClearedByRest(counters, "short")).toEqual(["a"]);
  });
  it("clears everything on a long rest", () => {
    expect(keysClearedByRest(counters, "long")).toEqual(["a", "b"]);
  });
});

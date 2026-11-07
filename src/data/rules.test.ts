// The derived numbers on the sheet. rules.ts is pure (no React, no Supabase),
// which is why it's the first file with tests: each case is inputs in,
// number out, with nothing to mock.
import { describe, expect, it } from "vitest";
import {
  armorClass,
  attacksPerAction,
  battleReadyAbility,
  brutalCriticalDice,
  collectEffects,
  critThreshold,
  effectiveSkillLevel,
  heavyArmorSlows,
  hpBonus,
  meleeCritExtraDice,
  raceGrants,
  initiative,
  isMonkWeapon,
  isRangedWeapon,
  keysClearedByRest,
  martialArtsDie,
  martialArtsWeapon,
  pactSlots,
  passiveBonus,
  picksAllowed,
  resourceMax,
  resourceRecharge,
  saveAura,
  sneakAttackDice,
  speedBonus,
  spellSlots,
  steelDefender,
  styleAttackBonus,
  untrainedCheckBonus,
  weaponAbility,
  weaponAttack,
  weaponProficiencies,
  weaponProficiency,
  type ArmorLike,
  type ClassWeaponsLike,
  type EffectLevels,
  type FeatureEffect,
  type RaceGrantsLike,
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

const wizard: ClassWeaponsLike = {
  name: "Wizard",
  weaponTraining: "none",
  weaponProficiencies: ["Dagger", "Dart", "Sling", "Quarterstaff", "Crossbow, Light"],
  multiclassGrantsWeapons: false,
};
const fighter: ClassWeaponsLike = {
  name: "Fighter",
  weaponTraining: "martial",
  weaponProficiencies: [],
  multiclassGrantsWeapons: true,
};
const rogue: ClassWeaponsLike = {
  name: "Rogue",
  weaponTraining: "simple",
  weaponProficiencies: ["Crossbow, Hand", "Longsword", "Rapier", "Shortsword"],
  multiclassGrantsWeapons: false,
};

describe("weaponProficiencies", () => {
  it("gives a wizard five named weapons and no category", () => {
    const p = weaponProficiencies([{ cls: wizard, isStarting: true }], [], none);
    expect(p.category).toBe("none");
    expect(weaponProficiency({ name: "Dagger", category: "simple" }, p)).toEqual({
      proficient: true,
      source: "Wizard",
    });
    expect(weaponProficiency({ name: "Club", category: "simple" }, p).proficient).toBe(false);
  });

  it("follows the multiclass table: a fighter dip grants martial, a rogue dip nothing", () => {
    const wizFighter = weaponProficiencies(
      [{ cls: wizard, isStarting: true }, { cls: fighter, isStarting: false }],
      [],
      none,
    );
    expect(wizFighter).toMatchObject({ category: "martial", categorySource: "Fighter" });

    const wizRogue = weaponProficiencies(
      [{ cls: wizard, isStarting: true }, { cls: rogue, isStarting: false }],
      [],
      none,
    );
    expect(wizRogue.category).toBe("none");
    expect(wizRogue.named.has("Rapier")).toBe(false);
  });

  it("gives a starting rogue its own list in full", () => {
    const p = weaponProficiencies([{ cls: rogue, isStarting: true }], [], none);
    expect(weaponProficiency({ name: "Rapier", category: "martial" }, p).source).toBe("Rogue");
    expect(weaponProficiency({ name: "Greatsword", category: "martial" }, p).proficient).toBe(false);
  });

  it("adds extras, but a class's grant names the source first", () => {
    const p = weaponProficiencies(
      [{ cls: rogue, isStarting: true }],
      ["Longsword", "Battleaxe"],
      none,
    );
    expect(p.named.get("Longsword")).toBe("Rogue");
    expect(p.named.get("Battleaxe")).toBe("added");
  });

  it("reads a covered weapon as the category's, not as an extra", () => {
    const p = weaponProficiencies([{ cls: fighter, isStarting: true }], ["Longsword"], none);
    expect(weaponProficiency({ name: "Longsword", category: "martial" }, p).source).toBe("Fighter");
  });

  it("knows nothing with no class", () => {
    const p = weaponProficiencies([], [], none);
    expect(weaponProficiency({ name: "Club", category: "simple" }, p).proficient).toBe(false);
  });
});

describe("weaponAttack", () => {
  const sword = { ...longsword, name: "Longsword", category: "martial", isMagic: false };
  const mods = { str: 3, dex: 1, int: 0 };
  const attack = (opts: Partial<Parameters<typeof weaponAttack>[0]>) =>
    weaponAttack({
      weapon: sword,
      mods,
      pb: 2,
      proficient: true,
      styles: [],
      effects: none,
      unarmored: false,
      ...opts,
    });

  it("is ability + proficiency to hit, ability to damage", () => {
    expect(attack({})).toMatchObject({ ability: "str", toHit: 5, damageMod: 3, dice: "1d8" });
    expect(attack({ proficient: false }).toHit).toBe(3);
  });

  it("adds a magic bonus to both to-hit and damage, and names it", () => {
    const r = attack({ weapon: { ...sword, isMagic: true, magicBonus: 2 } });
    expect(r).toMatchObject({ toHit: 7, damageMod: 5 });
    expect(r.hitParts).toEqual(["STR +3", "proficiency +2", "magic +2"]);
  });

  it("adds Archery only to a ranged weapon", () => {
    const bow = { ...longbow, name: "Longbow", category: "martial", isMagic: false };
    expect(attack({ weapon: bow, styles: ["archery"] })).toMatchObject({
      ability: "dex",
      toHit: 5,
      damageMod: 1,
    });
    expect(attack({ styles: ["archery"] }).toHit).toBe(5);
  });

  it("treats a +1 shortsword as a monk weapon by its base name", () => {
    const shortsword = {
      damageDice: "1d6",
      properties: ["finesse", "light"],
      name: "Shortsword",
      category: "martial",
      isMagic: true,
      magicBonus: 1,
    };
    const r = attack({
      weapon: shortsword,
      mods: { str: 0, dex: 4, int: 0 },
      effects: fx([["martial_arts", 11]]),
      unarmored: true,
    });
    expect(r).toMatchObject({ ability: "dex", dice: "1d8", toHit: 7, damageMod: 5 });
  });

  it("lets Battle Ready use INT on a magic weapon only", () => {
    const smith = { str: 1, dex: 0, int: 4 };
    const ready = fx([["battle_ready", 3]]);
    expect(attack({ mods: smith, effects: ready, weapon: { ...sword, isMagic: true } }).ability).toBe("int");
    expect(attack({ mods: smith, effects: ready }).ability).toBe("str");
  });
});

describe("Battle Ready", () => {
  const ready = fx([["battle_ready", 3]]);
  const smith = { str: 1, dex: 2, int: 4 };

  it("raises the class's training to martial", () => {
    const artificer = [{ cls: { ...wizard, name: "Artificer", weaponTraining: "simple" as const, weaponProficiencies: [] }, isStarting: true }];
    expect(weaponProficiencies(artificer, [], none).category).toBe("simple");
    expect(weaponProficiencies(artificer, [], ready)).toMatchObject({
      category: "martial",
      categorySource: "Battle Ready",
    });
    expect(weaponProficiencies([], [], ready).category).toBe("martial");
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
    expect(hpBonus(fx([["draconic_resilience", 4]]))).toEqual({
      bonus: 4,
      parts: ["Draconic Resilience +4"],
    });
    expect(hpBonus(none)).toEqual({ bonus: 0, parts: [] });
  });

  it("takes the better of Draconic Resilience and Unarmored Defense", () => {
    expect(ac({ natural: { name: "Draconic Resilience", base: 13 } }).total).toBe(15);
    expect(ac({ natural: { name: "Draconic Resilience", base: 13 }, shield }).total).toBe(17);
    const unarmored = { ability: "con" as const, mod: 3, allowsShield: true };
    expect(ac({ natural: { name: "Draconic Resilience", base: 13 }, unarmored }).total).toBe(15);
    expect(ac({ natural: { name: "Draconic Resilience", base: 13 }, armor: chainMail }).total).toBe(16);
  });
});

// ---------- race and feat effects (159) ----------

describe("race and feat effects", () => {
  const halfPlate: ArmorLike = { name: "Half Plate", category: "medium", baseArmorClass: 15 };

  it("collects race and feat keys at total level, from 1st", () => {
    const e = collectEffects(
      [
        { classId: "fighter", subclassId: null, level: 3 },
        { classId: "rogue", subclassId: null, level: 2 },
      ],
      [],
      ["integrated_protection", "tough", null],
    );
    expect(e.get("integrated_protection")).toBe(5);
    expect(e.get("tough")).toBe(5);
    expect(e.size).toBe(2);
  });

  it("adds Integrated Protection's +1 in armour or out of it", () => {
    const e = fx([["integrated_protection", 1]]);
    expect(ac({ effects: e })).toEqual({
      total: 13,
      parts: ["10", "DEX +2", "Integrated Protection +1"],
    });
    expect(ac({ armor: chainMail, shield, effects: e }).total).toBe(19);
  });

  it("raises the medium armour DEX cap to +3 with Medium Armor Master", () => {
    const e = fx([["medium_armor_master", 1]]);
    expect(ac({ armor: halfPlate, dexMod: 4 }).total).toBe(17);
    expect(ac({ armor: halfPlate, dexMod: 4, effects: e }).total).toBe(18);
    // Below DEX 16 the feat changes nothing, and it never touches heavy armour.
    expect(ac({ armor: halfPlate, dexMod: 2, effects: e }).total).toBe(17);
    expect(ac({ armor: chainMail, dexMod: 4, effects: e }).total).toBe(16);
  });

  it("adds Alert's +5 to initiative", () => {
    expect(initiative(mods, 2, fx([["alert", 1]]))).toEqual({
      total: 7,
      parts: ["DEX +2", "Alert +5"],
    });
  });

  it("adds Observant's +5 to passive Perception and Investigation only", () => {
    const e = fx([["observant", 1]]);
    expect(passiveBonus("perception", e)).toBe(5);
    expect(passiveBonus("investigation", e)).toBe(5);
    expect(passiveBonus("insight", e)).toBe(0);
    expect(passiveBonus("perception", none)).toBe(0);
  });

  it("adds Mobile's +10 whatever is worn", () => {
    const e = fx([["mobile", 1]]);
    expect(speedBonus(e, { armorCategory: "heavy", shield: true })).toEqual({
      bonus: 10,
      parts: ["Mobile +10"],
    });
  });

  it("adds Tough's 2 per level, stacking with Draconic Resilience", () => {
    expect(hpBonus(fx([["tough", 5]])).bonus).toBe(10);
    expect(hpBonus(fx([["tough", 5], ["draconic_resilience", 3]]))).toEqual({
      bonus: 13,
      parts: ["Draconic Resilience +3", "Tough +10"],
    });
  });

  it("scales Brutal Critical by barbarian level", () => {
    const at = (l: number) => brutalCriticalDice(fx([["brutal_critical", l]]));
    expect([9, 12, 13, 16, 17, 20].map(at)).toEqual([1, 1, 2, 2, 3, 3]);
    expect(brutalCriticalDice(none)).toBe(0);
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

  it("drops to 0, so the sheet hides it, when a step says so (Rage at 20th)", () => {
    const rage = rule({
      steps: [1, 3, 6, 12, 17, 20].map((level, i) => ({ level, total: [2, 3, 4, 5, 6, 0][i] })),
    });
    expect([1, 3, 17, 19, 20].map((l) => resourceMax(rage, ctx(l, 6)))).toEqual([2, 3, 6, 6, 0]);
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

describe("spellSlots", () => {
  it("reads the PHB Spellcaster table for a full caster", () => {
    expect(spellSlots("full", 1)).toEqual([2]);
    expect(spellSlots("full", 5)).toEqual([4, 3, 2]);
    expect(spellSlots("full", 17)).toEqual([4, 3, 3, 3, 2, 1, 1, 1, 1]);
    expect(spellSlots("full", 20)).toEqual([4, 3, 3, 3, 3, 2, 2, 1, 1]);
  });

  // The printed Paladin/Ranger table, level by level.
  it("matches the PHB half-caster table, with nothing at 1st", () => {
    const paladin: Record<number, number[]> = {
      1: [], 2: [2], 3: [3], 4: [3], 5: [4, 2], 6: [4, 2], 7: [4, 3], 8: [4, 3],
      9: [4, 3, 2], 10: [4, 3, 2], 11: [4, 3, 3], 12: [4, 3, 3], 13: [4, 3, 3, 1],
      14: [4, 3, 3, 1], 15: [4, 3, 3, 2], 16: [4, 3, 3, 2], 17: [4, 3, 3, 3, 1],
      18: [4, 3, 3, 3, 1], 19: [4, 3, 3, 3, 2], 20: [4, 3, 3, 3, 2],
    };
    for (const [level, slots] of Object.entries(paladin)) {
      expect(spellSlots("half", Number(level))).toEqual(slots);
    }
  });

  it("starts the Artificer's table at 1st", () => {
    expect(spellSlots("half_up", 1)).toEqual([2]);
    expect(spellSlots("half_up", 2)).toEqual([2]);
    expect(spellSlots("half_up", 5)).toEqual([4, 2]);
    expect(spellSlots("half_up", 20)).toEqual([4, 3, 3, 3, 2]);
  });

  // The printed Eldritch Knight table, level by level.
  it("matches the PHB third-caster table, from 3rd", () => {
    const knight: Record<number, number[]> = {
      2: [], 3: [2], 4: [3], 6: [3], 7: [4, 2], 9: [4, 2], 10: [4, 3], 12: [4, 3],
      13: [4, 3, 2], 15: [4, 3, 2], 16: [4, 3, 3], 18: [4, 3, 3], 19: [4, 3, 3, 1],
      20: [4, 3, 3, 1],
    };
    for (const [level, slots] of Object.entries(knight)) {
      expect(spellSlots("third", Number(level))).toEqual(slots);
    }
  });

  it("gives Pact Magic and non-casters no regular slots", () => {
    expect(spellSlots("pact", 10)).toEqual([]);
    expect(spellSlots(null, 10)).toEqual([]);
  });
});

describe("pactSlots", () => {
  it("follows the Warlock table", () => {
    expect(pactSlots(1)).toEqual({ count: 1, slotLevel: 1 });
    expect(pactSlots(2)).toEqual({ count: 2, slotLevel: 1 });
    expect(pactSlots(3)).toEqual({ count: 2, slotLevel: 2 });
    expect(pactSlots(9)).toEqual({ count: 2, slotLevel: 5 });
    expect(pactSlots(11)).toEqual({ count: 3, slotLevel: 5 });
    expect(pactSlots(17)).toEqual({ count: 4, slotLevel: 5 });
    expect(pactSlots(0)).toBeNull();
  });
});

describe("racial grants (164)", () => {
  const grant = (name: string, over: Partial<RaceGrantsLike> = {}): RaceGrantsLike => ({
    name,
    speed: null,
    darkvision: null,
    skillProficiencies: [],
    weaponProficiencies: [],
    armorProficiencies: [],
    toolProficiencies: [],
    languages: [],
    resistances: [],
    ...over,
  });
  const elf = grant("Elf", {
    speed: 30,
    darkvision: 60,
    skillProficiencies: ["perception"],
    languages: ["Common", "Elvish"],
  });
  const drow = grant("Drow", {
    darkvision: 120,
    weaponProficiencies: ["Rapier", "Shortsword", "Crossbow, Hand"],
  });
  const woodElf = grant("Wood Elf", { speed: 35, weaponProficiencies: ["Longsword"] });

  it("unions a subrace onto its race, the better darkvision winning", () => {
    const g = raceGrants(elf, drow);
    expect(g.darkvision).toBe(120);
    expect(g.speed).toBe(30);
    expect(g.skills.get("perception")).toBe("Elf");
    expect(g.weapons.get("Rapier")).toBe("Drow");
    expect(g.languages).toEqual(["Common", "Elvish"]);
  });

  it("takes a subrace's speed when it has one", () => {
    expect(raceGrants(elf, woodElf).speed).toBe(35);
    expect(raceGrants(elf, null).speed).toBe(30);
    expect(raceGrants(null, null)).toMatchObject({ speed: null, darkvision: null });
  });

  it("raises a racial skill to proficient but keeps stored expertise", () => {
    expect(effectiveSkillLevel(0, true)).toBe(1);
    expect(effectiveSkillLevel(2, true)).toBe(2);
    expect(effectiveSkillLevel(0, false)).toBe(0);
  });

  it("puts racial weapons after the class and before extras", () => {
    const g = raceGrants(elf, drow);
    const p = weaponProficiencies([{ cls: rogue, isStarting: true }], ["Rapier", "Whip"], none, g.weapons);
    // The rogue's own rapier reads as the class's, not the race's.
    expect(p.named.get("Rapier")).toBe("Rogue");
    expect(p.named.get("Crossbow, Hand")).toBe("Rogue");
    expect(p.named.get("Whip")).toBe("added");
    const wiz = weaponProficiencies([{ cls: wizard, isStarting: true }], [], none, g.weapons);
    expect(weaponProficiency({ name: "Rapier", category: "martial" }, wiz).source).toBe("Drow");
  });

  it("adds Dwarven Toughness's 1 per level", () => {
    expect(hpBonus(fx([["dwarven_toughness", 4]]))).toEqual({
      bonus: 4,
      parts: ["Dwarven Toughness +4"],
    });
  });

  it("stacks Savage Attacks with Brutal Critical", () => {
    expect(meleeCritExtraDice(fx([["savage_attacks", 1]]))).toEqual({
      dice: 1,
      parts: ["Savage Attacks +1"],
    });
    expect(meleeCritExtraDice(fx([["savage_attacks", 13], ["brutal_critical", 13]])).dice).toBe(3);
    expect(meleeCritExtraDice(none).dice).toBe(0);
  });

  it("lets a dwarf wear heavy armour without the Strength at full speed", () => {
    expect(heavyArmorSlows(15, 13, none)).toBe(true);
    expect(heavyArmorSlows(15, 13, fx([["heavy_armor_speed", 1]]))).toBe(false);
    expect(heavyArmorSlows(15, 15, none)).toBe(false);
    expect(heavyArmorSlows(null, 8, none)).toBe(false);
  });
});

describe("steelDefender (167)", () => {
  it("is built from the artificer's level, INT and proficiency at 3rd", () => {
    const d = steelDefender(3, { intMod: 3, pb: 2 });
    expect(d.maxHp).toBe(20); // 2 + 3 + 5 x 3
    expect(d.ac).toBe(15);
    expect(d.hitDice).toBe("3d8");
    expect(d.saves).toEqual([
      { ability: "dex", bonus: 3 },
      { ability: "con", bonus: 4 },
    ]);
    expect(d.skills).toEqual([
      { name: "Athletics", bonus: 4 },
      { name: "Perception", bonus: 4 }, // proficiency doubled
    ]);
    expect(d.passivePerception).toBe(14);
    const rend = d.actions.find((a) => a.name === "Force-Empowered Rend")!;
    expect(rend.detail).toContain("+5 to hit");
    expect(rend.detail).toContain("1d8+2 force");
    expect(rend.detail).not.toContain("Arcane Jolt");
    expect(d.actions.find((a) => a.name === "Deflect Attack")!.detail).not.toContain("attacker takes");
  });

  it("adds Arcane Jolt to Rend at 9th", () => {
    const rend = steelDefender(9, { intMod: 4, pb: 4 }).actions.find(
      (a) => a.name === "Force-Empowered Rend",
    )!;
    expect(rend.detail).toContain("+2d6 force");
  });

  it("gets Improved Defender at 15th: +2 AC, 4d6 jolts, Deflect Attack hits back", () => {
    const d = steelDefender(15, { intMod: 5, pb: 5 });
    expect(d.maxHp).toBe(82);
    expect(d.ac).toBe(17);
    expect(d.actions.find((a) => a.name === "Force-Empowered Rend")!.detail).toContain("+4d6 force");
    expect(d.actions.find((a) => a.name === "Deflect Attack")!.detail).toContain("1d4+5 force");
  });

  it("never has fewer than 1 hit point", () => {
    expect(steelDefender(0, { intMod: -5, pb: 2 }).maxHp).toBe(1);
  });
});

// The derived numbers on the sheet. rules.ts is pure (no React, no Supabase),
// which is why it's the first file with tests: each case is inputs in,
// number out, with nothing to mock.
import { describe, expect, it } from "vitest";
import {
  armorClass,
  isRangedWeapon,
  styleAttackBonus,
  weaponAbility,
  type ArmorLike,
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

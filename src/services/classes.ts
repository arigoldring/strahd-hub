import { supabase } from "../lib/supabase";
import { parseOneOf, requireField } from "../lib/parse";
import {
  ABILITIES,
  SPELL_ABILITIES,
  type Ability,
  type SpellAbility,
} from "../data/rules";
import type { Tables } from "../types/database.types";

/**
 * The class catalogue (054/055): the twelve PHB classes plus this campaign's
 * homebrew, the same shared-or-mine split as feats. Only the facts the sheet
 * computes with are typed narrowly; everything descriptive is `description`.
 */
export interface CharacterClass {
  id: string;
  name: string;
  description: string;
  hitDie: number;
  /** The two saving throws the class grants (054's CHECK: exactly two). */
  saves: Ability[];
  /** Null for classes that don't cast (or cast only via a subclass). */
  spellAbility: SpellAbility | null;
  /** "martial" means simple + martial. */
  weaponTraining: "simple" | "martial";
  /** Unarmored Defense: the ability added to 10 + DEX with no armour on. */
  unarmoredAbility: Ability | null;
  /** The level the subclass is chosen at. */
  subclassLevel: number;
  /** What this class calls its subclass: "Divine Domain", "Primal Path" (066). */
  subclassTitle: string;
  isHomebrew: boolean;
}

/**
 * A subclass (054, seeded by 067-078). spellAbility is set only where the
 * subclass casts and its class doesn't: Eldritch Knight, Arcane Trickster.
 */
export interface Subclass {
  id: string;
  classId: string;
  name: string;
  description: string;
  /** Null for homebrew. */
  source: SubclassSource | null;
  spellAbility: SpellAbility | null;
  isHomebrew: boolean;
}

/**
 * A class or subclass feature (079). subclassId null means the base class's
 * own (Second Wind); otherwise it belongs to that archetype.
 */
export interface ClassFeature {
  id: string;
  classId: string;
  subclassId: string | null;
  level: number;
  name: string;
  description: string;
  /**
   * The options this feature's picker offers, from class_feature_options
   * (095). Empty means the feature has no picker. Having options is what
   * makes a picker, so there's no separate flag that could disagree with it.
   * The sheet lists them in the catalogue's order, not this array's.
   */
  optionIds: string[];
  isHomebrew: boolean;
}

/**
 * Something a feature lets a character pick (095): a fighting style today.
 * `key` is what code gives an effect to (rules.ts); homebrew may have none.
 */
export interface FeatureOption {
  id: string;
  kind: FeatureOptionKind;
  key: string | null;
  name: string;
  description: string;
  /** Null for homebrew. */
  source: SubclassSource | null;
  isHomebrew: boolean;
}

// One list in two places with 095's CHECK on feature_options.kind.
export const FEATURE_OPTION_KINDS = ["fighting_style"] as const;
export type FeatureOptionKind = (typeof FEATURE_OPTION_KINDS)[number];

export const FEATURE_OPTION_KIND_LABELS: Record<FeatureOptionKind, string> = {
  fighting_style: "Fighting style",
};

const WEAPON_TRAINING = ["simple", "martial"] as const;

// One list in two places with 066's CHECK on subclasses.source; change them
// together, as with featCategories.
export const SUBCLASS_SOURCES = ["phb", "xgte", "tcoe"] as const;
export type SubclassSource = (typeof SUBCLASS_SOURCES)[number];

export const SUBCLASS_SOURCE_LABELS: Record<SubclassSource, string> = {
  phb: "PHB",
  xgte: "Xanathar's",
  tcoe: "Tasha's",
};

export function toCharacterClass(row: Tables<"classes">): CharacterClass {
  const subject = `Class ${row.id}`;
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    hitDie: row.hit_die,
    saves: row.save_proficiencies.map((s) =>
      parseOneOf(s, ABILITIES, "save_proficiencies", subject),
    ),
    spellAbility:
      row.spell_ability == null
        ? null
        : parseOneOf(row.spell_ability, SPELL_ABILITIES, "spell_ability", subject),
    weaponTraining: parseOneOf(
      requireField(row.weapon_training, "weapon_training", subject),
      WEAPON_TRAINING,
      "weapon_training",
      subject,
    ),
    unarmoredAbility:
      row.unarmored_ability == null
        ? null
        : parseOneOf(row.unarmored_ability, ABILITIES, "unarmored_ability", subject),
    subclassLevel: row.subclass_level,
    subclassTitle: row.subclass_title,
    isHomebrew: row.campaign_id !== null,
  };
}

export function toSubclass(row: Tables<"subclasses">): Subclass {
  const subject = `Subclass ${row.id}`;
  return {
    id: row.id,
    classId: row.class_id,
    name: row.name,
    description: row.description,
    source:
      row.source == null
        ? null
        : parseOneOf(row.source, SUBCLASS_SOURCES, "source", subject),
    spellAbility:
      row.spell_ability == null
        ? null
        : parseOneOf(row.spell_ability, SPELL_ABILITIES, "spell_ability", subject),
    isHomebrew: row.campaign_id !== null,
  };
}

// getFeats' shape and getFeats' reason: RLS answers "may this viewer see this
// row", which a member of two campaigns passes for both campaigns' homebrew,
// so the query narrows to the campaign being viewed.
export async function getClasses(campaignId: string): Promise<CharacterClass[]> {
  const { data, error } = await supabase
    .from("classes")
    .select("*")
    .or(`campaign_id.is.null,campaign_id.eq.${campaignId}`)
    .order("name");
  if (error) {
    console.error(error);
    throw error;
  }
  return data.map(toCharacterClass);
}

// Every class's subclasses in one read, filtered per class on the client. Its
// own query rather than a `subclasses(*)` embed on getClasses: an embed would
// bring along another campaign's homebrew subclasses of a shared class, and
// this .or() is what keeps them out.
export async function getSubclasses(campaignId: string): Promise<Subclass[]> {
  const { data, error } = await supabase
    .from("subclasses")
    .select("*")
    .or(`campaign_id.is.null,campaign_id.eq.${campaignId}`)
    .order("name");
  if (error) {
    console.error(error);
    throw error;
  }
  return data.map(toSubclass);
}

type ClassFeatureRow = Tables<"class_features"> & {
  class_feature_options: Pick<Tables<"class_feature_options">, "option_id">[];
};

export function toClassFeature(row: ClassFeatureRow): ClassFeature {
  return {
    id: row.id,
    classId: row.class_id,
    subclassId: row.subclass_id,
    level: row.level,
    name: row.name,
    description: row.description,
    optionIds: row.class_feature_options.map((l) => l.option_id),
    isHomebrew: row.campaign_id !== null,
  };
}

// getSubclasses' shape: every class's features in one read, filtered per class
// on the client, with the same .or() keeping other campaigns' homebrew out.
// The links are embedded. Their read policy needs both ends visible, so a
// link to another campaign's homebrew option comes back as absent, not as an
// id the options catalogue can't resolve.
export async function getClassFeatures(campaignId: string): Promise<ClassFeature[]> {
  const { data, error } = await supabase
    .from("class_features")
    .select("*, class_feature_options(option_id)")
    .or(`campaign_id.is.null,campaign_id.eq.${campaignId}`)
    .order("level")
    .order("name");
  if (error) {
    console.error(error);
    throw error;
  }
  return data.map(toClassFeature);
}

export function toFeatureOption(row: Tables<"feature_options">): FeatureOption {
  const subject = `Feature option ${row.id}`;
  return {
    id: row.id,
    kind: parseOneOf(row.kind, FEATURE_OPTION_KINDS, "kind", subject),
    key: row.key,
    name: row.name,
    description: row.description,
    source:
      row.source == null
        ? null
        : parseOneOf(row.source, SUBCLASS_SOURCES, "source", subject),
    isHomebrew: row.campaign_id !== null,
  };
}

// The options catalogue, getSubclasses' shape again. PHB first, then the
// later books, then homebrew, alphabetical within each: the picker's order.
export async function getFeatureOptions(campaignId: string): Promise<FeatureOption[]> {
  const { data, error } = await supabase
    .from("feature_options")
    .select("*")
    .or(`campaign_id.is.null,campaign_id.eq.${campaignId}`)
    .order("source", { nullsFirst: false })
    .order("name");
  if (error) {
    console.error(error);
    throw error;
  }
  return data.map(toFeatureOption);
}

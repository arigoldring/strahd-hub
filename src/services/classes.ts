import { supabase } from "../lib/supabase";
import { parseOneOf, requireField } from "../lib/parse";
import { ABILITIES, SPELL_ABILITIES, type Ability, type SpellAbility } from "../data/rules";
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
  isHomebrew: boolean;
}

const WEAPON_TRAINING = ["simple", "martial"] as const;

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

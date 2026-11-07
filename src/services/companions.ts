import { supabase } from "../lib/supabase";
import { parseOneOf } from "../lib/parse";
import type { Tables } from "../types/database.types";

/**
 * A character's companions (167): today only the Battle Smith's steel
 * defender. Only what changes in play is stored: a name, the damage taken
 * and temp HP. The maximum HP and the whole stat block are derived by
 * rules.ts (steelDefender), so a level-up needs no write.
 *
 * No row means the default companion: full HP, the kind's own name. The
 * first rename or hit creates the row, through an upsert.
 */

/**
 * One list in two places with the CHECK on character_companions.kind (167).
 * A new kind ships client first: toCompanion throws on a kind it doesn't
 * know.
 */
export const COMPANION_KINDS = ["steel_defender"] as const;
export type CompanionKind = (typeof COMPANION_KINDS)[number];

export const COMPANION_DEFAULT_NAMES: Record<CompanionKind, string> = {
  steel_defender: "Steel Defender",
};

export interface Companion {
  kind: CompanionKind;
  /** Null means the kind's default name. */
  name: string | null;
  /** Hit points lost. Current HP is the derived maximum minus this. */
  damage: number;
  hpTemp: number;
}

export interface CompanionPatch {
  name?: string | null;
  damage?: number;
  hpTemp?: number;
}

type CompanionRow = Tables<"character_companions">;

function toCompanion(row: CompanionRow): Companion {
  return {
    kind: parseOneOf(row.kind, COMPANION_KINDS, "kind", "Companion"),
    name: row.name,
    damage: row.damage,
    hpTemp: row.hp_temp,
  };
}

/** The companion a missing row stands for. */
export function defaultCompanion(kind: CompanionKind): Companion {
  return { kind, name: null, damage: 0, hpTemp: 0 };
}

/**
 * A blank name is the default name (167's CHECK refuses a blank one, so a
 * cleared field has to become null here rather than an error).
 */
export function normalizeCompanionName(name: string): string | null {
  const trimmed = name.trim();
  return trimmed === "" ? null : trimmed;
}

export async function getCompanions(characterId: string): Promise<Companion[]> {
  const { data, error } = await supabase
    .from("character_companions")
    .select("*")
    .eq("character_id", characterId);
  if (error) {
    console.error(error);
    throw error;
  }
  return data.map(toCompanion);
}

/**
 * Damage (delta < 0) or healing (delta > 0), one statement on the server:
 * temp HP absorbs damage first, damage stops at `cap` (the derived maximum)
 * and healing at full. Concurrent hits add up.
 */
export async function adjustCompanionHp(
  characterId: string,
  kind: CompanionKind,
  delta: number,
  cap: number,
): Promise<Companion> {
  const { data, error } = await supabase.rpc("adjust_companion_hp", {
    target_character: characterId,
    target_kind: kind,
    delta,
    cap,
  });
  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) throw new Error("You can't change this companion's HP.");
  return toCompanion(data);
}

/**
 * Rename, set temp HP or set the damage outright (typing a current HP).
 * An upsert WITHOUT ignoreDuplicates: the second save must change the row,
 * which is why 167 ships an UPDATE policy (the upsert gotcha in CLAUDE.md).
 */
export async function saveCompanion(
  characterId: string,
  kind: CompanionKind,
  patch: CompanionPatch,
): Promise<Companion> {
  const { data, error } = await supabase
    .from("character_companions")
    .upsert(
      {
        character_id: characterId,
        kind,
        ...(patch.name !== undefined && { name: patch.name }),
        ...(patch.damage !== undefined && { damage: patch.damage }),
        ...(patch.hpTemp !== undefined && { hp_temp: patch.hpTemp }),
      },
      { onConflict: "character_id,kind" },
    )
    .select()
    .maybeSingle();
  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) throw new Error("You can't change this companion.");
  return toCompanion(data);
}

/**
 * A long rest: every companion of the character back to full. Temp HP is
 * left alone, as the sheet's own long rest leaves the character's. A refused
 * update is a zero-row success, but only a caller who can't edit the
 * character is refused, and the sheet doesn't offer them the button.
 */
export async function restCompanions(characterId: string): Promise<void> {
  const { error } = await supabase
    .from("character_companions")
    .update({ damage: 0 })
    .eq("character_id", characterId);
  if (error) {
    console.error(error);
    throw error;
  }
}

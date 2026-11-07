import { supabase } from "../lib/supabase";

/**
 * How much of each use counter a character has spent (153). Only spent uses
 * are stored. A counter's maximum is derived by rules.ts (resourceMax), so
 * this map holds no maximums. A key that's missing means nothing spent.
 *
 * Keys: `res:<feature_resources.id>`, `slot:<1-9>` or `pact` (153's CHECK).
 */
export type ResourceUses = Record<string, number>;

export const featureResourceKey = (resourceId: string) => `res:${resourceId}`;

export async function getResourceUses(characterId: string): Promise<ResourceUses> {
  const { data, error } = await supabase
    .from("character_resource_uses")
    .select("resource_key, used")
    .eq("character_id", characterId);
  if (error) {
    console.error(error);
    throw error;
  }
  return Object.fromEntries(data.map((r) => [r.resource_key, r.used]));
}

/**
 * Spend (delta > 0) or give back (delta < 0) uses, clamped by the server to
 * 0..cap in one statement, so concurrent taps add up. Returns the spent count
 * after the write.
 */
export async function spendResource(
  characterId: string,
  key: string,
  delta: number,
  cap: number,
): Promise<number> {
  const { data, error } = await supabase.rpc("use_resource", {
    target_character: characterId,
    target_key: key,
    delta,
    cap,
  });
  if (error) {
    console.error(error);
    throw error;
  }
  // No row back means RLS refused the upsert.
  if (data == null) throw new Error("You can't change this character's counters.");
  return data;
}

/**
 * A rest: clear the spent count of the listed counters, or every counter for
 * `"all"` (a long rest). One DELETE either way, so it's atomic. A refused
 * delete is a zero-row success (153's header); only a caller who can't edit
 * the character is refused, and the sheet doesn't offer them the buttons.
 */
export async function clearResourceUses(
  characterId: string,
  keys: readonly string[] | "all",
): Promise<void> {
  if (keys !== "all" && keys.length === 0) return;
  let query = supabase.from("character_resource_uses").delete().eq("character_id", characterId);
  if (keys !== "all") query = query.in("resource_key", [...keys]);
  const { error } = await query;
  if (error) {
    console.error(error);
    throw error;
  }
}

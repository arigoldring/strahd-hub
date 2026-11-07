import { supabase } from "../lib/supabase";
import { parseOneOf } from "../lib/parse";
import { FEATURE_EFFECTS, type FeatureEffect } from "../data/rules";
import type { Tables } from "../types/database.types";

/**
 * The race catalogue (054): the nine PHB races (055) and Warforged (148),
 * plus this campaign's homebrew. Speed is a number the sheet uses; a character's
 * speed_override (056) beats it when set. `effect` (159) is the other.
 */
export interface Race {
  id: string;
  name: string;
  description: string;
  speed: number;
  size: RaceSize;
  /** The trait the sheet computes from: Warforged's Integrated Protection. */
  effect: FeatureEffect | null;
  isHomebrew: boolean;
}

export const RACE_SIZES = ["tiny", "small", "medium", "large"] as const;
export type RaceSize = (typeof RACE_SIZES)[number];

export function toRace(row: Tables<"races">): Race {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    speed: row.speed,
    size: parseOneOf(row.size, RACE_SIZES, "size", `Race ${row.id}`),
    effect:
      row.effect == null
        ? null
        : parseOneOf(row.effect, FEATURE_EFFECTS, "effect", `Race ${row.id}`),
    isHomebrew: row.campaign_id !== null,
  };
}

// getClasses' shape: shared rows plus this campaign's homebrew, nothing else.
export async function getRaces(campaignId: string): Promise<Race[]> {
  const { data, error } = await supabase
    .from("races")
    .select("*")
    .or(`campaign_id.is.null,campaign_id.eq.${campaignId}`)
    .order("name");
  if (error) {
    console.error(error);
    throw error;
  }
  return data.map(toRace);
}

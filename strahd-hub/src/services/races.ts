import { supabase } from "../lib/supabase";
import { parseOneOf } from "../lib/parse";
import type { Tables } from "../types/database.types";

/**
 * The race catalogue (054/055): the nine PHB races plus this campaign's
 * homebrew. Speed is the one number the sheet uses; a character's
 * speed_override (056) beats it when set.
 */
export interface Race {
  id: string;
  name: string;
  description: string;
  speed: number;
  size: RaceSize;
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

import { supabase } from "../lib/supabase";
import { parseOneOf } from "../lib/parse";
import { FEATURE_EFFECTS, type FeatureEffect, type RaceGrantsLike } from "../data/rules";
import { toFeatureResource, type FeatureResource } from "./classes";
import type { Tables } from "../types/database.types";

/**
 * The race catalogue (054): the nine PHB races (055) and Warforged (148),
 * plus this campaign's homebrew. Speed is a number the sheet uses; a character's
 * speed_override (056) beats it when set. `effect` (159) and the grant lists
 * (164) are the rest of what it computes from.
 *
 * A Race and a Subrace are both RaceGrantsLike, so rules.ts's raceGrants
 * merges them without knowing which is which.
 */
export interface Race extends RaceGrantsLike {
  id: string;
  description: string;
  speed: number;
  size: RaceSize;
  /** The trait the sheet computes from: Warforged's Integrated Protection. */
  effect: FeatureEffect | null;
  isHomebrew: boolean;
}

/** A subrace (164): Hill Dwarf, Drow. Adds to its race; never takes away. */
export interface Subrace extends RaceGrantsLike {
  id: string;
  raceId: string;
  description: string;
  /** Null: the race's speed. Wood Elf's 35 is the one that isn't. */
  speed: number | null;
  effect: FeatureEffect | null;
  isHomebrew: boolean;
}

/**
 * One trait to read (164): every subrace's when subraceId is null, else that
 * subrace's. The numbers it changes come from the race's columns, not from
 * here; a trait carries only its text and its use counters (153).
 */
export interface RaceTrait {
  id: string;
  raceId: string;
  subraceId: string | null;
  name: string;
  description: string;
  resources: FeatureResource[];
  isHomebrew: boolean;
}

export const RACE_SIZES = ["tiny", "small", "medium", "large"] as const;
export type RaceSize = (typeof RACE_SIZES)[number];

const parseEffect = (effect: string | null, subject: string) =>
  effect == null ? null : parseOneOf(effect, FEATURE_EFFECTS, "effect", subject);

export function toRace(row: Tables<"races">): Race {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    speed: row.speed,
    size: parseOneOf(row.size, RACE_SIZES, "size", `Race ${row.id}`),
    effect: parseEffect(row.effect, `Race ${row.id}`),
    darkvision: row.darkvision,
    skillProficiencies: row.skill_proficiencies,
    weaponProficiencies: row.weapon_proficiencies,
    armorProficiencies: row.armor_proficiencies,
    toolProficiencies: row.tool_proficiencies,
    languages: row.languages,
    resistances: row.resistances,
    isHomebrew: row.campaign_id !== null,
  };
}

export function toSubrace(row: Tables<"subraces">): Subrace {
  return {
    id: row.id,
    raceId: row.race_id,
    name: row.name,
    description: row.description,
    speed: row.speed,
    effect: parseEffect(row.effect, `Subrace ${row.id}`),
    darkvision: row.darkvision,
    skillProficiencies: row.skill_proficiencies,
    weaponProficiencies: row.weapon_proficiencies,
    armorProficiencies: row.armor_proficiencies,
    toolProficiencies: row.tool_proficiencies,
    languages: row.languages,
    resistances: row.resistances,
    isHomebrew: row.campaign_id !== null,
  };
}

type RaceTraitRow = Tables<"race_traits"> & {
  feature_resources: Tables<"feature_resources">[];
};

const bySort = (a: { sort: number; name: string }, b: { sort: number; name: string }) =>
  a.sort - b.sort || a.name.localeCompare(b.name);

export function toRaceTrait(row: RaceTraitRow): RaceTrait {
  return {
    id: row.id,
    raceId: row.race_id,
    subraceId: row.subrace_id,
    name: row.name,
    description: row.description,
    resources: [...row.feature_resources].sort(bySort).map(toFeatureResource),
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

// getSubclasses' shape: every race's in one read, filtered per race on the
// client.
export async function getSubraces(campaignId: string): Promise<Subrace[]> {
  const { data, error } = await supabase
    .from("subraces")
    .select("*")
    .or(`campaign_id.is.null,campaign_id.eq.${campaignId}`)
    .order("name");
  if (error) {
    console.error(error);
    throw error;
  }
  return data.map(toSubrace);
}

// getClassFeatures' shape, counters embedded. Ordered by `sort` here rather
// than in the query, because a race's traits and its subrace's interleave by
// it on the sheet.
export async function getRaceTraits(campaignId: string): Promise<RaceTrait[]> {
  const { data, error } = await supabase
    .from("race_traits")
    .select("*, feature_resources(*)")
    .or(`campaign_id.is.null,campaign_id.eq.${campaignId}`);
  if (error) {
    console.error(error);
    throw error;
  }
  return [...data].sort(bySort).map(toRaceTrait);
}

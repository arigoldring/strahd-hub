import { supabase } from "../lib/supabase";
import { parseOneOf } from "../lib/parse";
import {
  ABILITIES,
  SKILLS,
  type Ability,
  type ProficiencyLevel,
  type SkillKey,
} from "../data/rules";
import type { Tables, TablesUpdate } from "../types/database.types";

/**
 * A character's rules numbers (056): the three sibling tables of `characters`
 * the full sheet reads. All three are owner-or-DM writable through
 * can_edit_character, unlike the characters row itself (owner-only), which is
 * why none of this is a column there.
 *
 * Only inputs are stored. Modifiers, proficiency bonus, AC, attacks and spell
 * DC are derived on the client by src/data/rules.ts.
 */

export interface CharacterStats {
  characterId: string;
  raceId: string | null;
  scores: Record<Ability, number>;
  hpMax: number;
  hpCurrent: number;
  hpTemp: number;
  /** Null means "use the race's speed". */
  speedOverride: number | null;
  acBonus: number;
}

export interface CharacterClassEntry {
  /** The character_classes row id. */
  id: string;
  classId: string;
  subclassId: string | null;
  /** This entry's feature picks (083), oldest first. */
  choices: FeatureChoice[];
  level: number;
  isStarting: boolean;
}

/** One character_feature_choices row (083). */
export interface FeatureChoice {
  id: string;
  featureId: string;
  optionId: string;
  /** The free-text half of a pick, e.g. Favored Enemy's two humanoid races. */
  detail: string | null;
}

export const PROFICIENCY_KINDS = [
  "save",
  "skill",
  "weapon",
  "armor",
  "tool",
  "language",
] as const;
export type ProficiencyKind = (typeof PROFICIENCY_KINDS)[number];

export interface Proficiency {
  kind: ProficiencyKind;
  /** An ability code for saves, a SkillKey for skills, free text otherwise. */
  key: string;
  level: 1 | 2;
}

export interface CharacterSheetData {
  stats: CharacterStats;
  classes: CharacterClassEntry[];
  proficiencies: Proficiency[];
}

// The one place ability codes meet column names. 056 spells the columns out
// because `int` is a Postgres type keyword.
const SCORE_COLUMNS = {
  str: "strength",
  dex: "dexterity",
  con: "constitution",
  int: "intelligence",
  wis: "wisdom",
  cha: "charisma",
} as const satisfies Record<Ability, keyof Tables<"character_stats">>;

function toCharacterStats(row: Tables<"character_stats">): CharacterStats {
  return {
    characterId: row.character_id,
    raceId: row.race_id,
    scores: Object.fromEntries(
      ABILITIES.map((a) => [a, row[SCORE_COLUMNS[a]]]),
    ) as Record<Ability, number>,
    hpMax: row.hp_max,
    hpCurrent: row.hp_current,
    hpTemp: row.hp_temp,
    speedOverride: row.speed_override,
    acBonus: row.ac_bonus,
  };
}

function toProficiency(row: Tables<"character_proficiencies">): Proficiency {
  const subject = `Proficiency ${row.character_id}/${row.kind}/${row.key}`;
  return {
    kind: parseOneOf(row.kind, PROFICIENCY_KINDS, "kind", subject),
    key: row.key,
    level: row.level === 2 ? 2 : 1,
  };
}

/**
 * Four reads in parallel, the getCharacterInventory shape. A failure in any
 * sinks all four on purpose: a sheet with scores but no proficiencies would
 * show wrong totals rather than an error. Feature picks are one of the four
 * rather than their own hook so the Party page, which mounts this per
 * character, doesn't gain a query per character (KNOWN_ISSUES).
 *
 * The stats row always exists (056's trigger and backfill), so its absence is
 * an error here rather than a "no stats yet" state: it means RLS hid the
 * character, or the row was deleted by hand.
 */
export async function getCharacterSheet(
  characterId: string,
): Promise<CharacterSheetData> {
  const [stats, classes, profs, choices] = await Promise.all([
    supabase
      .from("character_stats")
      .select("*")
      .eq("character_id", characterId)
      .maybeSingle(),
    supabase
      .from("character_classes")
      .select("*")
      .eq("character_id", characterId)
      .order("created_at"),
    supabase
      .from("character_proficiencies")
      .select("*")
      .eq("character_id", characterId),
    supabase
      .from("character_feature_choices")
      .select("*")
      .eq("character_id", characterId)
      .order("created_at"),
  ]);

  for (const { error } of [stats, classes, profs, choices]) {
    if (error) {
      console.error(error);
      throw error;
    }
  }
  if (!stats.data) throw new Error("This character has no stats row.");

  return {
    stats: toCharacterStats(stats.data),
    classes: classes.data!.map((row) => ({
      id: row.id,
      classId: row.class_id,
      subclassId: row.subclass_id,
      choices: choices
        .data!.filter((c) => c.character_class_id === row.id)
        .map(toFeatureChoice),
      level: row.level,
      isStarting: row.is_starting,
    })),
    proficiencies: profs.data!.map(toProficiency),
  };
}

/** The writable subset of CharacterStats. */
export type CharacterStatsPatch = Partial<
  Omit<CharacterStats, "characterId" | "scores">
> & { scores?: Partial<Record<Ability, number>> };

/**
 * A plain UPDATE: the row always exists, so there is no upsert. A refused
 * write is a zero-row 200 (CLAUDE.md), so the row is selected back and its
 * absence treated as the refusal.
 */
export async function updateCharacterStats(
  characterId: string,
  patch: CharacterStatsPatch,
): Promise<CharacterStats> {
  const columns: TablesUpdate<"character_stats"> = {};
  if (patch.raceId !== undefined) columns.race_id = patch.raceId;
  if (patch.hpMax !== undefined) columns.hp_max = patch.hpMax;
  if (patch.hpCurrent !== undefined) columns.hp_current = patch.hpCurrent;
  if (patch.hpTemp !== undefined) columns.hp_temp = patch.hpTemp;
  if (patch.speedOverride !== undefined) columns.speed_override = patch.speedOverride;
  if (patch.acBonus !== undefined) columns.ac_bonus = patch.acBonus;
  for (const a of ABILITIES) {
    const score = patch.scores?.[a];
    if (score !== undefined) columns[SCORE_COLUMNS[a]] = score;
  }

  const { data, error } = await supabase
    .from("character_stats")
    .update(columns)
    .eq("character_id", characterId)
    .select("*")
    .maybeSingle();
  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) throw new Error("You can't edit this character's stats.");
  return toCharacterStats(data);
}

/**
 * Damage (negative) or healing (positive) through 056's function: one UPDATE,
 * so a DM and a player hitting the same character in the same round can't
 * overwrite each other. Temp HP absorbs damage first; healing caps at max.
 */
export async function adjustCharacterHp(
  characterId: string,
  delta: number,
): Promise<CharacterStats> {
  const { data, error } = await supabase.rpc("adjust_character_hp", {
    target_character: characterId,
    delta,
  });
  if (error) {
    console.error(error);
    throw error;
  }
  const row = data?.[0];
  if (!row) throw new Error("You can't change this character's HP.");
  return toCharacterStats(row);
}

/**
 * Sets the character's single (starting) class: updates the starting row if
 * there is one, otherwise inserts it, then replaces the save proficiencies
 * with the class's two. The page offers one class for now; the table already
 * holds several (multiclass), each its own row.
 *
 * Three requests, not one transaction. A failure between them leaves the
 * class changed and the saves stale, which the next class pick (or a manual
 * toggle) repairs; an RPC would make it atomic if that ever matters.
 *
 * subclass_id is cleared with the class: 056's composite FK refuses a subclass
 * of a different class. Feature picks need no clearing here: 083's trigger
 * deletes them when class_id changes.
 */
export async function setStartingClass(
  characterId: string,
  existing: CharacterClassEntry | undefined,
  classId: string,
  saves: readonly Ability[],
): Promise<void> {
  const write = existing
    ? supabase
        .from("character_classes")
        .update({ class_id: classId, subclass_id: null })
        .eq("id", existing.id)
        .select("id")
        .maybeSingle()
    : supabase
        .from("character_classes")
        .insert({ character_id: characterId, class_id: classId, is_starting: true })
        .select("id")
        .maybeSingle();
  const { data, error } = await write;
  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) throw new Error("You can't change this character's class.");

  await replaceSaves(characterId, saves);
}

export async function setClassLevel(entryId: string, level: number): Promise<void> {
  const { data, error } = await supabase
    .from("character_classes")
    .update({ level })
    .eq("id", entryId)
    .select("id")
    .maybeSingle();
  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) throw new Error("You can't change this character's level.");
}

/**
 * Null clears it. 056's composite FK refuses a subclass of a different class,
 * so a stale picker can't attach one; that surfaces as a 23503 error here.
 */
export async function setSubclass(
  entryId: string,
  subclassId: string | null,
): Promise<void> {
  const { data, error } = await supabase
    .from("character_classes")
    .update({ subclass_id: subclassId })
    .eq("id", entryId)
    .select("id")
    .maybeSingle();
  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) throw new Error("You can't change this character's subclass.");
}

function toFeatureChoice(row: Tables<"character_feature_choices">): FeatureChoice {
  return {
    id: row.id,
    featureId: row.feature_id,
    optionId: row.option_id,
    detail: row.detail,
  };
}

/**
 * One pick. 083's FKs refuse an option the feature doesn't offer or a feature
 * of another class (23503), and its unique index the same option twice on one
 * class entry (23505). How many picks a feature allows is not checked here or
 * there: the sheet only displays it.
 */
export async function addFeatureChoice(
  characterId: string,
  entry: Pick<CharacterClassEntry, "id" | "classId">,
  featureId: string,
  optionId: string,
): Promise<FeatureChoice> {
  const { data, error } = await supabase
    .from("character_feature_choices")
    .insert({
      character_id: characterId,
      character_class_id: entry.id,
      class_id: entry.classId,
      feature_id: featureId,
      option_id: optionId,
    })
    .select("*")
    .maybeSingle();
  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) throw new Error("You can't change this character's features.");
  return toFeatureChoice(data);
}

/** A refused delete is a zero-row success (CLAUDE.md), so the row is selected back. */
export async function removeFeatureChoice(choiceId: string): Promise<void> {
  const { data, error } = await supabase
    .from("character_feature_choices")
    .delete()
    .eq("id", choiceId)
    .select("id")
    .maybeSingle();
  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) throw new Error("You can't change this character's features.");
}

async function replaceSaves(characterId: string, saves: readonly Ability[]) {
  const { error: delError } = await supabase
    .from("character_proficiencies")
    .delete()
    .eq("character_id", characterId)
    .eq("kind", "save");
  if (delError) {
    console.error(delError);
    throw delError;
  }
  if (saves.length === 0) return;
  const { error } = await supabase
    .from("character_proficiencies")
    .insert(saves.map((key) => ({ character_id: characterId, kind: "save", key })));
  if (error) {
    console.error(error);
    throw error;
  }
}

/**
 * Sets one proficiency. Level 0 is "untrained", which 056 spells as no row,
 * so it's a delete. Otherwise an upsert WITHOUT ignoreDuplicates: going from
 * proficient to expertise must actually change the stored level, which is
 * why 056 ships an UPDATE policy (CLAUDE.md, "Upsert conflict behaviour is
 * per-table and load-bearing").
 */
export async function setProficiency(
  characterId: string,
  kind: ProficiencyKind,
  key: string,
  level: ProficiencyLevel,
): Promise<void> {
  if (level === 0) {
    const { error } = await supabase
      .from("character_proficiencies")
      .delete()
      .eq("character_id", characterId)
      .eq("kind", kind)
      .eq("key", key);
    if (error) {
      console.error(error);
      throw error;
    }
    return;
  }

  const { error } = await supabase
    .from("character_proficiencies")
    .upsert(
      { character_id: characterId, kind, key, level },
      { onConflict: "character_id,kind,key" },
    );
  if (error) {
    console.error(error);
    throw error;
  }
}

/** Skill proficiency levels keyed for the sheet; missing means untrained. */
export function skillLevels(
  proficiencies: readonly Proficiency[],
): Record<SkillKey, ProficiencyLevel> {
  const levels = Object.fromEntries(SKILLS.map((s) => [s.key, 0])) as Record<
    SkillKey,
    ProficiencyLevel
  >;
  for (const p of proficiencies) {
    if (p.kind === "skill" && p.key in levels) levels[p.key as SkillKey] = p.level;
  }
  return levels;
}

/** Abilities with a save proficiency. */
export function saveSet(proficiencies: readonly Proficiency[]): Set<string> {
  return new Set(proficiencies.filter((p) => p.kind === "save").map((p) => p.key));
}

import { supabase } from "../lib/supabase";
import { parseOneOf, requireField } from "../lib/parse";
import { COMBATANT_KINDS, numberedNames, type CombatantKind } from "../data/rules";
import type { Tables, TablesUpdate } from "../types/database.types";

/**
 * The initiative tracker (171). One live fight per campaign: `encounters`
 * holds the round and whose turn it is, `encounter_combatants` the order,
 * and `encounter_monster_stats` a monster's numbers, which only the DM can
 * read.
 *
 * Who may write what is the database's business, not this file's: RLS lets
 * the DM write everything and a player write their own PC's row, and 171's
 * pin triggers keep a player to the initiative column. A refused UPDATE comes
 * back as a zero-row success, so every write here that a refusal could hit
 * uses .select().maybeSingle() and treats no row as a refusal (CLAUDE.md).
 */

/** encounter_combatants.status. 171's CHECK; one list in two places. */
export const MONSTER_STATUSES = ["bloodied", "down"] as const;
export type MonsterStatus = (typeof MONSTER_STATUSES)[number];

export interface Combatant {
  id: string;
  kind: CombatantKind;
  /** A PC's or companion's character; null for a monster. */
  characterId: string | null;
  /** A monster's name. Null for a PC or companion, which take theirs from
   * the character and the companion row. */
  name: string | null;
  /** A monster's DEX score. Null for a PC (character_stats has it) and a
   * companion (sorted after its character, never by DEX). */
  dex: number | null;
  /** Null until rolled. Always null on a companion. */
  initiative: number | null;
  /** A monster's Bloodied/Down, written by 171's trigger. Null is healthy. */
  status: MonsterStatus | null;
}

export interface Encounter {
  id: string;
  campaignId: string;
  round: number;
  turnCombatantId: string | null;
  combatants: Combatant[];
}

export interface MonsterStats {
  combatantId: string;
  hpMax: number;
  hpCurrent: number;
  hpTemp: number;
  ac: number | null;
  initBonus: number;
}

export interface NewMonsters {
  name: string;
  /** How many. More than one numbers them: "Zombie 1", "Zombie 2". */
  count: number;
  dex: number;
  hpMax: number;
  ac: number | null;
  initBonus: number;
}

export interface CombatantPatch {
  name?: string;
  dex?: number;
  initiative?: number | null;
}

export type MonsterStatsPatch = Partial<Omit<MonsterStats, "combatantId">>;

/** Who joins when a fight starts: each PC, and their defender if they have one. */
export interface StartingPc {
  characterId: string;
  hasDefender: boolean;
}

type CombatantRow = Tables<"encounter_combatants">;
type StatsRow = Tables<"encounter_monster_stats">;

// The FK is named because there are two between these tables: the
// combatants' encounter_id (one fight, many combatants) and 171's
// encounters_turn_fkey (whose turn: one). Unnamed, PostgREST can't choose,
// and the generated types pick the turn's one-to-one.
const ENCOUNTER_SELECT =
  "*, encounter_combatants!encounter_combatants_encounter_id_fkey(*)";

function toCombatant(row: CombatantRow): Combatant {
  const subject = `Combatant ${row.id}`;
  return {
    id: row.id,
    kind: parseOneOf(row.kind, COMBATANT_KINDS, "kind", subject),
    characterId: row.character_id,
    name: row.name,
    dex: row.dex,
    initiative: row.initiative,
    status:
      row.status === null ? null : parseOneOf(row.status, MONSTER_STATUSES, "status", subject),
  };
}

function toMonsterStats(row: StatsRow): MonsterStats {
  return {
    combatantId: row.combatant_id,
    hpMax: row.hp_max,
    hpCurrent: row.hp_current,
    hpTemp: row.hp_temp,
    ac: row.ac,
    initBonus: row.init_bonus,
  };
}

function fail(error: unknown): never {
  console.error(error);
  throw error;
}

/** The campaign's live fight, or null when there isn't one. */
export async function getEncounter(campaignId: string): Promise<Encounter | null> {
  const { data, error } = await supabase
    .from("encounters")
    .select(ENCOUNTER_SELECT)
    .eq("campaign_id", campaignId)
    .maybeSingle();
  if (error) fail(error);
  if (!data) return null;
  return {
    id: data.id,
    campaignId: data.campaign_id,
    round: data.round,
    turnCombatantId: data.turn_combatant_id,
    combatants: requireField(data.encounter_combatants, "encounter_combatants", `Encounter ${data.id}`)
      .map(toCombatant),
  };
}

/**
 * Starts the fight with every PC in it. Two requests: the encounter, then
 * its combatants. If the second fails the fight exists with nobody in it,
 * which the page shows as an empty fight the DM can end, so no compensating
 * delete. A second Start while a fight runs fails on 171's unique
 * campaign_id (23505), with the message below.
 */
export async function startEncounter(campaignId: string, pcs: StartingPc[]): Promise<void> {
  const { data, error } = await supabase
    .from("encounters")
    .insert({ campaign_id: campaignId })
    .select("id")
    .single();
  if (error) {
    if (error.code === "23505") throw new Error("A fight is already running in this campaign.");
    fail(error);
  }

  await addPcs(data.id, pcs);
}

/**
 * PCs into a running fight: everyone at the start, or a latecomer. A PC
 * already in it fails on 171's unique (encounter_id, kind, character_id),
 * which the page avoids by offering only the missing ones.
 */
export async function addPcs(encounterId: string, pcs: StartingPc[]): Promise<void> {
  const rows = pcs.flatMap((pc) => [
    { encounter_id: encounterId, kind: "pc", character_id: pc.characterId },
    ...(pc.hasDefender
      ? [{ encounter_id: encounterId, kind: "companion", character_id: pc.characterId }]
      : []),
  ]);
  if (rows.length === 0) return;
  const { error } = await supabase.from("encounter_combatants").insert(rows);
  if (error) fail(error);
}

/** Ends the fight. Its combatants and their stats cascade with it. */
export async function endEncounter(encounterId: string): Promise<void> {
  const { data, error } = await supabase
    .from("encounters")
    .delete()
    .eq("id", encounterId)
    .select("id")
    .maybeSingle();
  if (error) fail(error);
  if (!data) throw new Error("You can't end this fight, or it has already ended.");
}

/** Round and whose turn, the DM's Next and Back. */
export async function setTurn(
  encounterId: string,
  turn: { turnId: string | null; round: number },
): Promise<void> {
  const { data, error } = await supabase
    .from("encounters")
    .update({ turn_combatant_id: turn.turnId, round: turn.round })
    .eq("id", encounterId)
    .select("id")
    .maybeSingle();
  if (error) fail(error);
  if (!data) throw new Error("You can't change whose turn it is.");
}

/**
 * Adds monsters. The combatants first, then their stats; if the stats
 * insert fails, the combatants just added are deleted again, because a
 * monster without stats would have no HP to show the DM.
 */
export async function addMonsters(encounterId: string, monsters: NewMonsters): Promise<void> {
  const { data, error } = await supabase
    .from("encounter_combatants")
    .insert(
      numberedNames(monsters.name, monsters.count).map((name) => ({
        encounter_id: encounterId,
        kind: "monster",
        name,
        dex: monsters.dex,
      })),
    )
    .select("id");
  if (error) fail(error);

  const { error: statsError } = await supabase.from("encounter_monster_stats").insert(
    data.map((row) => ({
      combatant_id: row.id,
      hp_max: monsters.hpMax,
      hp_current: monsters.hpMax,
      ac: monsters.ac,
      init_bonus: monsters.initBonus,
    })),
  );
  if (statsError) {
    await supabase
      .from("encounter_combatants")
      .delete()
      .in(
        "id",
        data.map((row) => row.id),
      );
    fail(statsError);
  }
}

/** Removes a combatant. Its stats cascade. */
export async function removeCombatant(combatantId: string): Promise<void> {
  const { data, error } = await supabase
    .from("encounter_combatants")
    .delete()
    .eq("id", combatantId)
    .select("id")
    .maybeSingle();
  if (error) fail(error);
  if (!data) throw new Error("You can't remove this combatant.");
}

/**
 * A combatant's name, DEX or initiative. A player may only change their own
 * PC's initiative: RLS refuses other rows outright (no row comes back), and
 * 171's pin trigger quietly keeps every other column as it was.
 */
export async function updateCombatant(
  combatantId: string,
  patch: CombatantPatch,
): Promise<Combatant> {
  const update: TablesUpdate<"encounter_combatants"> = {
    ...(patch.name !== undefined && { name: patch.name.trim() }),
    ...(patch.dex !== undefined && { dex: patch.dex }),
    ...(patch.initiative !== undefined && { initiative: patch.initiative }),
  };
  const { data, error } = await supabase
    .from("encounter_combatants")
    .update(update)
    .eq("id", combatantId)
    .select()
    .maybeSingle();
  if (error) fail(error);
  if (!data) throw new Error("You can't change this combatant.");
  return toCombatant(data);
}

/**
 * Several initiatives at once, the DM's Roll all. One UPDATE per combatant,
 * in parallel: an upsert would need every not-null column of the row, and
 * a fight is a dozen rows at most.
 */
export async function setInitiatives(
  rolls: { combatantId: string; initiative: number }[],
): Promise<void> {
  await Promise.all(rolls.map((r) => updateCombatant(r.combatantId, { initiative: r.initiative })));
}

/**
 * Every monster's numbers in the fight. DM-only: for anyone else RLS returns
 * no rows, which is an empty list, not an error. The inner join filters by
 * the encounter so the query key can name the encounter alone.
 */
export async function getMonsterStats(encounterId: string): Promise<MonsterStats[]> {
  const { data, error } = await supabase
    .from("encounter_monster_stats")
    .select("*, encounter_combatants!inner(encounter_id)")
    .eq("encounter_combatants.encounter_id", encounterId);
  if (error) fail(error);
  return data.map(toMonsterStats);
}

/**
 * Damage (delta < 0) or healing (delta > 0), one statement on the server:
 * temp HP first, never below 0, never above the maximum. The trigger then
 * updates the combatant's Bloodied/Down for the players.
 */
export async function adjustMonsterHp(combatantId: string, delta: number): Promise<MonsterStats> {
  const { data, error } = await supabase
    .rpc("adjust_monster_hp", { target_combatant: combatantId, delta })
    .maybeSingle();
  if (error) fail(error);
  if (!data) throw new Error("You can't change this monster's HP.");
  return toMonsterStats(data);
}

/**
 * Typed numbers: max HP, current HP, temp HP, AC, initiative bonus. Lowering
 * the maximum below current HP brings current down with it, because 171's
 * CHECK refuses current > max.
 */
export async function updateMonsterStats(
  current: MonsterStats,
  patch: MonsterStatsPatch,
): Promise<MonsterStats> {
  const hpMax = patch.hpMax ?? current.hpMax;
  const update: TablesUpdate<"encounter_monster_stats"> = {
    ...(patch.hpMax !== undefined && { hp_max: patch.hpMax }),
    ...(patch.hpTemp !== undefined && { hp_temp: patch.hpTemp }),
    ...(patch.ac !== undefined && { ac: patch.ac }),
    ...(patch.initBonus !== undefined && { init_bonus: patch.initBonus }),
  };
  const hpCurrent = Math.min(patch.hpCurrent ?? current.hpCurrent, hpMax);
  if (hpCurrent !== current.hpCurrent) update.hp_current = hpCurrent;

  const { data, error } = await supabase
    .from("encounter_monster_stats")
    .update(update)
    .eq("combatant_id", current.combatantId)
    .select()
    .maybeSingle();
  if (error) fail(error);
  if (!data) throw new Error("You can't change this monster.");
  return toMonsterStats(data);
}

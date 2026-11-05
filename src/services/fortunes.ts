import { supabase } from "../lib/supabase";
import type { Tables } from "../types/database.types";

// Same two-type split as mapReveals.ts: FortuneRow is exactly what Supabase
// returns; Fortune is how the rest of the app talks about one card.
type FortuneRow = Tables<"campaign_fortunes">;

export interface Fortune {
  id: string;
  /** 1-5 in reading order. Also the sort key. */
  card: number;
  title: string;
  /**
   * One element per stanza, its verse lines joined by "\n" (127). The column
   * is still called `lines`; renaming it wasn't worth a migration.
   */
  stanzas: string[];
  /** Only an artifact can be found. A companion's fortune never is (127). */
  isArtifact: boolean;
  isRevealed: boolean;
  isFound: boolean;
}

/**
 * A stanza in [square brackets] is a vision note -- narration, not Madam Eva
 * speaking (128). Returns the note without its brackets, or null for verse.
 * The one place the convention is read; the stored text keeps the brackets so
 * the editor round-trips it as typed.
 */
export function visionText(stanza: string): string | null {
  return stanza.startsWith("[") && stanza.endsWith("]")
    ? stanza.slice(1, -1).trim()
    : null;
}

function toFortune(row: FortuneRow): Fortune {
  return {
    id: row.id,
    card: row.card,
    title: row.title,
    stanzas: row.lines,
    isArtifact: row.is_artifact,
    isRevealed: row.is_revealed,
    isFound: row.is_found,
  };
}

// No isDm branch. 065's read policy hands the DM every card and a player none
// until the reading is revealed, so "no rows" IS "Madam Eva hasn't read yet" --
// the nav and the page both render straight from the length of this.
//
// Scoped to campaignId for getLocations' reason: a member of two campaigns
// passes RLS for both.
export async function getFortunes(campaignId: string): Promise<Fortune[]> {
  const { data, error } = await supabase
    .from("campaign_fortunes")
    .select("*")
    .eq("campaign_id", campaignId)
    .order("card");

  if (error) {
    console.error(error);
    throw error;
  }

  return data.map(toFortune);
}

/**
 * Reveal or hide the whole reading at once. One UPDATE across the campaign's
 * rows, so the cards can't end up half-revealed.
 *
 * Zero rows back is a refusal, not a no-op: RLS USING drops every row for a
 * non-DM before anything is checked (CLAUDE.md, "A refused write raises
 * nothing").
 */
export async function setFortunesRevealed(
  campaignId: string,
  isRevealed: boolean,
): Promise<void> {
  const { data, error } = await supabase
    .from("campaign_fortunes")
    .update({ is_revealed: isRevealed })
    .eq("campaign_id", campaignId)
    .select("id");

  if (error) {
    console.error(error);
    throw error;
  }
  if (data.length === 0) {
    throw new Error("You do not have permission to reveal the fortunes");
  }
}

/**
 * Rewrite one card's text. The text only: pin_fortune_row (065, 127) resets
 * the title, is_artifact and every key column, so nothing else is offered here.
 *
 * Every line is trimmed, blank lines inside a stanza are dropped, and a stanza
 * left empty is dropped, so 065's lines CHECK is a backstop rather than the
 * error a DM sees. All-blank is refused here with a message, for the same
 * reason. Returns what was stored.
 */
export async function updateFortuneStanzas(
  id: string,
  stanzas: string[],
): Promise<string[]> {
  const cleaned = stanzas
    .map((stanza) =>
      stanza
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line !== "")
        .join("\n"),
    )
    .filter((stanza) => stanza !== "");
  if (cleaned.length === 0) {
    throw new Error("A fortune needs at least one line");
  }

  const { data, error } = await supabase
    .from("campaign_fortunes")
    .update({ lines: cleaned })
    .eq("id", id)
    .select("lines")
    .maybeSingle();

  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) {
    throw new Error("You do not have permission to edit this fortune");
  }
  return data.lines;
}

export async function setFortuneFound(
  id: string,
  isFound: boolean,
): Promise<void> {
  const { data, error } = await supabase
    .from("campaign_fortunes")
    .update({ is_found: isFound })
    .eq("id", id)
    .select("id")
    .maybeSingle();

  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) {
    throw new Error("You do not have permission to mark a fortune found");
  }
}

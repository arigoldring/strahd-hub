import { supabase } from "../lib/supabase";
import type { Tables } from "../types/database.types";

// Same two-type split as mapReveals.ts: FortuneRow is exactly what Supabase
// returns; Fortune is how the rest of the app talks about one card.
type FortuneRow = Tables<"campaign_fortunes">;

export interface Fortune {
  id: string;
  /** 1-3 in reading order. Also the sort key. */
  card: number;
  title: string;
  lines: string[];
  isRevealed: boolean;
  isFound: boolean;
}

function toFortune(row: FortuneRow): Fortune {
  return {
    id: row.id,
    card: row.card,
    title: row.title,
    lines: row.lines,
    isRevealed: row.is_revealed,
    isFound: row.is_found,
  };
}

// No isDm branch. 065's read policy hands the DM all three and a player none
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
 * three rows, so the cards can't end up half-revealed.
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
 * Rewrite one card's text. The text only: pin_fortune_row (065) resets the
 * title and every key column, so nothing else is offered here.
 *
 * Trimmed and blank lines dropped at the boundary, so 065's lines CHECK is a
 * backstop rather than the error a DM sees. All-blank is refused here with a
 * message, for the same reason. Returns what was stored.
 */
export async function updateFortuneLines(
  id: string,
  lines: string[],
): Promise<string[]> {
  const cleaned = lines.map((line) => line.trim()).filter((line) => line !== "");
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

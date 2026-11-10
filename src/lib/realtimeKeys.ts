import type { QueryKey } from "@tanstack/react-query";

// Which query keys a database change makes stale. Pure on purpose (no
// Supabase, no React), so the whole mapping is unit-tested in
// realtimeKeys.test.ts. services/realtime.ts receives the events and
// hooks/useCampaignRealtime.ts invalidates what this returns.
//
// INVALIDATE, DON'T PATCH. An event carries one raw row, but the cache holds
// shaped data: ["characterSheet", id] is built from four tables, inventory
// entries are embeds run through toItem. Writing the payload into the cache
// would need a second copy of every transformation. So an event only says
// "this is stale", and the existing queryFn refetches it. One extra request
// per change, which is nothing at this app's size.
//
// Must list every table in the publication (170, 172). Adding a table there
// without a case here means its events arrive and invalidate nothing.
export const REALTIME_TABLES = [
  "characters",
  "character_stats",
  "character_inventory",
  "character_resource_uses",
  "character_companions",
  "party_inventory",
  "party_currency",
  "encounters",
  "encounter_combatants",
] as const;

export type RealtimeTable = (typeof REALTIME_TABLES)[number];

export interface RowChange {
  table: RealtimeTable;
  eventType: "INSERT" | "UPDATE" | "DELETE";
  /**
   * `new` for INSERT and UPDATE, `old` for DELETE. A DELETE's `old` holds only
   * the primary key (replica identity DEFAULT, 170's header), so a column
   * that isn't part of the key is missing from it.
   */
  row: Record<string, unknown>;
}

const str = (value: unknown): string | undefined =>
  typeof value === "string" ? value : undefined;

export function keysForChange(change: RowChange, campaignId: string): QueryKey[] {
  const { table, row } = change;
  const characterId = str(row.character_id);
  const rowCampaign = str(row.campaign_id);

  // Tables with a campaign_id: a member of two campaigns hears both, because
  // RLS passes them for both. A change to the other one is not this page's
  // business. A DELETE has no campaign_id (only `id` is in the key), so it
  // falls through and invalidates, which costs at most a refetch.
  if (rowCampaign !== undefined && rowCampaign !== campaignId) return [];

  // Sibling tables have no campaign_id (CLAUDE.md, Multi-campaign), so their
  // events can't be filtered that way. Invalidating a key for another
  // campaign's character is harmless: nothing is cached under it, so nothing
  // refetches. When a DELETE lacks character_id (character_inventory's key is
  // its own `id`), the prefix form invalidates every character's entry.
  const perCharacter = (prefix: string): QueryKey =>
    characterId ? [prefix, characterId] : [prefix];

  switch (table) {
    case "characters":
      // The purse and the name live on this row. ["characters", campaignId]
      // is a prefix of useCharacter's ["characters", campaignId, userId].
      return [["characters", campaignId], ["party", campaignId]];
    case "character_stats":
      // HP. The roster's PARTY_SELECT doesn't read stats, so no party key.
      return [perCharacter("characterSheet")];
    case "character_inventory":
      // The roster embeds every character's stacks.
      return [perCharacter("characterInventory"), ["party", campaignId]];
    case "character_resource_uses":
      return [perCharacter("characterResources")];
    case "character_companions":
      return [perCharacter("characterCompanions")];
    case "party_inventory":
      return [["partyInventory", campaignId]];
    case "party_currency":
      return [["partyCurrency", campaignId]];
    case "encounters":
      // Round and whose turn. useEncounter reads the fight and its
      // combatants under this one key.
      return [["encounter", campaignId]];
    case "encounter_combatants":
      // No campaign_id (171), so another campaign's combatant can't be told
      // apart and refetches this campaign's fight: one wasted request. Not
      // the ["encounter"] prefix: the other campaign's fight is not on
      // screen, and opening it within staleTime (60 s) of the change is the
      // only way to see it out of date, for a DM running two fights at once.
      return [["encounter", campaignId]];
  }
}

/**
 * Everything the tables above feed, for after a reconnect. Events sent while
 * the socket was down are gone (Realtime doesn't replay them), so on coming
 * back every covered key is treated as stale. Prefixes, because there's no
 * row to say which character.
 */
export function keysAfterReconnect(campaignId: string): QueryKey[] {
  return [
    ["characters", campaignId],
    ["party", campaignId],
    ["characterSheet"],
    ["characterInventory"],
    ["characterResources"],
    ["characterCompanions"],
    ["partyInventory", campaignId],
    ["partyCurrency", campaignId],
    ["encounter", campaignId],
  ];
}

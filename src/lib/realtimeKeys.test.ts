// The table-to-keys mapping behind live updates. Pure, like rules.ts, so each
// case is a change in and a list of keys out.
import { describe, expect, it } from "vitest";
import {
  keysAfterReconnect,
  keysForChange,
  REALTIME_TABLES,
  type RowChange,
} from "./realtimeKeys";

const CAMPAIGN = "camp-a";
const OTHER = "camp-b";
const CHAR = "char-1";

const change = (
  table: RowChange["table"],
  eventType: RowChange["eventType"],
  row: Record<string, unknown>,
): RowChange => ({ table, eventType, row });

describe("keysForChange", () => {
  it("sends HP changes to that character's sheet", () => {
    expect(
      keysForChange(change("character_stats", "UPDATE", { character_id: CHAR }), CAMPAIGN),
    ).toEqual([["characterSheet", CHAR]]);
  });

  it("sends loot to the pack and to the roster", () => {
    expect(
      keysForChange(
        change("character_inventory", "INSERT", { id: "e1", character_id: CHAR }),
        CAMPAIGN,
      ),
    ).toEqual([["characterInventory", CHAR], ["party", CAMPAIGN]]);
  });

  it("falls back to the prefix when a delete carries only the id", () => {
    expect(
      keysForChange(change("character_inventory", "DELETE", { id: "e1" }), CAMPAIGN),
    ).toEqual([["characterInventory"], ["party", CAMPAIGN]]);
  });

  it("keeps character_id on deletes whose primary key includes it", () => {
    // character_resource_uses' key is (character_id, resource_key).
    expect(
      keysForChange(
        change("character_resource_uses", "DELETE", {
          character_id: CHAR,
          resource_key: "x",
        }),
        CAMPAIGN,
      ),
    ).toEqual([["characterResources", CHAR]]);
  });

  it("ignores a campaign-scoped change from another campaign", () => {
    expect(
      keysForChange(change("party_currency", "UPDATE", { campaign_id: OTHER }), CAMPAIGN),
    ).toEqual([]);
    expect(
      keysForChange(change("characters", "UPDATE", { id: CHAR, campaign_id: OTHER }), CAMPAIGN),
    ).toEqual([]);
  });

  it("invalidates on a campaign-scoped delete, which has no campaign_id", () => {
    expect(
      keysForChange(change("party_inventory", "DELETE", { id: "p1" }), CAMPAIGN),
    ).toEqual([["partyInventory", CAMPAIGN]]);
  });

  it("sends a purse change to the character and the roster", () => {
    expect(
      keysForChange(change("characters", "UPDATE", { id: CHAR, campaign_id: CAMPAIGN }), CAMPAIGN),
    ).toEqual([["characters", CAMPAIGN], ["party", CAMPAIGN]]);
  });

  it("maps every published table to at least one key", () => {
    for (const table of REALTIME_TABLES) {
      expect(keysForChange(change(table, "UPDATE", {}), CAMPAIGN).length).toBeGreaterThan(0);
    }
  });
});

describe("keysAfterReconnect", () => {
  it("covers every key keysForChange can produce", () => {
    const covered = keysAfterReconnect(CAMPAIGN).map((k) => JSON.stringify(k));
    for (const table of REALTIME_TABLES) {
      for (const key of keysForChange(change(table, "DELETE", {}), CAMPAIGN)) {
        expect(covered).toContain(JSON.stringify(key));
      }
    }
  });
});

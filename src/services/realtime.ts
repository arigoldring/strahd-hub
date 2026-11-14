import type { RealtimePostgresChangesPayload } from "@supabase/supabase-js";
import { supabase } from "../lib/supabase";
import { REALTIME_TABLES, type RowChange } from "../lib/realtimeKeys";

export type RealtimeStatus = "connecting" | "live" | "reconnecting";

/**
 * Opens one Realtime channel listening to every table in 170's publication,
 * and returns the function that closes it.
 *
 * NO SERVER-SIDE FILTERS. A postgres_changes filter can only test a column of
 * the changed table, and the sibling tables have no campaign_id. A filter also
 * can't apply to DELETE, whose `old` holds only the primary key. So every
 * event this user's RLS lets through arrives here, and keysForChange throws
 * away what belongs to another campaign. At 5-10 users that's a handful of
 * extra messages.
 *
 * A UNIQUE TOPIC PER CALL. React StrictMode mounts, unmounts and remounts
 * every effect in dev, so this runs twice in quick succession. removeChannel
 * is asynchronous, and reusing the topic can hand the second call the
 * first, still-closing channel. A fresh suffix keeps the two apart. The topic
 * is only a name here; postgres_changes doesn't route on it.
 *
 * Reconnects are supabase-js's job: when the socket drops, the channel
 * reports an error or a timeout and rejoins on its own with backoff. This
 * function only translates those statuses for the caller.
 */
export function subscribeToCampaignChanges(
  campaignId: string,
  onChange: (change: RowChange) => void,
  onStatus: (status: RealtimeStatus) => void,
): () => void {
  const channel = supabase.channel(`campaign:${campaignId}:${crypto.randomUUID()}`);

  for (const table of REALTIME_TABLES) {
    channel.on(
      "postgres_changes",
      { event: "*", schema: "public", table },
      (payload: RealtimePostgresChangesPayload<Record<string, unknown>>) => {
        onChange({
          table,
          eventType: payload.eventType,
          row: payload.eventType === "DELETE" ? payload.old : payload.new,
        });
      },
    );
  }

  channel.subscribe((status, err) => {
    if (status === "SUBSCRIBED") onStatus("live");
    // CLOSED is what our own removeChannel produces; reporting it would flash
    // "reconnecting" on every unmount.
    else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT") {
      if (err) console.error("Realtime:", err);
      onStatus("reconnecting");
    }
  });

  return () => {
    void supabase.removeChannel(channel);
  };
}

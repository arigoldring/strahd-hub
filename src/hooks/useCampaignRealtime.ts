import { useEffect, useState } from "react";
import { useQueryClient, type QueryKey } from "@tanstack/react-query";
import {
  subscribeToCampaignChanges,
  type RealtimeStatus,
} from "../services/realtime";
import { keysAfterReconnect, keysForChange } from "../lib/realtimeKeys";

// How long to wait before checking again whether a write on the key is still
// in flight. Short, because the user is waiting to see the change.
const RETRY_MS = 250;

/**
 * Live updates for one campaign: subscribes while mounted, invalidates the
 * query keys each database change makes stale, and reports the connection's
 * state for the rail's indicator. Mounted once, in Layout, so no page needs to
 * know it exists.
 *
 * A WRITE IN FLIGHT DEFERS ITS KEY'S INVALIDATION. Every write this app makes
 * comes back as an event too (the echo). For the sheet's optimistic fields
 * that's a problem: type 14 then 15, and the echo of 14 refetches the row
 * before 15 lands, snapping the field back to 14 for a beat. So while any
 * mutation whose mutationKey starts with the query key is pending, the
 * invalidation waits and checks again. It is deferred, never dropped: another
 * user's change landing during your write still arrives once your write
 * settles. The optimistic hooks (sheet, resources, companions) carry
 * `[...queryKey, "write"]` mutation keys for this. A mutation without a
 * mutationKey never matches, so the rest of the app is unaffected.
 *
 * Missed events. While the socket is down nothing is queued for us, so when
 * the channel comes back after having been live, every key it covers is
 * invalidated. The first subscribe doesn't do that: the pages have just
 * fetched, and the gap between their fetch and the subscribe is milliseconds.
 * The window-focus refetch (queryClient.ts) is still there as a second net.
 */
export function useCampaignRealtime(campaignId: string): RealtimeStatus {
  const queryClient = useQueryClient();
  const [status, setStatus] = useState<RealtimeStatus>("connecting");

  useEffect(() => {
    setStatus("connecting");
    let hasBeenLive = false;
    const timers = new Set<number>();

    const invalidate = (key: QueryKey) => {
      if (queryClient.isMutating({ mutationKey: key }) > 0) {
        const timer = window.setTimeout(() => {
          timers.delete(timer);
          invalidate(key);
        }, RETRY_MS);
        timers.add(timer);
        return;
      }
      void queryClient.invalidateQueries({ queryKey: key });
    };

    const unsubscribe = subscribeToCampaignChanges(
      campaignId,
      (change) => keysForChange(change, campaignId).forEach(invalidate),
      (next) => {
        setStatus(next);
        if (next !== "live") return;
        if (hasBeenLive) keysAfterReconnect(campaignId).forEach(invalidate);
        hasBeenLive = true;
      },
    );

    return () => {
      unsubscribe();
      timers.forEach((timer) => window.clearTimeout(timer));
    };
  }, [campaignId, queryClient]);

  return status;
}

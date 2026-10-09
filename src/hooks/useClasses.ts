import { errorMessage } from "../lib/errors";
import { getClasses } from "../services/classes";
import { useQuery } from "@tanstack/react-query";

// Keyed by campaign for useFeats' reason: the queryFn closes over campaignId,
// so the key must carry it or the cache lies about what it holds.
export function useClasses(campaignId: string) {
  return useQuery({
    queryKey: ["classes", campaignId],
    queryFn: () =>
      getClasses(campaignId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load classes"));
      }),
  });
}

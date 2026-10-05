import { errorMessage } from "../lib/errors";
import { getRaces } from "../services/races";
import { useQuery } from "@tanstack/react-query";

// useClasses' twin, keyed by campaign for the same reason.
export function useRaces(campaignId: string) {
  return useQuery({
    queryKey: ["races", campaignId],
    queryFn: () =>
      getRaces(campaignId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load races"));
      }),
  });
}

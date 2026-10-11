import { errorMessage } from "../lib/errors";
import { getSubclasses } from "../services/classes";
import { useQuery } from "@tanstack/react-query";

// useClasses' twin, keyed by campaign for the same reason.
export function useSubclasses(campaignId: string) {
  return useQuery({
    queryKey: ["subclasses", campaignId],
    queryFn: () =>
      getSubclasses(campaignId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load subclasses"));
      }),
  });
}

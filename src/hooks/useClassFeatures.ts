import { errorMessage } from "../lib/errors";
import { getClassFeatures } from "../services/classes";
import { useQuery } from "@tanstack/react-query";

// useSubclasses' twin, keyed by campaign for the same reason.
export function useClassFeatures(campaignId: string) {
  return useQuery({
    queryKey: ["classFeatures", campaignId],
    queryFn: () =>
      getClassFeatures(campaignId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load class features"));
      }),
  });
}

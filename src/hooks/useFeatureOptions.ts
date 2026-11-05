import { errorMessage } from "../lib/errors";
import { getFeatureOptions } from "../services/classes";
import { useQuery } from "@tanstack/react-query";

// useClassFeatures' twin, keyed by campaign for the same reason: the query
// keeps this campaign's homebrew and drops every other campaign's.
export function useFeatureOptions(campaignId: string) {
  return useQuery({
    queryKey: ["featureOptions", campaignId],
    queryFn: () =>
      getFeatureOptions(campaignId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load feature options"));
      }),
  });
}

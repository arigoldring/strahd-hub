import { errorMessage } from "../lib/errors";
import { getRaceTraits, getRaces, getSubraces } from "../services/races";
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

// useSubclasses' twin (164).
export function useSubraces(campaignId: string) {
  return useQuery({
    queryKey: ["subraces", campaignId],
    queryFn: () =>
      getSubraces(campaignId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load subraces"));
      }),
  });
}

// useClassFeatures' twin (164).
export function useRaceTraits(campaignId: string) {
  return useQuery({
    queryKey: ["raceTraits", campaignId],
    queryFn: () =>
      getRaceTraits(campaignId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load racial traits"));
      }),
  });
}

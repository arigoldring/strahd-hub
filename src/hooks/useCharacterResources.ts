import {
  clearResourceUses,
  getResourceUses,
  spendResource,
  type ResourceUses,
} from "../services/characterResources";
import { errorMessage } from "../lib/errors";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

// Keyed by character alone, useCharacterSheet's reasoning.
//
// Spending is OPTIMISTIC, like the sheet's toggles: a pip that fills only
// after the round trip reads as "it didn't take", and a player tapping three
// superiority dice in a row taps faster than that. Each tap patches the cache
// and the server's clamp has the last word. The refetch waits until the last
// pending tap has settled. A refetch between two taps would briefly show the
// server's count from before the second one.
export function useCharacterResources(characterId: string) {
  const queryClient = useQueryClient();
  const queryKey = ["characterResources", characterId];
  const mutationKey = ["characterResources", characterId, "write"];

  const { data, isLoading, error } = useQuery({
    queryKey,
    queryFn: () =>
      getResourceUses(characterId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load this character's counters"));
      }),
  });

  const settle = () => {
    // This mutation still counts as pending while its own onSettled runs.
    if (queryClient.isMutating({ mutationKey }) <= 1) {
      void queryClient.invalidateQueries({ queryKey });
    }
  };
  const snapshot = async (patch: (uses: ResourceUses) => ResourceUses) => {
    await queryClient.cancelQueries({ queryKey });
    const previous = queryClient.getQueryData<ResourceUses>(queryKey);
    queryClient.setQueryData<ResourceUses>(queryKey, patch(previous ?? {}));
    return { previous };
  };
  const restore = (
    _err: unknown,
    _vars: unknown,
    context: { previous?: ResourceUses } | undefined,
  ) => {
    queryClient.setQueryData(queryKey, context?.previous);
  };

  const spendMutation = useMutation({
    mutationKey,
    mutationFn: (vars: { key: string; delta: number; cap: number }) =>
      spendResource(characterId, vars.key, vars.delta, vars.cap),
    onMutate: ({ key, delta, cap }) =>
      snapshot((uses) => ({
        ...uses,
        [key]: Math.min(cap, Math.max(0, (uses[key] ?? 0) + delta)),
      })),
    onError: restore,
    onSettled: settle,
  });

  const restMutation = useMutation({
    mutationKey,
    mutationFn: (keys: readonly string[] | "all") => clearResourceUses(characterId, keys),
    onMutate: (keys) =>
      snapshot((uses) =>
        keys === "all"
          ? {}
          : Object.fromEntries(Object.entries(uses).filter(([k]) => !keys.includes(k))),
      ),
    onError: restore,
    onSettled: settle,
  });

  return {
    uses: data,
    isLoading,
    error,
    spend: spendMutation.mutateAsync,
    rest: restMutation.mutateAsync,
  };
}

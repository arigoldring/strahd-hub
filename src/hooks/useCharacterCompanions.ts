import {
  adjustCompanionHp,
  getCompanions,
  restCompanions,
  saveCompanion,
  type Companion,
  type CompanionKind,
  type CompanionPatch,
} from "../services/companions";
import { errorMessage } from "../lib/errors";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

// Keyed by character alone, useCharacterSheet's reasoning: a character id
// already implies one campaign.
//
// Renames, temp HP and typed HP are OPTIMISTIC, like the sheet's number
// fields. Damage and healing are not: the server works the result out (temp
// HP first, the cap), so the cache takes the row it returns, as
// useCharacterSheet's adjustHp does.
export function useCharacterCompanions(characterId: string) {
  const queryClient = useQueryClient();
  const queryKey = ["characterCompanions", characterId];

  const { data, isLoading, error } = useQuery({
    queryKey,
    queryFn: () =>
      getCompanions(characterId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load this character's companions"));
      }),
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey });
  // Replace one kind's entry, or add it if there was no row yet.
  const put = (list: Companion[] | undefined, next: Companion) => [
    ...(list ?? []).filter((c) => c.kind !== next.kind),
    next,
  ];
  const snapshot = async (patch: (list: Companion[]) => Companion[]) => {
    await queryClient.cancelQueries({ queryKey });
    const previous = queryClient.getQueryData<Companion[]>(queryKey);
    queryClient.setQueryData<Companion[]>(queryKey, patch(previous ?? []));
    return { previous };
  };
  const restore = (
    _err: unknown,
    _vars: unknown,
    context: { previous?: Companion[] } | undefined,
  ) => {
    queryClient.setQueryData(queryKey, context?.previous);
  };

  const adjustMutation = useMutation({
    mutationFn: (vars: { kind: CompanionKind; delta: number; cap: number }) =>
      adjustCompanionHp(characterId, vars.kind, vars.delta, vars.cap),
    onSuccess: (companion) => {
      queryClient.setQueryData<Companion[]>(queryKey, (list) => put(list, companion));
    },
  });

  const saveMutation = useMutation({
    mutationFn: (vars: { current: Companion; patch: CompanionPatch }) =>
      saveCompanion(characterId, vars.current.kind, vars.patch),
    onMutate: ({ current, patch }) => snapshot((list) => put(list, { ...current, ...patch })),
    onError: restore,
    onSettled: invalidate,
  });

  const restMutation = useMutation({
    mutationFn: (_vars: void) => restCompanions(characterId),
    onMutate: () => snapshot((list) => list.map((c) => ({ ...c, damage: 0 }))),
    onError: restore,
    onSettled: invalidate,
  });

  return {
    companions: data,
    isLoading,
    error,
    adjustHp: adjustMutation.mutateAsync,
    save: saveMutation.mutateAsync,
    rest: restMutation.mutateAsync,
  };
}

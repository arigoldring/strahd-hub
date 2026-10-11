import {
  adjustCharacterHp,
  getCharacterSheet,
  setClassLevel,
  setProficiency,
  setStartingClass,
  setSubclass,
  updateCharacterStats,
  type CharacterClassEntry,
  type CharacterSheetData,
  type CharacterStatsPatch,
  type ProficiencyKind,
} from "../services/characterSheet";
import type { Ability, ProficiencyLevel } from "../data/rules";
import { errorMessage } from "../lib/errors";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

// Keyed by character alone, useCharacterInventory's reasoning: a character id
// already implies one campaign.
//
// Stats and proficiency writes are OPTIMISTIC, unlike the rest of the app's
// mutations, which invalidate and wait. Those are add/remove buttons where a
// beat of latency is fine; these are number fields and toggles, where a value
// that snaps back until the round trip lands reads as "it didn't take". Each
// optimistic write snapshots the cache, patches it, restores the snapshot on
// error, and invalidates on settle so the server's answer always wins.
//
// The mutations still reject to the caller (mutateAsync), per CLAUDE.md: a
// failed save belongs next to the control that caused it.
export function useCharacterSheet(characterId: string) {
  const queryClient = useQueryClient();
  const queryKey = ["characterSheet", characterId];

  const { data, isLoading, error } = useQuery({
    queryKey,
    queryFn: () =>
      getCharacterSheet(characterId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load this character's sheet"));
      }),
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey });

  // Snapshot, patch, and hand back the snapshot for onError to restore.
  const patchCache = async (
    patch: (sheet: CharacterSheetData) => CharacterSheetData,
  ) => {
    await queryClient.cancelQueries({ queryKey });
    const previous = queryClient.getQueryData<CharacterSheetData>(queryKey);
    if (previous) queryClient.setQueryData(queryKey, patch(previous));
    return { previous };
  };
  const restore = (
    _err: unknown,
    _vars: unknown,
    context: { previous?: CharacterSheetData } | undefined,
  ) => {
    if (context?.previous) queryClient.setQueryData(queryKey, context.previous);
  };

  const updateStatsMutation = useMutation({
    mutationFn: (patch: CharacterStatsPatch) =>
      updateCharacterStats(characterId, patch),
    onMutate: (patch) =>
      patchCache((sheet) => ({
        ...sheet,
        stats: {
          ...sheet.stats,
          ...patch,
          scores: { ...sheet.stats.scores, ...patch.scores },
        },
      })),
    onError: restore,
    onSettled: invalidate,
  });

  const setProficiencyMutation = useMutation({
    mutationFn: (vars: { kind: ProficiencyKind; key: string; level: ProficiencyLevel }) =>
      setProficiency(characterId, vars.kind, vars.key, vars.level),
    onMutate: ({ kind, key, level }) =>
      patchCache((sheet) => {
        const rest = sheet.proficiencies.filter(
          (p) => !(p.kind === kind && p.key === key),
        );
        return {
          ...sheet,
          proficiencies: level === 0 ? rest : [...rest, { kind, key, level }],
        };
      }),
    onError: restore,
    onSettled: invalidate,
  });

  // Not optimistic: the server computes the result (temp HP first, cap at
  // max), so the cache takes the row it returns rather than guessing.
  const adjustHpMutation = useMutation({
    mutationFn: (delta: number) => adjustCharacterHp(characterId, delta),
    onSuccess: (stats) => {
      queryClient.setQueryData<CharacterSheetData>(queryKey, (sheet) =>
        sheet ? { ...sheet, stats } : sheet,
      );
    },
  });

  // Several requests (class row, then saves), so plain invalidate-and-wait.
  const setClassMutation = useMutation({
    mutationFn: (vars: {
      existing: CharacterClassEntry | undefined;
      classId: string;
      saves: readonly Ability[];
    }) => setStartingClass(characterId, vars.existing, vars.classId, vars.saves),
    onSettled: invalidate,
  });

  const setLevelMutation = useMutation({
    mutationFn: (vars: { entryId: string; level: number }) =>
      setClassLevel(vars.entryId, vars.level),
    onMutate: ({ entryId, level }) =>
      patchCache((sheet) => ({
        ...sheet,
        classes: sheet.classes.map((c) => (c.id === entryId ? { ...c, level } : c)),
      })),
    onError: restore,
    onSettled: invalidate,
  });

  const setSubclassMutation = useMutation({
    mutationFn: (vars: { entryId: string; subclassId: string | null }) =>
      setSubclass(vars.entryId, vars.subclassId),
    onMutate: ({ entryId, subclassId }) =>
      patchCache((sheet) => ({
        ...sheet,
        classes: sheet.classes.map((c) =>
          c.id === entryId ? { ...c, subclassId } : c,
        ),
      })),
    onError: restore,
    onSettled: invalidate,
  });

  return {
    data,
    isLoading,
    error,
    updateStats: updateStatsMutation.mutateAsync,
    setProficiency: setProficiencyMutation.mutateAsync,
    adjustHp: adjustHpMutation.mutateAsync,
    setClass: setClassMutation.mutateAsync,
    setLevel: setLevelMutation.mutateAsync,
    setSubclass: setSubclassMutation.mutateAsync,
  };
}

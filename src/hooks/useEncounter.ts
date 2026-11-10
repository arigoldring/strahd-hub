import { useMutation, useQueries, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  addMonsters,
  adjustMonsterHp,
  endEncounter,
  getEncounter,
  getMonsterStats,
  removeCombatant,
  setInitiatives,
  setTurn,
  startEncounter,
  updateCombatant,
  updateMonsterStats,
  type CombatantPatch,
  type Encounter,
  type MonsterStats,
  type MonsterStatsPatch,
  type NewMonsters,
  type StartingPc,
} from "../services/encounters";
import { combatStats, type CombatStats } from "../data/rules";
import { errorMessage } from "../lib/errors";
import { characterSheetQuery } from "./useCharacterSheet";
import { characterFeatsQuery } from "./useCharacterFeats";
import { useClassFeatures } from "./useClassFeatures";
import { useRaces, useSubraces } from "./useRaces";

/**
 * The campaign's live fight and its combatants, under ["encounter",
 * campaignId], the key 172's events invalidate (realtimeKeys.ts). Keyed by
 * campaign, not encounter: the page asks "is there a fight here", and a
 * fight's id doesn't exist until it starts.
 *
 * The turn, initiatives and removals are OPTIMISTIC, the sheet's reasoning:
 * Next is pressed in quick succession, and an initiative is a number field.
 * Each carries the "write" mutationKey so useCampaignRealtime holds back the
 * echo of the last write while the next is in flight. Start, End and Add
 * monster invalidate and wait: they create or destroy rows the cache can't
 * invent ids for.
 */
export function useEncounter(campaignId: string) {
  const queryClient = useQueryClient();
  const queryKey = ["encounter", campaignId];
  const mutationKey = [...queryKey, "write"];

  const { data, isLoading, error } = useQuery({
    queryKey,
    queryFn: () =>
      getEncounter(campaignId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load the fight"));
      }),
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey });
  const patchCache = async (patch: (encounter: Encounter) => Encounter) => {
    await queryClient.cancelQueries({ queryKey });
    const previous = queryClient.getQueryData<Encounter | null>(queryKey);
    if (previous) queryClient.setQueryData(queryKey, patch(previous));
    return { previous };
  };
  const restore = (
    _err: unknown,
    _vars: unknown,
    context: { previous?: Encounter | null } | undefined,
  ) => {
    if (context?.previous !== undefined) queryClient.setQueryData(queryKey, context.previous);
  };

  const startMutation = useMutation({
    mutationKey,
    mutationFn: (pcs: StartingPc[]) => startEncounter(campaignId, pcs),
    onSettled: invalidate,
  });

  const endMutation = useMutation({
    mutationKey,
    mutationFn: (encounterId: string) => endEncounter(encounterId),
    onSettled: (_data, _err, encounterId) => {
      queryClient.removeQueries({ queryKey: ["encounterMonsterStats", encounterId] });
      return invalidate();
    },
  });

  const setTurnMutation = useMutation({
    mutationKey,
    mutationFn: (vars: { encounterId: string; turnId: string | null; round: number }) =>
      setTurn(vars.encounterId, vars),
    onMutate: ({ turnId, round }) =>
      patchCache((e) => ({ ...e, turnCombatantId: turnId, round })),
    onError: restore,
    onSettled: invalidate,
  });

  const addMonstersMutation = useMutation({
    mutationKey,
    mutationFn: (vars: { encounterId: string; monsters: NewMonsters }) =>
      addMonsters(vars.encounterId, vars.monsters),
    onSettled: (_data, _err, { encounterId }) =>
      Promise.all([
        invalidate(),
        queryClient.invalidateQueries({ queryKey: ["encounterMonsterStats", encounterId] }),
      ]),
  });

  const removeMutation = useMutation({
    mutationKey,
    mutationFn: (combatantId: string) => removeCombatant(combatantId),
    onMutate: (combatantId) =>
      patchCache((e) => ({
        ...e,
        combatants: e.combatants.filter((c) => c.id !== combatantId),
        // 171's FK sets the turn to null when its combatant goes.
        turnCombatantId: e.turnCombatantId === combatantId ? null : e.turnCombatantId,
      })),
    onError: restore,
    onSettled: invalidate,
  });

  const updateMutation = useMutation({
    mutationKey,
    mutationFn: (vars: { combatantId: string; patch: CombatantPatch }) =>
      updateCombatant(vars.combatantId, vars.patch),
    onMutate: ({ combatantId, patch }) =>
      patchCache((e) => ({
        ...e,
        combatants: e.combatants.map((c) => (c.id === combatantId ? { ...c, ...patch } : c)),
      })),
    onError: restore,
    onSettled: invalidate,
  });

  const rollMutation = useMutation({
    mutationKey,
    mutationFn: (rolls: { combatantId: string; initiative: number }[]) => setInitiatives(rolls),
    onMutate: (rolls) => {
      const byId = new Map(rolls.map((r) => [r.combatantId, r.initiative]));
      return patchCache((e) => ({
        ...e,
        combatants: e.combatants.map((c) =>
          byId.has(c.id) ? { ...c, initiative: byId.get(c.id)! } : c,
        ),
      }));
    },
    onError: restore,
    onSettled: invalidate,
  });

  return {
    encounter: data,
    isLoading,
    error,
    start: startMutation.mutateAsync,
    end: endMutation.mutateAsync,
    setTurn: setTurnMutation.mutateAsync,
    addMonsters: addMonstersMutation.mutateAsync,
    remove: removeMutation.mutateAsync,
    update: updateMutation.mutateAsync,
    setInitiatives: rollMutation.mutateAsync,
  };
}

/**
 * The monsters' numbers, for the DM only. `enabled` is off for players, not
 * because RLS needs the help (it returns them no rows) but so the page
 * doesn't send a request whose answer is known to be empty.
 *
 * Not published to Realtime (172), so nothing invalidates this from outside:
 * the DM is the only writer, and their own writes update it. A write that
 * changes HP also invalidates the fight, because 171's trigger has just
 * changed that combatant's Bloodied/Down.
 */
export function useMonsterStats(campaignId: string, encounterId: string | null, isDm: boolean) {
  const queryClient = useQueryClient();
  const queryKey = ["encounterMonsterStats", encounterId];

  const { data, isLoading, error } = useQuery({
    queryKey,
    queryFn: () =>
      getMonsterStats(encounterId!).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load the monsters' stats"));
      }),
    enabled: isDm && encounterId !== null,
  });

  const put = (next: MonsterStats) =>
    queryClient.setQueryData<MonsterStats[]>(queryKey, (list) =>
      (list ?? []).map((s) => (s.combatantId === next.combatantId ? next : s)),
    );
  const statusChanged = () => queryClient.invalidateQueries({ queryKey: ["encounter", campaignId] });

  // Not optimistic: the server works out the result (temp HP first, the
  // caps), useCharacterSheet's adjustHp reasoning.
  const adjustMutation = useMutation({
    mutationFn: (vars: { combatantId: string; delta: number }) =>
      adjustMonsterHp(vars.combatantId, vars.delta),
    onSuccess: (stats) => {
      put(stats);
      return statusChanged();
    },
  });

  const updateMutation = useMutation({
    mutationFn: (vars: { current: MonsterStats; patch: MonsterStatsPatch }) =>
      updateMonsterStats(vars.current, vars.patch),
    onMutate: async ({ current, patch }) => {
      await queryClient.cancelQueries({ queryKey });
      const previous = queryClient.getQueryData<MonsterStats[]>(queryKey);
      put({ ...current, ...patch });
      return { previous };
    },
    onError: (_err, _vars, context) => queryClient.setQueryData(queryKey, context?.previous),
    onSettled: () =>
      Promise.all([queryClient.invalidateQueries({ queryKey }), statusChanged()]),
  });

  return {
    stats: data,
    isLoading,
    error,
    adjustHp: adjustMutation.mutateAsync,
    update: updateMutation.mutateAsync,
  };
}

export interface PcCombatInfo extends CombatStats {
  hpCurrent: number;
  hpMax: number;
  hpTemp: number;
}

/**
 * Every PC's DEX, initiative bonus and HP, from their sheets. useQueries
 * with the sheet hooks' own query definitions (characterSheetQuery,
 * characterFeatsQuery), so these are the same cache entries the Sheet page
 * reads, and 170's character_stats events keep the HP live here too.
 *
 * The derivation is rules.ts's combatStats, which shares characterEffects
 * with the sheet, so the initiative bonus here is the one the sheet shows.
 * Members can read every sheet in their campaign (the Party page's rule), so
 * a player's screen gets the same numbers and sorts the same order.
 */
export function usePcCombatInfo(campaignId: string, characterIds: readonly string[]) {
  const { data: features = [] } = useClassFeatures(campaignId);
  const { data: races = [] } = useRaces(campaignId);
  const { data: subraces = [] } = useSubraces(campaignId);
  const sheets = useQueries({ queries: characterIds.map(characterSheetQuery) });
  const feats = useQueries({ queries: characterIds.map(characterFeatsQuery) });

  const info = new Map<string, PcCombatInfo>();
  characterIds.forEach((id, i) => {
    const sheet = sheets[i]?.data;
    const ownFeats = feats[i]?.data;
    if (!sheet || !ownFeats) return;
    const race = races.find((r) => r.id === sheet.stats.raceId) ?? null;
    const subrace = subraces.find((s) => s.id === sheet.stats.subraceId) ?? null;
    info.set(id, {
      ...combatStats({
        scores: sheet.stats.scores,
        classes: sheet.classes,
        features,
        race,
        subrace,
        feats: ownFeats,
      }),
      hpCurrent: sheet.stats.hpCurrent,
      hpMax: sheet.stats.hpMax,
      hpTemp: sheet.stats.hpTemp,
    });
  });

  const failed = [...sheets, ...feats].find((q) => q.error)?.error ?? null;
  return {
    info,
    isLoading: info.size < characterIds.length && !failed,
    error: failed,
  };
}

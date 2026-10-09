import {
  getFortunes,
  setFortunesRevealed,
  setFortuneFound,
  updateFortuneLines,
  Fortune,
} from "../services/fortunes";
import { asPlayerView } from "../lib/playerView";
import { errorMessage } from "../lib/errors";
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";

// Module scope for a stable identity -- see useNpcs.
const fortunesAsPlayer = (fortunes: Fortune[]): Fortune[] =>
  asPlayerView(fortunes);

/**
 * asPlayer re-renders the DM's three cards the way a player's response would
 * arrive: all of them once revealed, none before. Passed in rather than read
 * from the preview context, for the reason useNpcs gives.
 *
 * Mounted twice on a campaign page -- by Layout, to decide whether the nav
 * shows the link, and by the Fortunes page itself. Same key, so one request.
 */
export function useFortunes(
  campaignId: string,
  { asPlayer = false }: { asPlayer?: boolean } = {},
) {
  const queryClient = useQueryClient();
  const { data, isLoading, error } = useQuery({
    queryKey: ["fortunes", campaignId],
    queryFn: () =>
      getFortunes(campaignId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load fortunes"));
      }),
    select: asPlayer ? fortunesAsPlayer : undefined,
  });

  const invalidate = () =>
    queryClient.invalidateQueries({ queryKey: ["fortunes", campaignId] });

  const revealMutation = useMutation({
    mutationFn: (isRevealed: boolean) =>
      setFortunesRevealed(campaignId, isRevealed),
    onSuccess: invalidate,
  });

  const foundMutation = useMutation({
    mutationFn: ({ id, isFound }: { id: string; isFound: boolean }) =>
      setFortuneFound(id, isFound),
    onSuccess: invalidate,
  });

  const saveLinesMutation = useMutation({
    mutationFn: ({ id, lines }: { id: string; lines: string[] }) =>
      updateFortuneLines(id, lines),
    onSuccess: invalidate,
  });

  return {
    data,
    isLoading,
    error,
    // mutate plus the error alongside, useMaps' toggleReveal shape: both are
    // bare clicks with no form to hold a draft open.
    setRevealed: revealMutation.mutate,
    setRevealedError: revealMutation.error,
    revealPending: revealMutation.isPending,
    setFound: foundMutation.mutate,
    setFoundError: foundMutation.error,
    // mutateAsync: the editor awaits it and stays open holding the draft when
    // the save is refused, useNpcs' saveNpc shape.
    saveLines: saveLinesMutation.mutateAsync,
  };
}

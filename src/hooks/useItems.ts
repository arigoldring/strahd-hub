import { errorMessage } from "../lib/errors";
import { getItems, updateItem, type NewItem } from "../services/items";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

// Keyed by campaign because the queryFn closes over campaignId: everything the
// queryFn reads must appear in the key, or the cache entry lies about what it
// holds — a bare ["items"] would serve one campaign's catalogue to another.
export function useItems(campaignId: string) {
  const queryClient = useQueryClient();
  // Destructured, not spread: a spread reads every getter on the result and
  // subscribes the component to all of them — see useLocations.
  const { data, isLoading, error } = useQuery({
    queryKey: ["items", campaignId],
    queryFn: () =>
      getItems(campaignId).catch((err) => {
        throw new Error(errorMessage(err, "Failed to load items"));
      }),
  });

  // An edit lands in place (053), so every cache holding a copy of the item
  // is stale, not just the catalogue: the party hoard, every character pack
  // (toItem runs on their embeds too), and the roster built from those packs.
  // characterInventory is keyed by character, not campaign, so it's
  // invalidated by prefix — every pack in the cache, which for one table of
  // players is a handful of stale marks and nothing fetches until a page
  // showing one is mounted.
  const updateItemMutation = useMutation({
    mutationFn: ({ itemId, input }: { itemId: string; input: NewItem }) =>
      updateItem(itemId, input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["items", campaignId] });
      queryClient.invalidateQueries({
        queryKey: ["partyInventory", campaignId],
      });
      queryClient.invalidateQueries({ queryKey: ["characterInventory"] });
      queryClient.invalidateQueries({ queryKey: ["party", campaignId] });
    },
  });

  // Rejects rather than surfacing through `error`, like every mutation here:
  // the form that called it reports the failure.
  return {
    data,
    isLoading,
    error,
    updateItem: updateItemMutation.mutateAsync,
  };
}

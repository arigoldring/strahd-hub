import { useCampaign } from "../components/CampaignLayout";
import { usePlayerPreview } from "../components/PlayerPreviewContext";

/**
 * The two questions a campaign page asks about its viewer, answered with
 * player preview already taken into account.
 *
 * - `showDmUi`: render DM controls (editors, reveal toggles, authoring links).
 *   False for a player, and false for a DM who is previewing.
 * - `asPlayer`: pass to every reveal-gated read (`useLocations`, `useNpcs`,
 *   `useFortunes`, `useMaps`) as `{ asPlayer }`. True for a player, and true
 *   for a DM who is previewing.
 *
 * `asPlayer` is `!isDm || previewing` everywhere, not just `previewing`. For
 * the RLS-gated tables the extra `!isDm` is a no-op — a player's rows are
 * already all revealed and carry no DM notes, so re-filtering them changes
 * nothing. For the map registry it is load-bearing: maps live client-side, so
 * this flag is the only thing hiding an unrevealed map from a real player
 * (src/data/maps.ts). One expression for both means no page has to know which
 * kind of table it is reading.
 *
 * Kept out of useCampaign() on purpose (see PlayerPreviewContext): the campaign
 * is what the server said and `campaign.isDm` keeps meaning exactly who is
 * signed in, which is what route guards and the preview toggle itself need.
 * Bare `campaign.isDm` in pages and components is checked by
 * src/lib/dmViewDiscipline.test.ts and needs a `dm-identity:` comment.
 */
export function useDmView(): { showDmUi: boolean; asPlayer: boolean } {
  const campaign = useCampaign();
  const { previewing } = usePlayerPreview();
  return {
    showDmUi: campaign.isDm && !previewing,
    asPlayer: !campaign.isDm || previewing,
  };
}

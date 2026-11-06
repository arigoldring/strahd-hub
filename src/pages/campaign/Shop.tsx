import { ReactNode, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { useItems } from "../../hooks/useItems";
import {
  Item,
  type Rarity,
  magicRarities,
  priceLabel,
  rarityLabel,
} from "../../services/items";
import { useCampaign } from "../../components/CampaignLayout";
import { usePlayerPreview } from "../../components/PlayerPreviewContext";
import { addToPartyInventory } from "../../services/partyInventory";
import { errorMessage } from "../../lib/errors";
import {
  EditItemLink,
  ItemDetailCard,
} from "../../components/ItemDetailCard";
import { useSearchBar } from "../../hooks/useSearchBar";
import "./shop.css";

export function Shop() {
  // The campaign in the URL, resolved by CampaignLayout above this route. Both
  // the catalog (shared SRD plus this campaign's homebrew — see getItems) and
  // adding to a party's inventory are scoped to it.
  const campaign = useCampaign();
  const { previewing } = usePlayerPreview();
  // Gates the Edit link on a homebrew card, nothing else. showDmUi rather
  // than bare isDm so player preview shows the card a player would see.
  const showDmUi = campaign.isDm && !previewing;
  const { data: items = [], isLoading: loading, error } = useItems(campaign.id);
  // The open item is held by id, not as the Item itself — same as Maps holds a
  // location id. Storing the object would leave `panel` pointing at whichever
  // object was in the list at click time, so a later edit or refetch (which
  // replaces the row with a new object) would show a stale card beside a fresh
  // table row, and a delete would leave a card for an item that's gone.
  const [panelId, setPanelId] = useState<string | null>(null);
  // The second filter axis, live only while the Magic filter is. Held here
  // rather than in useSearchBar, which knows one filter string; the predicate
  // below closes over it, and it is read on every render, so it never lags.
  const [rarity, setRarity] = useState<Rarity | "">("");
  // "magic" is any item with a rarity, whatever its kind (129: rarity is an
  // axis beside kind). The kind filters exclude magic items, or General would
  // be ~300 wondrous items with the rope buried among them.
  const { filter, setFilter, setSearch, filtered } = useSearchBar(
    items,
    (item, filter) =>
      filter === "magic"
        ? item.rarity !== null && (rarity === "" || item.rarity === rarity)
        : item.kind === filter && item.rarity === null,
  );
  if (loading) return <p>Loading Items...</p>;
  if (error) return <p>Couldn't load items: {error.message}</p>;
  const panel = items.find((item) => item.id === panelId) ?? null;

  // The magic view reads best grouped by rarity, common first; every other
  // view keeps the order it always had.
  const rows =
    filter === "magic"
      ? [...filtered].sort(
          (a, b) =>
            rarityRank(a.rarity) - rarityRank(b.rarity) ||
            a.name.localeCompare(b.name),
        )
      : filtered;

  function chooseFilter(next: string) {
    setFilter(next);
    setRarity("");
  }

  function createTable() {
    return (
      <table>
        <tbody>
          {rows.map((item: Item) => (
            <tr key={item.id}>
              <td>
                <button onClick={() => setPanelId(item.id)}>{item.name}</button>
              </td>
              <td>{priceLabel(item)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    );
  }
  return (
    <>
      <p className="shop-eyebrow">— Village of Barovia —</p>
      <h1 className="shop-title">Bildrath's Mercantile</h1>
      {/* shop.css styles these children positionally, not by class:
          .shop > div:nth-of-type(1) is the filter row, (2) the detail overlay,
          (3) the item list, and .shop > input is the search box. Reordering,
          wrapping, or inserting a sibling div silently restyles the page. */}
      <div className="shop">
        <div>
          <p>Filters</p>
          <button
            className={filter === "" ? "active" : ""}
            onClick={() => chooseFilter("")}
          >
            All
          </button>
          <button
            className={filter === "general" ? "active" : ""}
            onClick={() => chooseFilter("general")}
          >
            general
          </button>
          <button
            className={filter === "armor" ? "active" : ""}
            onClick={() => chooseFilter("armor")}
          >
            Armor
          </button>
          <button
            className={filter === "weapon" ? "active" : ""}
            onClick={() => chooseFilter("weapon")}
          >
            Weapons
          </button>
          <button
            className={filter === "magic" ? "active" : ""}
            onClick={() => chooseFilter("magic")}
          >
            Magic
          </button>
          {/* The rarity row lives inside this same div, after a line break,
              because shop.css styles `.shop > div:nth-of-type(n)` by position:
              a second div here would become the detail overlay's selector. The
              break is a span for the same reason. */}
          {filter === "magic" && (
            <>
              <span className="shop-filter-break" />
              <p>Rarity</p>
              {(["", ...magicRarities] as const).map((r) => (
                <button
                  key={r || "any"}
                  className={`shop-rarity${rarity === r ? " active" : ""}`}
                  onClick={() => setRarity(r)}
                >
                  {r === "" ? "Any" : rarityLabel(r)}
                </button>
              ))}
            </>
          )}
        </div>
        <input
          type="text"
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search for an item"
        ></input>
        {/* Click-outside backdrop. shop.css only promotes this to a fixed
            full-screen overlay while it actually has a child (:has(> div)), so
            with no item selected it stays an inert empty div. The card itself
            stops propagation so clicking inside it doesn't dismiss itself. */}
        <div onClick={() => setPanelId(null)}>
          {panel && (
            <ItemDetailCard
              // key by id so switching items remounts the card, which resets the
              // Add button's per-item state instead of carrying "Added" across.
              key={panel.id}
              item={panel}
              onClose={() => setPanelId(null)}
              footer={
                <AddToPartyInventory
                  campaignId={campaign.id}
                  itemId={panel.id}
                >
                  {showDmUi && (
                    <EditItemLink campaignId={campaign.id} item={panel} />
                  )}
                </AddToPartyInventory>
              }
            />
          )}
        </div>
        {!panel && (
          <p className="item-detail-empty">
            "Looking to arm yourself, are you? Mind the mist on your way out."
            <span className="sub">— select an item to inspect it —</span>
          </p>
        )}
        <div>{createTable()}</div>
      </div>
    </>
  );
}

// Position in magicRarities, so the magic view sorts in the tuple's order.
// Mundane items never reach it (the magic filter excludes them); they would
// sort last.
function rarityRank(rarity: Rarity | null): number {
  return rarity === null ? magicRarities.length : magicRarities.indexOf(rarity);
}

// The one place a Shop item crosses into a campaign's shared loot. Calls the
// service directly rather than usePartyInventory — Shop neither owns nor shows
// that list, and mounting the list hook here would fetch it for nobody — but
// it must still invalidate the list's cache entry: useQueryClient reaches the
// cache without mounting a query, and invalidating an inactive query only
// marks it stale (no fetch), so an add here costs nothing yet still shows up
// in Inventory even once partyInventory gets a nonzero staleTime.
// `children` sits in the same row, after the button: the DM's Edit link
// shares this footer rather than drawing a second ruled-off row beneath it.
function AddToPartyInventory({
  campaignId,
  itemId,
  children,
}: {
  campaignId: string;
  itemId: string;
  children?: ReactNode;
}) {
  const queryClient = useQueryClient();
  const [adding, setAdding] = useState(false);
  const [added, setAdded] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleAdd() {
    setAdding(true);
    setError(null);
    try {
      await addToPartyInventory(campaignId, itemId);
      queryClient.invalidateQueries({
        queryKey: ["partyInventory", campaignId],
      });
      setAdded(true);
    } catch (err) {
      console.error("Problem adding to party inventory:", err);
      setError(errorMessage(err, "Couldn't add this to the party's inventory"));
    } finally {
      setAdding(false);
    }
  }

  return (
    <div className="item-detail-add-row">
      <button className="item-detail-add" onClick={handleAdd} disabled={adding}>
        {adding
          ? "Adding..."
          : added
            ? "Add another"
            : "Add to party inventory"}
      </button>
      {children}
      {/* "Add another" and a note, rather than a disabled button, because a
          second add is a real action — buying a second torch. Since 031 each
          click raises the party's stack of this item by one instead of filing a
          second row, so the label describes what the party gets, and the button
          stays live because there is now a constraint keeping the list clean
          rather than a UI rule hoping it stays that way. */}
      {added && !error && (
        <span className="item-detail-add-note">
          Added to the party's inventory.
        </span>
      )}
      {error && <span className="item-detail-add-error">{error}</span>}
    </div>
  );
}

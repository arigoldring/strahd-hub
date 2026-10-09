import { Navigate, useLocation, useNavigate, useParams } from "react-router-dom";
import { useCampaign } from "../../components/CampaignLayout";
import { useItems } from "../../hooks/useItems";
import { type NewItem } from "../../services/items";
import { HomebrewItemForm } from "./CreateItem";
import "./createItem.css";

// Where the Edit button was pressed, carried in router state so Save and
// Cancel land back there (the Shop card or the hoard rail). Absent on a
// direct visit or a refresh, which falls back to the Shop: the catalogue is
// where every item, homebrew included, can be found again.
type EditItemState = { returnTo?: string } | null;

export function EditItem() {
  const campaign = useCampaign();
  const navigate = useNavigate();
  const location = useLocation();
  const { itemId } = useParams();
  const { data: items, isLoading, error, updateItem } = useItems(campaign.id);

  const returnTo =
    (location.state as EditItemState)?.returnTo ??
    `/campaign/${campaign.id}/Shop`;

  // Same guard as CreateItem: bare isDm, not showDmUi, so toggling player
  // preview doesn't throw the DM off a half-finished edit. 053 refuses a
  // non-DM's save regardless.
  if (!campaign.isDm)
    return <Navigate to={`/campaign/${campaign.id}`} replace />;
  if (isLoading) return <p>Loading item...</p>;
  if (error) return <p>Couldn't load items: {error.message}</p>;

  // Looked up in the campaign's catalogue rather than fetched by id: getItems
  // already holds exactly the items this campaign may see, so an id from
  // another campaign simply isn't found. A shared item is found but refused
  // here, before the form, because 053 would refuse it at save time anyway.
  const item = items?.find((candidate) => candidate.id === itemId);
  if (!item || !item.isHomebrew)
    return <Navigate to={returnTo} replace />;

  const editingId = item.id;
  async function handleSave(input: NewItem) {
    await updateItem({ itemId: editingId, input });
    navigate(returnTo);
  }

  return (
    <div className="create-item">
      <p className="create-item__eyebrow">⚒ The Forge ⚒</p>
      <h1>Edit {item.name}</h1>
      <p className="create-item__sub">
        Changed in place: every stack of this item, in the hoard and in every
        pack, shows the new version.{" "}
        <button
          type="button"
          className="create-item-link"
          onClick={() => navigate(returnTo)}
        >
          Cancel
        </button>
      </p>
      {/* Keyed on the id so the form's state is seeded from this item once and
          not reused if the route param changes under a mounted page. */}
      <HomebrewItemForm
        key={item.id}
        initial={item}
        onSubmit={handleSave}
        submitLabel="Save Changes"
        savingLabel="Saving..."
      />
    </div>
  );
}

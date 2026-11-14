import { Navigate, useNavigate } from "react-router-dom";
import { SubmitEvent, useState } from "react";
import { useCampaign } from "../../components/CampaignLayout";
import { usePartyInventory } from "../../hooks/usePartyInventory";
import { useItems } from "../../hooks/useItems";
import {
  type Item,
  type NewItem,
  type Rarity,
  type Weapon,
  magicRarities,
  rarityLabel,
  armorCategories,
  damageTypes,
  weaponCategories,
  weaponProperties,
} from "../../services/items";
import { errorMessage } from "../../lib/errors";
import "./createItem.css";

export function CreateItem() {
  const campaign = useCampaign();
  const navigate = useNavigate();
  const { createHomeBrewItem } = usePartyInventory(campaign.id);

  // dm-identity: route guard; preview must not bounce a DM off this page.
  if (!campaign.isDm)
    return <Navigate to={`/campaign/${campaign.id}`} replace />;

  async function handleCreate(input: NewItem) {
    await createHomeBrewItem(input);
    navigate(`/campaign/${campaign.id}/Inventory`);
  }

  return (
    <div className="create-item">
      <p className="create-item__eyebrow">⚒ The Forge ⚒</p>
      <h1>New Homebrew Item</h1>
      <p className="create-item__sub">
        Saved straight into this campaign's hoard — you'll land in the Inventory
        when it's made.
      </p>
      <HomebrewItemForm
        onSubmit={handleCreate}
        submitLabel="Create Item"
        savingLabel="Creating..."
      />
    </div>
  );
}

/**
 * The forge's fields, shared by CreateItem and EditItem. `initial` is the item
 * being edited; without it every field starts blank. It seeds state once, on
 * mount — a refetch mid-edit does not overwrite what the DM is typing, which
 * is why EditItem keys this on the item id rather than passing a live object.
 *
 * Every kind's fields are seeded, not only the item's own, so switching a
 * weapon to armor and back restores the weapon's stats. Only the visible
 * kind's fields are submitted; updateItem nulls the rest (001's checks).
 */
export function HomebrewItemForm({
  initial,
  onSubmit,
  submitLabel,
  savingLabel,
}: {
  initial?: Item;
  onSubmit: (input: NewItem) => Promise<void>;
  submitLabel: string;
  savingLabel: string;
}) {
  const weapon = initial?.kind === "weapon" ? initial : undefined;
  const armor = initial?.kind === "armor" ? initial : undefined;

  // The bases a magic weapon may name: shared, mundane weapons (161's
  // check_item_base_weapon refuses anything else).
  const campaign = useCampaign();
  const { data: catalogue = [] } = useItems(campaign.id);
  const baseWeapons = catalogue
    .filter((i): i is Weapon => i.kind === "weapon" && !i.isHomebrew && i.rarity === null)
    .sort((a, b) => a.name.localeCompare(b.name));
  const [baseWeaponId, setBaseWeaponId] = useState(weapon?.baseWeaponId ?? "");
  // "" is no bonus. Only offered on a magic weapon; 161 refuses it on a
  // mundane item, and toAuthoredColumns drops it if the rarity goes back.
  const [magicBonus, setMagicBonus] = useState(
    weapon?.magicBonus != null ? String(weapon.magicBonus) : "",
  );

  const [kind, setKind] = useState<"general" | "weapon" | "armor">(
    initial?.kind ?? "general",
  );
  const [name, setName] = useState(initial?.name ?? "");
  const [description, setDescription] = useState(initial?.description ?? "");
  const [price, setPrice] = useState(
    initial ? String(initial.price) : "",
  );
  const [tagsInput, setTagsInput] = useState(initial?.tags.join(", ") ?? "");
  // "" is mundane in the <select>; it becomes null on submit (129).
  const [rarity, setRarity] = useState<Rarity | "">(initial?.rarity ?? "");
  const [requiresAttunement, setRequiresAttunement] = useState(
    initial?.requiresAttunement ?? false,
  );
  const [attunementNote, setAttunementNote] = useState(
    initial?.attunementNote ?? "",
  );

  const [weaponCategory, setWeaponCategory] = useState<"simple" | "martial">(
    weapon?.category ?? "simple",
  );
  const [damageDice, setDamageDice] = useState(weapon?.damageDice ?? "");
  const [damageType, setDamageType] = useState<
    | "acid"
    | "bludgeoning"
    | "cold"
    | "fire"
    | "force"
    | "lightning"
    | "necrotic"
    | "piercing"
    | "poison"
    | "psychic"
    | "radiant"
    | "slashing"
    | "thunder"
  >(weapon?.damageType ?? "piercing");
  const [properties, setProperties] = useState<Set<string>>(
    () => new Set(weapon?.properties ?? []),
  );
  const [versatileDice, setVersatileDice] = useState(
    weapon?.versatileDice ?? "",
  );
  const [rangeNormal, setRangeNormal] = useState(
    weapon?.rangeNormal != null ? String(weapon.rangeNormal) : "",
  );
  const [rangeLong, setRangeLong] = useState(
    weapon?.rangeLong != null ? String(weapon.rangeLong) : "",
  );

  const [armorCategory, setArmorCategory] = useState<
    "light" | "medium" | "heavy" | "shield"
  >(armor?.category ?? "light");
  const [baseArmorClass, setBaseArmorClass] = useState(
    armor ? String(armor.baseArmorClass) : "",
  );
  const [strengthRequirement, setStrengthRequirement] = useState(
    armor?.strengthRequirement != null ? String(armor.strengthRequirement) : "",
  );
  const [stealthDisadvantage, setStealthDisadvantage] = useState(
    armor?.stealthDisadvantage ?? false,
  );

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Picking a base copies its stats onto the form, which the DM can still
  // change. Copied rather than read through the link because 001's checks
  // need a weapon row to carry its own dice.
  function pickBase(id: string) {
    setBaseWeaponId(id);
    const base = baseWeapons.find((w) => w.id === id);
    if (!base) return;
    setWeaponCategory(base.category);
    setDamageDice(base.damageDice);
    setDamageType(base.damageType);
    setProperties(new Set(base.properties));
    setVersatileDice(base.versatileDice ?? "");
    setRangeNormal(base.rangeNormal != null ? String(base.rangeNormal) : "");
    setRangeLong(base.rangeLong != null ? String(base.rangeLong) : "");
  }

  function toggleProperty(prop: string) {
    const newSet = new Set(properties);
    if (newSet.has(prop)) {
      newSet.delete(prop);
    } else {
      newSet.add(prop);
    }
    setProperties(newSet);
  }

  async function handleSubmit(e: SubmitEvent<HTMLFormElement>) {
    e.preventDefault();

    if (!name.trim()) {
      setError("Name is required");
      return;
    }

    if (!description.trim()) {
      setError("Description is required");
      return;
    }

    if (!price || isNaN(Number(price)) || Number(price) < 0) {
      setError("Price must be a valid non-negative number");
      return;
    }

    const tags = tagsInput
      .split(",")
      .map((t) => t.trim())
      .filter((t) => t.length > 0);

    // The same three fields on every kind, since rarity is an axis beside kind.
    // toAuthoredColumns drops attunement on a mundane item, so switching the
    // rarity back to None can't trip 129's CHECKs with a stale checkbox.
    const magic = {
      rarity: rarity === "" ? null : rarity,
      requiresAttunement,
      attunementNote: attunementNote.trim() || undefined,
    };

    let input: NewItem;

    if (kind === "weapon") {
      if (!damageDice.trim()) {
        setError("Damage dice is required for weapons");
        return;
      }

      input = {
        kind: "weapon",
        name: name.trim(),
        description: description.trim(),
        price: Number(price),
        tags,
        ...magic,
        category: weaponCategory,
        damageDice: damageDice.trim(),
        damageType,
        properties: Array.from(properties) as any[],
        versatileDice: versatileDice.trim() || undefined,
        rangeNormal: rangeNormal ? Number(rangeNormal) : undefined,
        rangeLong: rangeLong ? Number(rangeLong) : undefined,
        magicBonus: magicBonus ? Number(magicBonus) : undefined,
        baseWeaponId: baseWeaponId || undefined,
      };
    } else if (kind === "armor") {
      if (!baseArmorClass || isNaN(Number(baseArmorClass))) {
        setError("Armor Class is required and must be a number");
        return;
      }

      input = {
        kind: "armor",
        name: name.trim(),
        description: description.trim(),
        price: Number(price),
        tags,
        ...magic,
        category: armorCategory,
        baseArmorClass: Number(baseArmorClass),
        strengthRequirement: strengthRequirement
          ? Number(strengthRequirement)
          : undefined,
        stealthDisadvantage,
        // Not offered on armour yet (nothing reads it); kept so an edit
        // doesn't wipe one set some other way.
        magicBonus: armor?.magicBonus,
      };
    } else {
      input = {
        kind: "general",
        name: name.trim(),
        description: description.trim(),
        price: Number(price),
        tags,
        ...magic,
      };
    }

    setSaving(true);
    setError(null);
    try {
      await onSubmit(input);
    } catch (err) {
      console.error("Problem saving homebrew item:", err);
      setError(errorMessage(err, "Couldn't save this item"));
      setSaving(false);
    }
  }

  return (
    <form className="create-item-form" onSubmit={handleSubmit}>
      <fieldset className="create-item-section">
        <legend>Basic Info</legend>

        <label className="create-item-label" htmlFor="name">
          Name *
        </label>
        <input
          id="name"
          className="create-item-input"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          disabled={saving}
          required
        />

        <label className="create-item-label" htmlFor="description">
          Description *
        </label>
        <textarea
          id="description"
          className="create-item-input create-item-textarea"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          disabled={saving}
          required
          rows={4}
        />

        <label className="create-item-label" htmlFor="price">
          Price (gold) *
        </label>
        <input
          id="price"
          className="create-item-input"
          type="number"
          min="0"
          step="0.01"
          value={price}
          onChange={(e) => setPrice(e.target.value)}
          disabled={saving}
          required
        />

        <label className="create-item-label" htmlFor="tags">
          Tags <span className="create-item-hint">(comma-separated)</span>
        </label>
        <input
          id="tags"
          className="create-item-input"
          type="text"
          value={tagsInput}
          onChange={(e) => setTagsInput(e.target.value)}
          disabled={saving}
          placeholder="e.g. consumable, potion, rare"
        />
      </fieldset>

      <fieldset className="create-item-section">
        <legend>Type</legend>

        <div className="create-item-kind-selector">
          {["general", "weapon", "armor"].map((k) => (
            <label key={k} className="create-item-radio-label">
              <input
                type="radio"
                name="kind"
                value={k}
                checked={kind === k}
                onChange={(e) =>
                  setKind(e.target.value as "general" | "weapon" | "armor")
                }
                disabled={saving}
              />
              {k.charAt(0).toUpperCase() + k.slice(1)}
            </label>
          ))}
        </div>
      </fieldset>

      <fieldset className="create-item-section">
        <legend>Magic</legend>

        <label className="create-item-label" htmlFor="rarity">
          Rarity
        </label>
        <select
          id="rarity"
          className="create-item-input"
          value={rarity}
          onChange={(e) => setRarity(e.target.value as Rarity | "")}
          disabled={saving}
        >
          <option value="">None (mundane)</option>
          {magicRarities.map((r) => (
            <option key={r} value={r}>
              {rarityLabel(r)}
            </option>
          ))}
        </select>

        {rarity !== "" && (
          <>
            <label className="create-item-radio-label">
              <input
                type="checkbox"
                checked={requiresAttunement}
                onChange={(e) => setRequiresAttunement(e.target.checked)}
                disabled={saving}
              />
              Requires attunement
            </label>
            {requiresAttunement && (
              <>
                <label className="create-item-label" htmlFor="attunementNote">
                  Attuned by{" "}
                  <span className="create-item-hint">(optional)</span>
                </label>
                <input
                  id="attunementNote"
                  className="create-item-input"
                  type="text"
                  value={attunementNote}
                  onChange={(e) => setAttunementNote(e.target.value)}
                  disabled={saving}
                  placeholder="e.g. by a cleric or paladin"
                />
              </>
            )}
            {kind === "weapon" && (
              <>
                <label className="create-item-label" htmlFor="magicBonus">
                  Bonus to attack and damage
                </label>
                <select
                  id="magicBonus"
                  className="create-item-input"
                  value={magicBonus}
                  onChange={(e) => setMagicBonus(e.target.value)}
                  disabled={saving}
                >
                  <option value="">None</option>
                  <option value="1">+1</option>
                  <option value="2">+2</option>
                  <option value="3">+3</option>
                </select>
              </>
            )}
          </>
        )}
      </fieldset>

      {kind === "weapon" && (
        <fieldset className="create-item-section">
          <legend>Weapon Stats</legend>

          <label className="create-item-label" htmlFor="base-weapon">
            Base weapon{" "}
            <span className="create-item-hint">
              (decides proficiency; fills in the stats below)
            </span>
          </label>
          <select
            id="base-weapon"
            className="create-item-select"
            value={baseWeaponId}
            onChange={(e) => pickBase(e.target.value)}
            disabled={saving}
          >
            <option value="">None (its own weapon)</option>
            {baseWeapons.map((w) => (
              <option key={w.id} value={w.id}>
                {w.name}
              </option>
            ))}
          </select>

          <label className="create-item-label" htmlFor="weapon-category">
            Category *
          </label>
          <select
            id="weapon-category"
            className="create-item-select"
            value={weaponCategory}
            onChange={(e) =>
              setWeaponCategory(e.target.value as "simple" | "martial")
            }
            disabled={saving}
          >
            {weaponCategories.map((cat) => (
              <option key={cat} value={cat}>
                {cat.charAt(0).toUpperCase() + cat.slice(1)}
              </option>
            ))}
          </select>

          <label className="create-item-label" htmlFor="damage-dice">
            Damage Dice *
          </label>
          <input
            id="damage-dice"
            className="create-item-input"
            type="text"
            value={damageDice}
            onChange={(e) => setDamageDice(e.target.value)}
            disabled={saving}
            placeholder="e.g. 1d8, 2d6"
            required
          />

          <label className="create-item-label" htmlFor="damage-type">
            Damage Type *
          </label>
          <select
            id="damage-type"
            className="create-item-select"
            value={damageType}
            onChange={(e) => setDamageType(e.target.value as any)}
            disabled={saving}
          >
            {damageTypes.map((dt) => (
              <option key={dt} value={dt}>
                {dt.charAt(0).toUpperCase() + dt.slice(1)}
              </option>
            ))}
          </select>

          <fieldset className="create-item-checkboxes">
            <legend>Properties</legend>
            {weaponProperties.map((prop) => (
              <label key={prop} className="create-item-checkbox-label">
                <input
                  type="checkbox"
                  checked={properties.has(prop)}
                  onChange={() => toggleProperty(prop)}
                  disabled={saving}
                />
                {prop.charAt(0).toUpperCase() + prop.slice(1)}
              </label>
            ))}
          </fieldset>

          <label className="create-item-label" htmlFor="versatile-dice">
            Versatile Dice
          </label>
          <input
            id="versatile-dice"
            className="create-item-input"
            type="text"
            value={versatileDice}
            onChange={(e) => setVersatileDice(e.target.value)}
            disabled={saving}
            placeholder="e.g. 1d10"
          />

          <label className="create-item-label" htmlFor="range-normal">
            Range (normal)
          </label>
          <input
            id="range-normal"
            className="create-item-input"
            type="number"
            min="0"
            value={rangeNormal}
            onChange={(e) => setRangeNormal(e.target.value)}
            disabled={saving}
            placeholder="feet"
          />

          <label className="create-item-label" htmlFor="range-long">
            Range (long)
          </label>
          <input
            id="range-long"
            className="create-item-input"
            type="number"
            min="0"
            value={rangeLong}
            onChange={(e) => setRangeLong(e.target.value)}
            disabled={saving}
            placeholder="feet"
          />
        </fieldset>
      )}

      {kind === "armor" && (
        <fieldset className="create-item-section">
          <legend>Armor Stats</legend>

          <label className="create-item-label" htmlFor="armor-category">
            Category *
          </label>
          <select
            id="armor-category"
            className="create-item-select"
            value={armorCategory}
            onChange={(e) =>
              setArmorCategory(
                e.target.value as "light" | "medium" | "heavy" | "shield",
              )
            }
            disabled={saving}
          >
            {armorCategories.map((cat) => (
              <option key={cat} value={cat}>
                {cat.charAt(0).toUpperCase() + cat.slice(1)}
              </option>
            ))}
          </select>

          <label className="create-item-label" htmlFor="base-ac">
            Armor Class *
          </label>
          <input
            id="base-ac"
            className="create-item-input"
            type="number"
            min="1"
            value={baseArmorClass}
            onChange={(e) => setBaseArmorClass(e.target.value)}
            disabled={saving}
            required
          />

          <label className="create-item-label" htmlFor="strength-req">
            Strength Requirement
          </label>
          <input
            id="strength-req"
            className="create-item-input"
            type="number"
            min="1"
            max="20"
            value={strengthRequirement}
            onChange={(e) => setStrengthRequirement(e.target.value)}
            disabled={saving}
            placeholder="e.g. 15"
          />

          <label className="create-item-checkbox-label">
            <input
              type="checkbox"
              checked={stealthDisadvantage}
              onChange={(e) => setStealthDisadvantage(e.target.checked)}
              disabled={saving}
            />
            Stealth Disadvantage
          </label>
        </fieldset>
      )}

      <div className="create-item-actions">
        <button
          type="submit"
          className="create-item-btn create-item-btn--primary"
          disabled={saving}
        >
          {saving ? savingLabel : submitLabel}
        </button>
      </div>

      {error && <p className="create-item-error">{error}</p>}
    </form>
  );
}

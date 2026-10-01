import { supabase } from "../lib/supabase";
import { parseOneOf, requireField } from "../lib/parse";
import type {
  Tables,
  TablesInsert,
  TablesUpdate,
} from "../types/database.types";
/**
 * Item is how the rest of the app sees an item; the DB row shape comes from the
 * generated Database types via the typed supabase client, and getItems maps one
 * into the other.
 *
 * Prices are stored in copper (price_cp) and exposed as gold — hence the /100.
 * The generated row marks description as nullable (the DB column is), so it's
 * routed through requireField (lib/parse) like every other required field.
 */
export interface ItemBase {
  id: string;
  name: string;
  price: number;
  description: string;
  tags: string[];
  // True for this campaign's homebrew (campaign_id not null), false for the
  // shared catalogue. Only homebrew is editable (053), so this decides whether
  // a DM sees an Edit button. Not campaignId itself: getItems has already
  // narrowed to shared-or-this-campaign, so "not shared" is enough.
  isHomebrew: boolean;
}
export const weaponProperties = [
  "ammunition",
  "finesse",
  "heavy",
  "light",
  "loading",
  "reach",
  "special",
  "thrown",
  "two-handed",
  "versatile",
] as const;
export type WeaponProperty = (typeof weaponProperties)[number];

export const damageTypes = [
  "acid",
  "bludgeoning",
  "cold",
  "fire",
  "force",
  "lightning",
  "necrotic",
  "piercing",
  "poison",
  "psychic",
  "radiant",
  "slashing",
  "thunder",
] as const;

export type DamageType = (typeof damageTypes)[number];

export const weaponCategories = ["simple", "martial"] as const;
export type WeaponCategory = (typeof weaponCategories)[number];

export const armorCategories = ["light", "medium", "heavy", "shield"] as const;
export type ArmorCategory = (typeof armorCategories)[number];

export interface GeneralItem extends ItemBase {
  kind: "general";
}

export interface Weapon extends ItemBase {
  kind: "weapon";
  category: WeaponCategory;
  damageDice: string;
  damageType: DamageType;
  properties: WeaponProperty[];
  versatileDice?: string;
  rangeNormal?: number;
  rangeLong?: number;
}

export interface Armor extends ItemBase {
  kind: "armor";
  baseArmorClass: number;
  category: ArmorCategory;
  strengthRequirement?: number;
  stealthDisadvantage: boolean;
}

export type Item = GeneralItem | Weapon | Armor;

// isHomebrew is omitted along with id because neither is the author's to
// choose: a client write is always homebrew (025's INSERT check, 053's pin).
export type NewItem =
  | Omit<GeneralItem, "id" | "isHomebrew">
  | Omit<Weapon, "id" | "isHomebrew">
  | Omit<Armor, "id" | "isHomebrew">;

// Maps one items row into the app's Item. Explicit fields (vs `...row`)
// intentionally drop price_cp and created_at.
//
// Exported because party_inventory reads these same items through a join and
// maps them with this exact logic (services/partyInventory.ts). It takes a
// plain items row, so a join caller passes the nested row.items — not the whole
// joined row — and merges its own columns on afterward.
export function toItem(row: Tables<"items">): Item {
  // Composed once per row: every parse below leads its error with it, so a
  // failure names the offending item instead of just the field.
  const subject = `Item ${row.id}`;
  const base: ItemBase = {
    id: row.id,
    name: row.name,
    description: requireField(row.description, "description", subject),
    price: row.price_cp / 100,
    tags: row.tags,
    isHomebrew: row.campaign_id !== null,
  };
  switch (row.kind) {
    case "weapon":
      return {
        ...base,
        kind: "weapon",
        category: parseOneOf(
          requireField(row.weapon_category, "weapon_category", subject),
          weaponCategories,
          "weapon_category",
          subject,
        ),
        damageDice: requireField(row.damage_dice, "damage_dice", subject),
        damageType: parseOneOf(
          requireField(row.damage_type, "damage_type", subject),
          damageTypes,
          "damage_type",
          subject,
        ),
        // parseOneOf takes one string and returns one WeaponProperty, so map
        // lifts it to arrays for free — the result types as WeaponProperty[]
        // with no cast at all. `?.` short-circuits the null column to [].
        properties:
          row.properties?.map((p) =>
            parseOneOf(p, weaponProperties, "properties", subject),
          ) ?? [],
        versatileDice: row.versatile_dice ?? undefined,
        rangeNormal: row.range_normal ?? undefined,
        rangeLong: row.range_long ?? undefined,
      };
    case "armor":
      return {
        ...base,
        kind: "armor",
        baseArmorClass: requireField(
          row.base_armor_class,
          "base_armor_class",
          subject,
        ),
        category: parseOneOf(
          requireField(row.armor_category, "armor_category", subject),
          armorCategories,
          "armor_category",
          subject,
        ),
        strengthRequirement: row.strength_requirement ?? undefined,
        // Not defaulted with `?? false`: that would quietly turn missing data
        // into a confident "no" while every other field here treats null as
        // an error.
        // Safe to require: armor_fields_required (001) guarantees non-null
        // whenever kind = 'armor'. The column itself stays nullable — it has
        // to, since armor_fields_absent needs it null on every other row.
        stealthDisadvantage: requireField(
          row.stealth_disadvantage,
          "stealth_disadvantage",
          subject,
        ),
      };
    case "general":
      return { ...base, kind: "general" };
    // Not a fallback: a typo'd kind used to silently become a GeneralItem
    // with its weapon fields dropped. Fails at the boundary instead.
    // TS can't check exhaustiveness here because row.kind is `string` — the
    // `never` trick belongs in the render switch, where the input is Item.
    default:
      throw new Error(`Unknown item kind "${row.kind}" on item ${row.id}`);
  }
}

// The columns an item's kind decides, each at the value it must hold on a row
// of any other kind: 001's *_fields_absent checks require them null whenever
// the kind doesn't use them. An insert gets that for free (unset columns
// default to null); an update does not. Turning a weapon into a general item
// must null its weapon columns explicitly, or the old values stay behind and
// the check refuses the save.
const KIND_FIELDS_CLEARED = {
  weapon_category: null,
  damage_dice: null,
  damage_type: null,
  properties: null,
  versatile_dice: null,
  range_normal: null,
  range_long: null,
  armor_category: null,
  base_armor_class: null,
  strength_requirement: null,
  stealth_disadvantage: null,
} satisfies TablesUpdate<"items">;

// Every author-controlled column for this input, campaign_id excluded. Shared
// by insert (which adds the campaign) and update (which must not send one;
// pin_item_row would discard it anyway).
function toAuthoredColumns(input: NewItem) {
  const base = {
    ...KIND_FIELDS_CLEARED,
    name: input.name,
    description: input.description,
    price_cp: Math.round(input.price * 100),
    tags: input.tags,
    kind: input.kind,
  };

  switch (input.kind) {
    case "weapon":
      return {
        ...base,
        weapon_category: input.category,
        damage_dice: input.damageDice,
        damage_type: input.damageType,
        properties: input.properties.length > 0 ? input.properties : null,
        versatile_dice: input.versatileDice ?? null,
        range_normal: input.rangeNormal ?? null,
        range_long: input.rangeLong ?? null,
      };
    case "armor":
      return {
        ...base,
        armor_category: input.category,
        base_armor_class: input.baseArmorClass,
        strength_requirement: input.strengthRequirement ?? null,
        stealth_disadvantage: input.stealthDisadvantage,
      };
    case "general":
      return base;
  }
}

function toInsertRow(
  campaignId: string,
  input: NewItem,
): TablesInsert<"items"> {
  return { campaign_id: campaignId, ...toAuthoredColumns(input) };
}

// Scoped to shared-or-this-campaign, not left to RLS: RLS answers "may this
// viewer see this row", and a member of two campaigns passes that check for
// both campaigns' homebrew — the query itself has to narrow to the campaign
// being viewed. .or() takes a raw PostgREST filter string, so campaignId is
// spliced into it rather than passed as a parameter (the only splice in this
// codebase; .in() can't express "is null", so .or() is the right tool). That's
// acceptable because CampaignLayout has already validated the id against the
// viewer's own campaign list, and RLS remains the boundary regardless — a
// malformed id makes a bad query, not a leak.
export async function getItems(campaignId: string): Promise<Item[]> {
  const { data: items, error: retrievalError } = await supabase
    .from("items")
    .select("*")
    .or(`campaign_id.is.null,campaign_id.eq.${campaignId}`);
  if (retrievalError) {
    console.error(retrievalError);
    throw retrievalError;
  }

  // NOTE: a throw in toItem aborts the whole map, so one malformed row hides
  // all the good ones. That's the right tradeoff while seeding (fail loud, fix
  // the row) but revisit once the data is stable.
  return items.map(toItem);
}

export async function createItem(
  campaignId: string,
  input: NewItem,
): Promise<Item> {
  const { data, error } = await supabase
    .from("items")
    .insert(toInsertRow(campaignId, input))
    .select("*")
    .single();

  if (error) {
    console.error(error);
    throw error;
  }

  return toItem(data);
}

// Edits a homebrew item in place, so every stack holding it (the party hoard,
// every character's pack) reads the new values on its next fetch. 053 allows
// this for the campaign's DM on homebrew only. A shared row, another
// campaign's row or a non-DM caller is refused, and a refused UPDATE raises
// nothing: it matches zero rows and returns 200. Hence .maybeSingle(), with
// "no row came back" turned into the error the form shows.
export async function updateItem(
  itemId: string,
  input: NewItem,
): Promise<Item> {
  const update: TablesUpdate<"items"> = toAuthoredColumns(input);
  const { data, error } = await supabase
    .from("items")
    .update(update)
    .eq("id", itemId)
    .select("*")
    .maybeSingle();

  if (error) {
    console.error(error);
    throw error;
  }
  if (!data) {
    throw new Error(
      "This item can't be edited. Only this campaign's DM can edit its homebrew.",
    );
  }

  return toItem(data);
}

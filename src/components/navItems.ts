/**
 * Every destination in the campaign chrome, in rail order. One list, because
 * there are now two navs reading it — the desktop rail and the phone tab bar —
 * and two hand-written lists is how a new page ends up reachable on one device
 * and not the other.
 *
 * `tab` marks the four that get a slot on the phone's bottom bar; everything
 * else lands in its More sheet. Chosen by what the table actually opens
 * mid-session on a phone (Maps, NPCs, Recaps), plus Home as the way back.
 */
export interface NavItem {
  to: string;
  label: (isDm: boolean) => string;
  /** NavLink's `end`: only the index route needs it, or Home is always lit. */
  end?: boolean;
  dmOnly?: boolean;
  /** A slot on the phone tab bar. Four at most — a fifth is More. */
  tab?: boolean;
  /** Below the rule: the doors out of the campaign's content. */
  footer?: boolean;
  /**
   * Hidden from players until Madam Eva's reading is revealed (065). A DM
   * always sees it, styled as a DM link until the players can too.
   */
  hiddenUntilRead?: boolean;
}

export const NAV_ITEMS: NavItem[] = [
  { to: ".", label: () => "Home", end: true, tab: true },
  // A DM has no PC of their own — Character.tsx dispatches to a roster of the
  // campaign's players for them instead of the create/own-sheet flow, so the
  // label says which one this link is about to open.
  { to: "Character", label: (isDm) => (isDm ? "Characters" : "Character") },
  // The full sheet (054-057). Beside Character until it replaces it.
  { to: "Sheet", label: () => "Sheet" },
  // Directly after Character, because Inventory is now half a personal page —
  // your own pack, with the party's hoard beside it — rather than the shared
  // pile alone.
  { to: "Inventory", label: () => "Inventory" },
  // Not DM-gated: a player sees the same page, without the Give controls on
  // each panel. Temporarily hidden while we look at the app without The Party.
  // { to: "Party", label: () => "The Party" },
  { to: "Shop", label: () => "Shop" },
  { to: "CreateItem", label: () => "New Item", dmOnly: true },
  { to: "Maps", label: () => "Maps", tab: true },
  { to: "Spells", label: () => "Spells" },
  // Beside Spells, because they are the same kind of page: a reference
  // catalogue you browse and then take something from onto your sheet.
  // CreateFeat is deliberately not here — the nav is for destinations, and the
  // Feats page carries its own forge link.
  { to: "Feats", label: () => "Feats" },
  { to: "NPC", label: () => "NPCs", tab: true },
  // Madam Eva's reading (065). Not a tab: it is consulted between sessions,
  // not mid-fight.
  { to: "Fortunes", label: () => "Fortunes", hiddenUntilRead: true },
  { to: "Recaps", label: () => "Recaps", tab: true },
  { to: "Invites", label: () => "Invites", dmOnly: true, footer: true },
  { to: "/", label: () => "Campaigns", footer: true },
];

/**
 * fortunesRead is "is any fortune revealed". The link appears for players
 * once the DM reveals the reading (on their next refetch). Hiding it is
 * cosmetic, not the boundary: until then RLS returns a player no rows, so the
 * page behind the link is empty for them anyway.
 */
export function visibleNavItems(
  isDm: boolean,
  fortunesRead: boolean,
): NavItem[] {
  return NAV_ITEMS.filter(
    (item) =>
      isDm || (!item.dmOnly && (!item.hiddenUntilRead || fortunesRead)),
  );
}

/** Styled as a DM link: DM-only for good, or only for now. */
export function isDmStyled(item: NavItem, fortunesRead: boolean): boolean {
  return !!item.dmOnly || (!!item.hiddenUntilRead && !fortunesRead);
}

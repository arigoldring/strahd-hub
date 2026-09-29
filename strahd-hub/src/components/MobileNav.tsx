import { useEffect, useRef, useState, type ReactNode } from "react";
import { NavLink, useLocation } from "react-router-dom";
import type { Campaign } from "../services/campaigns";
import type { NavItem } from "./navItems";
import { AccountControls, PreviewToggle } from "./RailControls";
import "./mobileNav.css";

/**
 * The phone's version of the rail: four tabs along the bottom edge, where a
 * thumb already is, and a More sheet holding everything else the rail carries
 * — the remaining links, the preview toggle, the name editor and Sign out.
 *
 * Rendered on every width and hidden above the breakpoint by mobileNav.css,
 * the same way the rail is hidden below it. Nothing here is phone-only in
 * behaviour, only in visibility.
 */
export function MobileNav({
  campaign,
  items,
}: {
  campaign: Campaign;
  items: NavItem[];
}) {
  const [open, setOpen] = useState(false);
  const dialogRef = useRef<HTMLDialogElement>(null);
  const { pathname } = useLocation();

  const tabs = items.filter((item) => item.tab);
  const rest = items.filter((item) => !item.tab);

  // A native <dialog> opened with showModal() brings the focus trap, Escape to
  // close and an inert page behind it for free — three things a div would have
  // to reimplement. The state is still React's; this effect only mirrors it.
  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);

  // Any navigation closes the sheet, including Back — which a close-on-click
  // on each link alone would miss.
  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  // More is "active" when the page on screen is one of its links, so the bar
  // always shows where you are. Tabs resolve against the campaign base the
  // same way their relative `to` does.
  const base = `/campaign/${campaign.id}`;
  const onTab = tabs.some((tab) => {
    const path = tab.to === "." ? base : `${base}/${tab.to}`;
    return tab.end
      ? pathname === path
      : pathname === path || pathname.startsWith(`${path}/`);
  });

  return (
    <>
      <nav className="tabbar" aria-label="Main">
        {tabs.map((tab) => (
          <NavLink key={tab.to} to={tab.to} end={tab.end} className="tabbar__tab">
            {TAB_ICONS[tab.to]}
            <span>{tab.label(campaign.isDm)}</span>
          </NavLink>
        ))}
        <button
          type="button"
          className={`tabbar__tab${!onTab ? " active" : ""}`}
          aria-haspopup="dialog"
          aria-expanded={open}
          onClick={() => setOpen(true)}
        >
          {ICON_MORE}
          <span>More</span>
        </button>
      </nav>

      <dialog
        ref={dialogRef}
        className="sheet"
        aria-label="More"
        // Escape fires `close` without going through React; resync.
        onClose={() => setOpen(false)}
        // A click whose target is the dialog itself landed on the backdrop —
        // the sheet's content always sits inside .sheet__body.
        onClick={(e) => {
          if (e.target === e.currentTarget) setOpen(false);
        }}
      >
        <div className="sheet__body">
          <div className="sheet__grip" aria-hidden="true" />
          <div className="sheet__head">
            <div>
              <p className="app-rail__eyebrow">Campaign</p>
              <p className="sheet__campaign">{campaign.name}</p>
            </div>
            <span
              className={`app-rail__role${campaign.isDm ? " app-rail__role--dm" : ""}`}
            >
              {campaign.isDm ? "Dungeon Master" : "Player"}
            </span>
          </div>

          <div className="sheet__links">
            {rest.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={item.dmOnly ? "app-nav__dm" : undefined}
                // Same-page taps don't change pathname, so the effect above
                // would leave the sheet open over the page you asked for.
                onClick={() => setOpen(false)}
              >
                {item.label(campaign.isDm)}
              </NavLink>
            ))}
          </div>

          {campaign.isDm && (
            <div className="sheet__preview">
              <PreviewToggle />
            </div>
          )}
          <AccountControls />
        </div>
      </dialog>
    </>
  );
}

// Line icons at 24px, stroke only, so they take the tab's text colour and
// light up with it.
function Icon({ children }: { children: ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width="24"
      height="24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

const TAB_ICONS: Record<string, ReactNode> = {
  // a keep: the campaign's front door
  ".": (
    <Icon>
      <path d="M4 21V9l2-1V5h2v2l4-2 4 2V5h2v3l2 1v12z" />
      <path d="M10 21v-5a2 2 0 0 1 4 0v5" />
    </Icon>
  ),
  Maps: (
    <Icon>
      <path d="M9 4 3 6v14l6-2 6 2 6-2V4l-6 2z" />
      <path d="M9 4v14M15 6v14" />
    </Icon>
  ),
  NPC: (
    <Icon>
      <circle cx="12" cy="8" r="3.5" />
      <path d="M5 20c.8-3.8 3.6-6 7-6s6.2 2.2 7 6" />
    </Icon>
  ),
  Recaps: (
    <Icon>
      <path d="M6 4h11a2 2 0 0 1 2 2v14H8a2 2 0 0 1-2-2z" />
      <path d="M6 18a2 2 0 0 1 2-2h11M10 8h5M10 11h5" />
    </Icon>
  ),
};

const ICON_MORE = (
  <Icon>
    <circle cx="5" cy="12" r="1.2" />
    <circle cx="12" cy="12" r="1.2" />
    <circle cx="19" cy="12" r="1.2" />
  </Icon>
);

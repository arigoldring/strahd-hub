import { Outlet, NavLink } from "react-router-dom";
import { useCampaign } from "./CampaignLayout";
import { AccountControls, PreviewToggle } from "./RailControls";
import { MobileNav } from "./MobileNav";
import { visibleNavItems, isDmStyled, type NavItem } from "./navItems";
import { useFortunes } from "../hooks/useFortunes";
import { useCampaignRealtime } from "../hooks/useCampaignRealtime";
import type { RealtimeStatus } from "../services/realtime";
import "./layout.css";

export function Layout() {
  // Read back off the outlet only to hand it down again. A bare <Outlet /> is
  // not a pass-through: it provides context={undefined}, which would blank out
  // the campaign CampaignLayout set. Every layout between the provider and the
  // page has to re-provide it.
  const campaign = useCampaign();
  // Any row back means the reading is revealed to this viewer (or they are the
  // DM). Loading and error both read as "not yet" -- the link is a door, and
  // the cost of it appearing a moment late is nothing.
  const { data: fortunes = [] } = useFortunes(campaign.id);
  const fortunesRead = fortunes.some((f) => f.isRevealed);
  // Live updates for every page below. Here rather than in CampaignLayout
  // because this is where the indicator renders, and it covers the same
  // routes: Layout is CampaignLayout's only child.
  const liveStatus = useCampaignRealtime(campaign.id);
  const items = visibleNavItems(campaign.isDm, fortunesRead);
  const navClass = (item: NavItem) =>
    isDmStyled(item, fortunesRead) ? "app-nav__dm" : undefined;

  return (
    <div className="app-shell">
      {/* Both navs are always rendered and layout.css picks one by width. A JS
          media query would render only one, but would also flash the wrong
          nav on first paint and re-mount on every rotation of an iPad. */}
      <nav className="app-rail">
        <div className="app-rail__campaign">
          <p className="app-rail__eyebrow">Campaign</p>
          <p className="app-rail__name">{campaign.name}</p>
          <span
            className={`app-rail__role${campaign.isDm ? " app-rail__role--dm" : ""}`}
          >
            {campaign.isDm ? "Dungeon Master" : "Player"}
          </span>
          {/* The rail itself is not part of what preview hides — the badge
              above and the DM links below stay exactly as they are. */}
          <LiveStatus status={liveStatus} />
          {campaign.isDm && <PreviewToggle />}
        </div>

        <div className="app-nav">
          {items
            .filter((item) => !item.footer)
            .map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={navClass(item)}
              >
                {item.label(campaign.isDm)}
              </NavLink>
            ))}
          <div className="app-nav__rule" />
          {items
            .filter((item) => item.footer)
            .map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                className={navClass(item)}
              >
                {item.label(campaign.isDm)}
              </NavLink>
            ))}
        </div>

        <AccountControls />
      </nav>

      <main className="app-main">
        <Outlet context={campaign} />
      </main>

      {/* Every width: the rail is hidden on a phone, and a phone is what
          drops the socket most (locked screen, backgrounded tab). Shown only
          when it matters, so the page isn't carrying a badge for the normal
          case. */}
      {liveStatus === "reconnecting" && (
        <p className="app-live-lost" role="status">
          Reconnecting… changes from others may be missing
        </p>
      )}

      <MobileNav campaign={campaign} items={items} navClass={navClass} />
    </div>
  );
}

const LIVE_LABELS: Record<RealtimeStatus, string> = {
  connecting: "Connecting",
  live: "Live",
  reconnecting: "Reconnecting",
};

/**
 * The rail's connection dot. "Live" means other people's changes reach this
 * page as they happen; anything else means they arrive only on a refocus or a
 * refetch, as they did before realtime.
 */
function LiveStatus({ status }: { status: RealtimeStatus }) {
  return (
    <p className={`app-rail__live app-rail__live--${status}`} role="status">
      <span className="app-rail__live-dot" aria-hidden="true" />
      {LIVE_LABELS[status]}
    </p>
  );
}

import { Outlet, NavLink } from "react-router-dom";
import { useCampaign } from "./CampaignLayout";
import { AccountControls, PreviewToggle } from "./RailControls";
import { MobileNav } from "./MobileNav";
import { visibleNavItems, isDmStyled, type NavItem } from "./navItems";
import { useFortunes } from "../hooks/useFortunes";
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

      <MobileNav campaign={campaign} items={items} navClass={navClass} />
    </div>
  );
}

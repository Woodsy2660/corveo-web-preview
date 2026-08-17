import { NavLink } from "react-router";
import { APP } from "@/copy/app";

const TABS = [
  { to: "/app/record", label: APP.tabs.record },
  { to: "/app/program", label: APP.tabs.program },
];

/**
 * Floating tab bar, fixed above the home indicator.
 *
 * The container radius is concentric with the device screen (--radius-xl),
 * not a full pill: at today's label-only height the two render identically,
 * but once the bar grows to take icons a pill would read as a stadium and
 * stop agreeing with the screen corners. The active chip stays fully round.
 */
export function TabBar() {
  return (
    <nav
      className="fixed inset-x-0 z-10 flex justify-center"
      style={{ bottom: "calc(var(--spacing-sm) + var(--safe-bottom))" }}
    >
      <div className="flex rounded-xl bg-action p-[var(--spacing-3xs)] shadow-lg">
        {TABS.map((tab) => (
          <NavLink
            key={tab.to}
            to={tab.to}
            className={({ isActive }) =>
              `rounded-round px-[var(--spacing-sm)] py-[var(--spacing-2xs)] transition-colors ${
                isActive ? "bg-card text-heading" : "text-action-ink"
              }`
            }
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {tab.label}
          </NavLink>
        ))}
      </div>
    </nav>
  );
}

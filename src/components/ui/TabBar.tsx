import { NavLink } from "react-router";
import { APP } from "@/copy/app";

const TABS = [
  { to: "/app/readings", label: APP.tabs.readings },
  { to: "/app/trend", label: APP.tabs.trend },
  { to: "/app/program", label: APP.tabs.program },
];

/** Floating pill tab bar, fixed above the home indicator. */
export function TabBar() {
  return (
    <nav
      className="fixed inset-x-0 z-10 flex justify-center"
      style={{ bottom: "calc(var(--spacing-sm) + var(--safe-bottom))" }}
    >
      <div className="flex rounded-round bg-action p-[var(--spacing-3xs)] shadow-lg">
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

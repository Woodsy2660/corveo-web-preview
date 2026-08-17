import { NavLink } from "react-router";
import { APP } from "@/copy/app";
import { EducationIcon, HeartIcon, ProgramIcon } from "@/components/ui/icons";

const TABS = [
  { to: "/app/program", label: APP.tabs.program, Icon: ProgramIcon },
  { to: "/app/record", label: APP.tabs.record, Icon: HeartIcon },
  { to: "/app/education", label: APP.tabs.education, Icon: EducationIcon },
];

/**
 * Floating tab bar, fixed above the home indicator.
 *
 * Icon-only: the record sits in the middle as the home of the app, with the
 * program to its left and the education library to its right. Labels are on
 * the accessible name rather than on screen — three glyphs this distinct
 * carry it, and the bar stays quiet against the content.
 *
 * The container radius is concentric with the device screen (--radius-xl)
 * rather than a full pill, so it keeps agreeing with the frame at this
 * taller icon height. The active chip stays fully round.
 */
export function TabBar() {
  return (
    <nav
      className="fixed inset-x-0 z-10 flex justify-center"
      style={{ bottom: "calc(var(--spacing-sm) + var(--safe-bottom))" }}
      aria-label={APP.tabs.navAria}
    >
      <div className="flex gap-[var(--spacing-3xs)] rounded-xl bg-action p-[var(--spacing-3xs)] shadow-lg">
        {TABS.map(({ to, label, Icon }) => (
          <NavLink
            key={to}
            to={to}
            aria-label={label}
            title={label}
            className={({ isActive }) =>
              `flex items-center justify-center rounded-round px-[var(--spacing-md)] py-[var(--spacing-xs)] ${
                isActive ? "bg-card text-heading" : "text-action-ink"
              }`
            }
            style={{
              fontSize: "var(--text-body-base)",
              transitionProperty: "background-color, color",
              transitionDuration: "var(--duration-fast)",
              transitionTimingFunction: "var(--ease-brand)",
            }}
          >
            <Icon />
          </NavLink>
        ))}
      </div>
    </nav>
  );
}

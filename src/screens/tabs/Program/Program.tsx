import { Link } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { APP } from "@/copy/app";
import { useProgramProgress } from "@/lib/api/hooks";

import { PROGRAM_PLACEHOLDER_WEEKS } from "@/copy/program-placeholder";

/**
 * Program tab (Deliverable 7) — the six-week education container.
 *
 * Content is authored, clinically reviewed, and supplied by Corveo (client
 * dependency 5) and is static: it never varies based on the user's
 * readings. Placeholder copy lives in src/copy/program-placeholder.ts and is
 * replaced verbatim by the signed-off content when it arrives.
 */
export function Program() {
  const { data: progress } = useProgramProgress();
  const currentWeek = progress?.current_week ?? 1;
  const c = APP.program;

  return (
    <Screen
      eyebrow={c.eyebrow}
      title={c.title}
      withTabBar
      action={
        <Link to="/app/settings" className="eyebrow underline underline-offset-4">
          {APP.common.settingsLink}
        </Link>
      }
    >
      <Card className="mb-[var(--spacing-sm)]">
        <p className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
          {c.contentPendingNotice}
        </p>
      </Card>

      <div className="flex flex-col gap-[var(--spacing-xs)]">
        {PROGRAM_PLACEHOLDER_WEEKS.map(({ week, title, blurb }) => {
          const open = week <= currentWeek;
          return (
            <Card key={week} label={c.weekLabel(week)} className={open ? "" : "opacity-60"}>
              <h2 className="pb-[var(--spacing-3xs)]" style={{ fontSize: "var(--text-heading-xl)" }}>
                {title}
              </h2>
              <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
                {open ? blurb : c.lockedNote}
              </p>
            </Card>
          );
        })}
      </div>
    </Screen>
  );
}

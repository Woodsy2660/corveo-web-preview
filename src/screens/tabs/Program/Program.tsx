import { Link } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Chip } from "@/components/ui/Chip";
import { APP } from "@/copy/app";
import { useProgramProgress } from "@/lib/api/hooks";
import {
  PROGRAM_CHAPTERS,
  PROGRAM_WEEK_COUNT,
  isAvailable,
  isRead,
  readCount,
} from "@/lib/program";

/**
 * Program tab (Deliverable 7) — the six-week education container.
 *
 * Content is authored, clinically reviewed, and supplied by Corveo (client
 * dependency 5) and is static: it never varies based on the user's readings.
 * Chapters unlock on the program's own weekly cadence, which is a calendar
 * rhythm and not a response to anything recorded.
 *
 * The card shape mirrors Userkind's Programs collection (title, excerpt,
 * estimated time) so the container survives the real content arriving.
 */
export function Program() {
  const { data: progress } = useProgramProgress();
  const c = APP.program;
  const read = readCount(progress);

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
      <p
        className="pb-[var(--spacing-sm)] text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {c.progress(read, PROGRAM_WEEK_COUNT)}
      </p>

      <Card className="mb-[var(--spacing-sm)]">
        <p className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
          {c.contentPendingNotice}
        </p>
      </Card>

      <ul className="flex list-none flex-col gap-[var(--spacing-xs)] p-0">
        {PROGRAM_CHAPTERS.map((chapter) => {
          const open = isAvailable(progress, chapter.week);
          const done = isRead(progress, chapter.week);

          const inner = (
            <Card label={c.weekLabel(chapter.week)} className={open ? "" : "opacity-60"}>
              <h2
                className="pb-[var(--spacing-3xs)]"
                style={{ fontSize: "var(--text-heading-xl)" }}
              >
                {chapter.title}
              </h2>
              <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
                {open ? chapter.excerpt : c.lockedNote}
              </p>
              {open ? (
                <div className="flex items-center gap-[var(--spacing-2xs)] pt-[var(--spacing-2xs)]">
                  <span
                    className="text-ink-tertiary"
                    style={{ fontSize: "var(--text-body-sm)" }}
                  >
                    {c.readTime(chapter.readMinutes)}
                  </span>
                  {done ? <Chip>{c.readLabel}</Chip> : null}
                </div>
              ) : null}
            </Card>
          );

          return (
            <li key={chapter.week}>
              {open ? (
                <Link
                  to={`/app/program/${chapter.week}`}
                  aria-label={c.openChapterAria(chapter.week, chapter.title)}
                  className="block"
                >
                  {inner}
                </Link>
              ) : (
                inner
              )}
            </li>
          );
        })}
      </ul>
    </Screen>
  );
}

import { Link } from "react-router";
import { Screen, ProfileLink } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { APP } from "@/copy/app";
import { useProgramProgress } from "@/lib/api/hooks";
import { findProgram, readCount } from "@/lib/programs";
import { useFollowedPrograms } from "@/lib/useFollowedPrograms";
import { ChapterList } from "@/screens/tabs/Program/ChapterRow";
import { ProgramIndex } from "@/screens/tabs/Program/ProgramIndex";

/**
 * Program tab (Deliverable 7).
 *
 * Opens on the program you are following. Follow more than one and a
 * switcher appears; follow none and the tab becomes the library instead of
 * an empty screen.
 *
 * Content is authored and clinically reviewed by Corveo (client dependency
 * 5) and is static: it never varies with the reader's readings. The core
 * program releases a chapter a week — a calendar rhythm, not a response to
 * anything recorded.
 */
export function Program() {
  const { data: progress } = useProgramProgress();
  const { following, active, setActive } = useFollowedPrograms();
  const c = APP.program;
  const program = findProgram(active);

  if (!program || following.length === 0) {
    return (
      <Screen title={APP.programIndex.title} withTabBar action={<ProfileLink />}>
        <ProgramIndex embedded />
      </Screen>
    );
  }

  const read = readCount(progress, program);

  return (
    <Screen
      overline={APP.programIndex.chapterCount(program.chapters.length, program.unitLabel)}
      title={program.title}
      withTabBar
      action={<ProfileLink />}
    >
      <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-base)" }}>
        {program.description}
      </p>

      <div className="flex items-center justify-between pt-[var(--spacing-2xs)] pb-[var(--spacing-sm)]">
        <span className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
          {c.progress(read, program.chapters.length)}
        </span>
        <Link
          to="/app/program/browse"
          className="text-ink-secondary underline underline-offset-4"
          style={{ fontSize: "var(--text-body-sm)" }}
        >
          {c.browseAll}
        </Link>
      </div>

      {/* Switcher appears only once there is something to switch between. */}
      {following.length > 1 ? (
        <div
          /* Full-bleed: the rail runs to the screen edge so a part-visible
             chip reads as "more to swipe" rather than as a clipped button. */
          className="no-scrollbar -mx-[var(--spacing-md)] flex gap-[var(--spacing-2xs)] overflow-x-auto px-[var(--spacing-md)] pb-[var(--spacing-sm)]"
          role="radiogroup"
          aria-label={c.switchAria}
        >
          {following.map((slug) => {
            const p = findProgram(slug);
            if (!p) return null;
            const on = slug === active;
            return (
              <button
                key={slug}
                role="radio"
                aria-checked={on}
                onClick={() => setActive(slug)}
                className={`min-h-[44px] flex-none rounded-round px-[var(--spacing-sm)] ${
                  on
                    ? "bg-action text-action-ink"
                    : "border border-hairline bg-card text-ink-secondary"
                }`}
                style={{ fontSize: "var(--text-body-sm)", fontWeight: on ? 500 : 400 }}
              >
                {p.title}
              </button>
            );
          })}
        </div>
      ) : null}

      <Card>
        <p className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
          {c.contentPendingNotice}
        </p>
      </Card>

      <ChapterList program={program} progress={progress} />
    </Screen>
  );
}

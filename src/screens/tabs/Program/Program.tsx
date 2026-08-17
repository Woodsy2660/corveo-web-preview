import { Link } from "react-router";
import { Screen, ProfileLink } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Chip } from "@/components/ui/Chip";
import { ArrowRightIcon, CheckIcon, ClockIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import { PROGRAM, type ProgramChapter } from "@/copy/program-placeholder";
import { useProgramProgress } from "@/lib/api/hooks";
import {
  PROGRAM_CHAPTERS,
  PROGRAM_WEEK_COUNT,
  isAvailable,
  isRead,
  readCount,
} from "@/lib/program";

/**
 * Program tab (Deliverable 7) — the six-week education container, laid out
 * on the same chapter-row pattern as corveo.vercel.app/programs: thumbnail,
 * chapter tag, duration with a clock, title, excerpt, and a trailing-arrow
 * CTA. Adapted for 390px — the row itself is the tap target, and the pill is
 * the visual affordance inside it rather than a second control.
 *
 * Chapter artwork is a Corveo asset that hasn't been supplied. Until it is,
 * each row shows a neutral tile carrying the week number rather than a
 * broken image or an empty box.
 *
 * Content is authored and clinically reviewed by Corveo (client dependency
 * 5) and is static: it never varies with the reader's readings. Chapters
 * unlock on the program's own weekly cadence, a calendar rhythm and not a
 * response to anything recorded.
 */
function ChapterRow({
  chapter,
  open,
  done,
}: {
  chapter: ProgramChapter;
  open: boolean;
  done: boolean;
}) {
  const c = APP.program;
  const medium = chapter.medium ?? "read";

  const body = (
    <div className="flex gap-[var(--spacing-xs)] py-[var(--spacing-sm)]">
      {/* Placeholder for Userkind's `cardImage`. */}
      <div
        aria-hidden
        className="flex size-[72px] flex-none items-center justify-center rounded-sm"
        style={{
          background: "var(--color-surface-neutral-lighter)",
          color: "var(--color-text-heading-inverse)",
          fontFamily: "var(--font-display)",
          fontSize: "var(--text-heading-xl)",
          opacity: open ? 1 : 0.5,
        }}
      >
        {chapter.week}
      </div>

      <div className={`flex min-w-0 flex-1 flex-col gap-[var(--spacing-2xs)] ${open ? "" : "opacity-60"}`}>
        <div className="flex flex-wrap items-center gap-[var(--spacing-2xs)]">
          <Chip>{c.weekLabel(chapter.week)}</Chip>
          {open ? (
            <span
              className="flex items-center gap-[var(--spacing-3xs)] text-ink-tertiary"
              style={{ fontSize: "var(--text-body-sm)" }}
            >
              <ClockIcon />
              {c.duration(chapter.readMinutes, medium)}
            </span>
          ) : null}
          {done ? (
            <span
              className="flex items-center gap-[var(--spacing-3xs)] text-ink-tertiary"
              style={{ fontSize: "var(--text-body-sm)" }}
            >
              <CheckIcon />
              {c.readLabel}
            </span>
          ) : null}
        </div>

        <h2 style={{ fontSize: "var(--text-heading-xl)" }}>{chapter.title}</h2>

        <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
          {open ? chapter.excerpt : c.lockedNote}
        </p>

        {open ? (
          <span
            className="mt-[var(--spacing-3xs)] inline-flex w-fit items-center gap-[var(--spacing-2xs)] rounded-round border border-hairline px-[var(--spacing-sm)] py-[var(--spacing-2xs)] text-heading"
            style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}
          >
            {c.cta[medium]}
            <ArrowRightIcon />
          </span>
        ) : null}
      </div>
    </div>
  );

  return open ? (
    <Link
      to={`/app/program/${chapter.week}`}
      aria-label={c.openChapterAria(chapter.week, chapter.title)}
      className="block"
    >
      {body}
    </Link>
  ) : (
    body
  );
}

export function Program() {
  const { data: progress } = useProgramProgress();
  const c = APP.program;
  const read = readCount(progress);

  return (
    <Screen
      overline={c.chapterCount(PROGRAM_WEEK_COUNT)}
      title={PROGRAM.title}
      withTabBar
      action={<ProfileLink />}
    >
      <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-base)" }}>
        {PROGRAM.description}
      </p>

      <p
        className="pt-[var(--spacing-2xs)] pb-[var(--spacing-sm)] text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {c.progress(read, PROGRAM_WEEK_COUNT)}
      </p>

      <Card>
        <p className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
          {c.contentPendingNotice}
        </p>
      </Card>

      <ul className="flex list-none flex-col p-0">
        {PROGRAM_CHAPTERS.map((chapter) => (
          <li
            key={chapter.week}
            className="border-b border-hairline last:border-b-0"
          >
            <ChapterRow
              chapter={chapter}
              open={isAvailable(progress, chapter.week)}
              done={isRead(progress, chapter.week)}
            />
          </li>
        ))}
      </ul>
    </Screen>
  );
}

import { Link } from "react-router";
import { CheckIcon, ClockIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import { CHAPTER_ART } from "@/assets/photos";
import type { ProgramChapter } from "@/copy/program-placeholder";
import type { ProgramProgressRow } from "@/lib/api/types";
import { isAvailable, isRead, type ProgramSummary } from "@/lib/programs";

/** The chapter list for one program, shared by the tab and the detail route. */
export function ChapterList({
  program,
  progress,
}: {
  program: ProgramSummary;
  progress: ProgramProgressRow | undefined;
}) {
  return (
    <ul className="flex list-none flex-col p-0">
      {program.chapters.map((chapter, i) => (
        <li key={chapter.week} className="card-enter border-b border-hairline last:border-b-0" style={{ "--stagger-index": Math.min(i, 4) } as React.CSSProperties}>
          <ChapterRow
            program={program}
            chapter={chapter}
            open={isAvailable(progress, program, chapter.week)}
            done={isRead(progress, program.slug, chapter.week)}
          />
        </li>
      ))}
    </ul>
  );
}

/**
 * One chapter row: thumbnail, title, excerpt, then week and duration.
 * Height follows the copy so excerpt and meta never sit on top of each other.
 * The whole row is the tap target.
 */
export function ChapterRow({
  program,
  chapter,
  open,
  done,
}: {
  program: ProgramSummary;
  chapter: ProgramChapter;
  open: boolean;
  done: boolean;
}) {
  const c = APP.program;
  const medium = chapter.medium ?? "read";

  const body = (
    <div className="flex gap-[var(--spacing-xs)] py-[var(--spacing-sm)]">
      <img
        src={CHAPTER_ART[chapter.week]}
        alt=""
        aria-hidden
        className="h-[96px] w-[66px] flex-none rounded-sm object-cover self-start"
      />

      <div className="flex min-w-0 flex-1 flex-col gap-[var(--spacing-3xs)]">
        <h2
          className="line-clamp-2"
          style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-heading)" }}
        >
          {chapter.title}
        </h2>
        <p
          className="line-clamp-2 text-ink-secondary"
          style={{ fontSize: "var(--text-body-sm)", lineHeight: "var(--leading-body)" }}
        >
          {open ? chapter.excerpt : c.lockedNote}
        </p>
        <div
          className="flex flex-wrap items-center gap-x-[var(--spacing-2xs)] gap-y-[var(--spacing-3xs)] text-ink-tertiary"
          style={{ fontSize: "var(--text-label)", lineHeight: "var(--leading-label)" }}
        >
          <span>{`${program.unitLabel} ${chapter.week}`}</span>
          {open ? (
            <span className="inline-flex items-center gap-[var(--spacing-3xs)]">
              <span aria-hidden>·</span>
              <ClockIcon />
              {c.duration(chapter.readMinutes, medium)}
            </span>
          ) : null}
          {done ? (
            <span className="inline-flex items-center gap-[var(--spacing-3xs)]">
              <span aria-hidden>·</span>
              <CheckIcon />
              {c.readLabel}
            </span>
          ) : null}
        </div>
      </div>
    </div>
  );

  return open ? (
    <Link
      to={`/app/program/${program.slug}/${chapter.week}`}
      aria-label={c.openChapterAria(chapter.week, chapter.title)}
      className="block"
    >
      {body}
    </Link>
  ) : (
    body
  );
}

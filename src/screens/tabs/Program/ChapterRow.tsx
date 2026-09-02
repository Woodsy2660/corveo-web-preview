import { Link } from "react-router";
import { CheckIcon, ClockIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import { CHAPTER_ART } from "@/assets/program";
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
      {program.chapters.map((chapter) => (
        <li key={chapter.week} className="border-b border-hairline last:border-b-0">
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
 * One chapter row, on the same pattern as corveo.vercel.app/programs:
 * thumbnail, title, excerpt, then the unit and duration as one quiet line.
 * Every row is the same height, so the list reads as a rhythm; the title
 * and excerpt clamp rather than push the row taller. The whole row is the
 * tap target — no CTA pill inside it.
 *
 * Chapter artwork is a Corveo asset that has not been supplied; the tile
 * shows a placeholder from src/assets/program until it is.
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
  const pending = !chapter.sections;

  const body = (
    <div className="flex h-[112px] gap-[var(--spacing-xs)] py-[var(--spacing-xs)]">
      <img
        src={CHAPTER_ART[chapter.week]}
        alt=""
        aria-hidden
        className="h-full w-[66px] flex-none rounded-sm object-cover"
      />

      {/* Locked chapters say so in words; they are not dimmed, so the list
          holds one weight top to bottom. */}
      <div className="flex min-w-0 flex-1 flex-col justify-between">
        <div className="min-w-0">
          <h2
            className="line-clamp-1"
            style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-heading)" }}
          >
            {chapter.title}
          </h2>
          <p
            className="line-clamp-2 text-ink-secondary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {open ? chapter.excerpt : c.lockedNote}
          </p>
        </div>

        <div
          className="flex items-center gap-[var(--spacing-2xs)] text-ink-tertiary"
          style={{ fontSize: "var(--text-label)", lineHeight: "var(--leading-label)" }}
        >
          <span>{`${program.unitLabel} ${chapter.week}`}</span>
          {open ? (
            <>
              <span aria-hidden>·</span>
              <span className="flex items-center gap-[var(--spacing-3xs)]">
                <ClockIcon />
                {c.duration(chapter.readMinutes, medium)}
              </span>
            </>
          ) : null}
          {done ? (
            <>
              <span aria-hidden>·</span>
              <span className="flex items-center gap-[var(--spacing-3xs)]">
                <CheckIcon />
                {c.readLabel}
              </span>
            </>
          ) : null}
          {open && pending ? (
            <>
              <span aria-hidden>·</span>
              <span style={{ fontWeight: 500 }}>{c.contentPending}</span>
            </>
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

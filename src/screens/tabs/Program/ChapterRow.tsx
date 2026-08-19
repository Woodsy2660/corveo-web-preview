import { Link } from "react-router";
import { Chip } from "@/components/ui/Chip";
import { CheckIcon, ClockIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
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
 * thumbnail, unit tag, duration with a clock, title, excerpt. The whole row
 * is the tap target — no CTA pill inside it.
 *
 * Chapter artwork is a Corveo asset that has not been supplied, so the tile
 * is a placeholder that spans the row's height and carries the chapter
 * number rather than a broken image.
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
    <div className="flex gap-[var(--spacing-xs)] py-[var(--spacing-sm)]">
      <div
        aria-hidden
        className="flex w-[96px] flex-none items-center justify-center self-stretch rounded-sm"
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

      <div
        className={`flex min-w-0 flex-1 flex-col gap-[var(--spacing-2xs)] ${
          open ? "" : "opacity-60"
        }`}
      >
        <div className="flex flex-wrap items-center gap-[var(--spacing-2xs)]">
          <Chip>{`${program.unitLabel} ${chapter.week}`}</Chip>
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

        {open && pending ? (
          <span
            className="mt-[var(--spacing-3xs)] text-ink-tertiary"
            style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}
          >
            {c.contentPending}
          </span>
        ) : null}
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

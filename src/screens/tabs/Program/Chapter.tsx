import { Link, useNavigate, useParams } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { Chip } from "@/components/ui/Chip";
import { APP } from "@/copy/app";
import { SAFETY } from "@/copy/safety";
import { useProgramProgress, useUpdateProgress } from "@/lib/api/hooks";
import { findChapter, findProgram, isAvailable, isRead, stepKey } from "@/lib/programs";

/**
 * Chapter reading view (Deliverable 7).
 *
 * Structure follows the shipped Corveo article template — content-type label,
 * serif title, standfirst, label/value meta pairs, sans section headings,
 * body, disclaimer, previous/next — so the app's long-form reading matches
 * the publication people already know.
 *
 * The chapter carries the education disclaimer at the point of reading, not
 * only in Settings.
 */
function MetaPair({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-[2px]">
      <span
        className="text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}
      >
        {label}
      </span>
      <span style={{ fontSize: "var(--text-body-base)" }}>{value}</span>
    </div>
  );
}

export function Chapter() {
  const { slug, week: weekParam } = useParams();
  const navigate = useNavigate();
  const { data: progress } = useProgramProgress();
  const updateProgress = useUpdateProgress();

  const c = APP.chapter;
  const week = Number(weekParam);
  const program = findProgram(slug);
  const chapter = program && Number.isInteger(week) ? findChapter(slug, week) : undefined;

  const backLink = (
    <Link
      to={program ? `/app/program/${program.slug}` : "/app/program"}
      className="eyebrow underline underline-offset-4"
    >
      {program ? program.title : c.back}
    </Link>
  );

  if (!program || !chapter || !isAvailable(progress, program, week)) {
    return (
      <Screen action={backLink} title={c.notFound}>
        <Button onClick={() => navigate("/app/program")}>{c.back}</Button>
      </Screen>
    );
  }

  const done = isRead(progress, program.slug, week);
  const previous = findChapter(program.slug, week - 1);
  const next = findChapter(program.slug, week + 1);
  const nextOpen = next ? isAvailable(progress, program, next.week) : false;

  return (
    <Screen
      overline={`${program.unitLabel} ${chapter.week}`}
      action={backLink}
      title={chapter.title}
      footer={
        done ? (
          <Button
            onClick={() =>
              navigate(nextOpen && next ? `/app/program/${program.slug}/${next.week}` : `/app/program/${program.slug}`)
            }
          >
            {nextOpen ? c.next : c.back}
          </Button>
        ) : (
          <Button
            disabled={updateProgress.isPending}
            onClick={() =>
              updateProgress.mutate({ completed_steps: { [stepKey(program.slug, week)]: true } })
            }
          >
            {updateProgress.isPending ? APP.common.busy : c.markRead}
          </Button>
        )
      }
    >
      <p
        className="pb-[var(--spacing-sm)] text-ink-secondary"
        style={{
          fontSize: "var(--text-body-lg)",
          lineHeight: "var(--leading-body-relaxed)",
        }}
      >
        {chapter.deck}
      </p>

      {done ? (
        <div className="pb-[var(--spacing-sm)]">
          <Chip>{c.markedRead}</Chip>
        </div>
      ) : null}

      <div className="flex flex-wrap gap-x-[var(--spacing-lg)] gap-y-[var(--spacing-xs)] border-y border-hairline py-[var(--spacing-sm)]">
        <MetaPair
          label={program.unitLabel}
          value={c.metaWeekValue(chapter.week, program.chapters.length)}
        />
        <MetaPair
          label={c.metaReadTime}
          value={c.metaReadTimeValue(chapter.readMinutes)}
        />
        <MetaPair label={c.metaReview} value={chapter.reviewStatus} />
      </div>

      <article className="flex flex-col gap-[var(--spacing-md)] pt-[var(--spacing-md)]">
        {(chapter.sections ?? []).map((section) => (
          <section key={section.heading} className="flex flex-col gap-[var(--spacing-2xs)]">
            <h2 style={{ fontSize: "var(--text-heading-xl)" }}>{section.heading}</h2>
            {section.body.map((paragraph) => (
              <p
                key={paragraph.slice(0, 32)}
                style={{
                  fontSize: "var(--text-body-lg)",
                  lineHeight: "var(--leading-body-relaxed)",
                }}
              >
                {paragraph}
              </p>
            ))}
          </section>
        ))}
      </article>

      <p
        className="mt-[var(--spacing-md)] border-t border-hairline pt-[var(--spacing-sm)] text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {SAFETY.educationNote}
      </p>

      <nav className="flex justify-between gap-[var(--spacing-sm)] pt-[var(--spacing-md)]">
        {previous ? (
          <Link
            to={`/app/program/${program.slug}/${previous.week}`}
            className="text-ink-secondary underline underline-offset-4"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {c.previous}
          </Link>
        ) : (
          <span />
        )}
        {next && nextOpen ? (
          <Link
            to={`/app/program/${program.slug}/${next.week}`}
            className="text-ink-secondary underline underline-offset-4"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {c.next}
          </Link>
        ) : (
          <span />
        )}
      </nav>
    </Screen>
  );
}

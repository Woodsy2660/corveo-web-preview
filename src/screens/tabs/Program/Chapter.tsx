import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { APP } from "@/copy/app";
import { SAFETY } from "@/copy/safety";
import { findEditorial } from "@/lib/education-content";
import { useProgramProgress, useUpdateProgress } from "@/lib/api/hooks";
import { findChapter, findProgram, isAvailable, isRead, stepKey } from "@/lib/programs";
import type { ProgramSection } from "@/copy/program-placeholder";

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

function ArticleBody({ sections }: { sections: readonly ProgramSection[] }) {
  return (
    <article className="flex flex-col gap-[var(--spacing-md)] pt-[var(--spacing-md)]">
      {sections.map((section) => (
        <section key={section.heading} className="flex flex-col gap-[var(--spacing-2xs)]">
          <h2 style={{ fontSize: "var(--text-heading-xl)" }}>{section.heading}</h2>
          {(section.blocks ?? []).map((block, i) =>
            block.type === "list" ? (
              <ul
                key={`${section.heading}-list-${i}`}
                className="list-disc pl-[var(--spacing-sm)]"
                style={{
                  fontSize: "var(--text-body-lg)",
                  lineHeight: "var(--leading-body-relaxed)",
                }}
              >
                {block.items.map((item) => (
                  <li key={item.slice(0, 40)}>{item}</li>
                ))}
              </ul>
            ) : (
              <p
                key={block.text.slice(0, 40)}
                style={{
                  fontSize: "var(--text-body-lg)",
                  lineHeight: "var(--leading-body-relaxed)",
                }}
              >
                {block.text}
              </p>
            ),
          )}
          {(section.body ?? []).map((paragraph) => (
            <p
              key={paragraph.slice(0, 40)}
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
  );
}

/**
 * Chapter reading view. Body copy is the Lovable-Andrew education package,
 * rendered as supplied — headings, paragraphs, lists, takeaway and holds.
 */
export function Chapter() {
  const { slug, week: weekParam } = useParams();
  const navigate = useNavigate();
  const { data: progress } = useProgramProgress();
  const updateProgress = useUpdateProgress();
  const [fade, setFade] = useState(0);
  const endRef = useRef<HTMLDivElement>(null);
  const markedRef = useRef(false);

  const c = APP.chapter;
  const week = Number(weekParam);
  const program = findProgram(slug);
  const chapter = program && Number.isInteger(week) ? findChapter(slug, week) : undefined;
  const done = program && Number.isInteger(week) ? isRead(progress, program.slug, week) : false;

  const markComplete = useCallback(() => {
    if (!program || !chapter || done || markedRef.current || updateProgress.isPending) return;
    markedRef.current = true;
    const unlocked = Math.min(week + 1, program.chapters.length);
    updateProgress.mutate(
      {
        completed_steps: { [stepKey(program.slug, week)]: true },
        current_week: Math.max(progress?.current_week ?? 1, unlocked),
      },
      { onError: () => { markedRef.current = false; } },
    );
  }, [program, chapter, done, week, progress, updateProgress]);

  useEffect(() => {
    markedRef.current = false;
    setFade(0);
  }, [week]);

  useEffect(() => {
    if (!endRef.current) return;
    const root = endRef.current.closest("main");
    if (!(root instanceof HTMLElement)) return;

    const onScroll = () => {
      const max = root.scrollHeight - root.clientHeight;
      if (max <= 0) {
        setFade(1);
        return;
      }
      const progress = root.scrollTop / max;
      setFade(Math.min(1, Math.max(0, (progress - 0.75) / 0.25)));
    };
    onScroll();
    root.addEventListener("scroll", onScroll, { passive: true });

    const complete = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) markComplete();
      },
      { root, threshold: 0.5, rootMargin: "0px 0px -12% 0px" },
    );
    if (!done) complete.observe(endRef.current);

    return () => {
      root.removeEventListener("scroll", onScroll);
      complete.disconnect();
    };
  }, [done, week, markComplete]);

  if (!program || !chapter || !isAvailable(progress, program, week)) {
    return (
      <Screen title={c.notFound} withTabBar>
        <Button onClick={() => navigate("/app/program")}>{c.back}</Button>
      </Screen>
    );
  }

  const next = findChapter(program.slug, week + 1);
  const nextOpen = next ? isAvailable(progress, program, next.week) : false;

  const actions = (
    <div className="flex flex-col gap-[var(--spacing-2xs)]">
      {done ? (
        nextOpen && next ? (
          <Button onClick={() => navigate(`/app/program/${program.slug}/${next.week}`)}>
            {c.next}
          </Button>
        ) : (
          <Button onClick={() => navigate("/app/program")}>{c.back}</Button>
        )
      ) : (
        <Button disabled={updateProgress.isPending} onClick={markComplete}>
          {updateProgress.isPending ? APP.common.busy : c.markRead}
        </Button>
      )}
      {!done || (nextOpen && next) ? (
        <Button variant="ghost" onClick={() => navigate("/app/program")}>
          {APP.common.back}
        </Button>
      ) : null}
    </div>
  );

  return (
    <>
    <Screen
      overline={`${program.unitLabel} ${chapter.week}`}
      title={chapter.title}
      className="step-enter"
      withTabBar
      scrollKey={`${program.slug}:${chapter.week}`}
    >
      {chapter.deck ? (
        <p
          className="pb-[var(--spacing-sm)] text-ink-secondary"
          style={{
            fontSize: "var(--text-body-lg)",
            lineHeight: "var(--leading-body-relaxed)",
          }}
        >
          {chapter.deck}
        </p>
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
      </div>

      {chapter.byline ? (
        <p className="pt-[var(--spacing-sm)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
          {chapter.byline}
        </p>
      ) : null}

      <ArticleBody sections={chapter.sections ?? []} />

      {chapter.keyTakeaway ? (
        <div className="mt-[var(--spacing-md)] border-t border-hairline pt-[var(--spacing-sm)]">
          <p className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}>
            {c.keyTakeaway}
          </p>
          <p
            className="pt-[var(--spacing-2xs)]"
            style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-body-relaxed)" }}
          >
            {chapter.keyTakeaway}
          </p>
        </div>
      ) : null}

      {chapter.crossLinks && chapter.crossLinks.length > 0 ? (
        <nav className="mt-[var(--spacing-md)] border-t border-hairline pt-[var(--spacing-sm)]" aria-label={c.related}>
          <p className="pb-[var(--spacing-2xs)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}>
            {c.related}
          </p>
          <ul className="m-0 flex list-none flex-col p-0">
            {chapter.crossLinks.map((link) => {
              const entry = findEditorial(link.prototypeTargetKey);
              const to =
                link.collection === "in-focus"
                  ? `/app/education/in-focus/${link.prototypeTargetKey}`
                  : `/app/education/pulse/${link.prototypeTargetKey}`;
              return (
                <li key={link.prototypeTargetKey} className="border-b border-hairline last:border-b-0">
                  <Link
                    to={to}
                    className="block py-[var(--spacing-2xs)] text-heading underline underline-offset-4"
                    style={{ fontSize: "var(--text-body-sm)" }}
                  >
                    {entry?.title ?? link.title}
                  </Link>
                </li>
              );
            })}
          </ul>
        </nav>
      ) : null}

      {chapter.nextWeekTitle ? (
        <div className="mt-[var(--spacing-md)] border-t border-hairline pt-[var(--spacing-sm)]">
          <p className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}>
            {c.nextWeek}
          </p>
          <p className="pt-[var(--spacing-2xs)]" style={{ fontSize: "var(--text-body-base)" }}>
            {chapter.nextWeekTitle}
          </p>
        </div>
      ) : null}

      <p
        className="mt-[var(--spacing-md)] border-t border-hairline pt-[var(--spacing-sm)] text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {SAFETY.educationNote}
      </p>
      <div ref={endRef} aria-hidden />
      <div aria-hidden className="h-[7.5rem]" />
    </Screen>
    {fade > 0 ? (
      <div
        className="fixed inset-x-0 bottom-0 z-[15] bg-page px-[var(--spacing-md)] pt-[var(--spacing-xs)]"
        style={{
          paddingBottom: "calc(96px + var(--safe-bottom))",
          opacity: fade,
          pointerEvents: fade > 0.2 ? "auto" : "none",
          transition: "opacity var(--duration-slow) var(--ease-brand)",
        }}
      >
        {actions}
      </div>
    ) : null}
    </>
  );
}

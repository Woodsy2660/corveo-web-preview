import { Link } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { APP } from "@/copy/app";
import { CORE_PROGRAM_SLUG, PROGRAMS } from "@/lib/programs";
import { useFollowedPrograms } from "@/lib/useFollowedPrograms";

/** The library as its own screen, reached from the Program tab. */
export function ProgramBrowse() {
  return (
    <Screen
      title={APP.programIndex.title}
      action={
        <Link to="/app/program" className="eyebrow underline underline-offset-4">
          {APP.chapter.back}
        </Link>
      }
    >
      <ProgramIndex />
    </Screen>
  );
}

/**
 * The programs library — every program, with follow state.
 *
 * SCOPE: only the core six-week program is inside Deliverable 7. The rest
 * are the website's programs and shipping them is a Change Request; this
 * screen exists so the browse-and-follow IA can be judged.
 */
export function ProgramIndex({ embedded = false }: { embedded?: boolean }) {
  const c = APP.programIndex;
  const { isFollowing, follow, unfollow } = useFollowedPrograms();

  return (
    <>
      <p
        className="pb-[var(--spacing-md)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {embedded ? c.emptyIntro : c.intro}
      </p>

      <ul className="flex list-none flex-col gap-[var(--spacing-sm)] p-0">
        {PROGRAMS.map((program) => {
          const following = isFollowing(program.slug);
          const core = program.slug === CORE_PROGRAM_SLUG;

          return (
            <li key={program.slug}>
              <Card>
                <Link to={`/app/program/${program.slug}`} className="block">
                  <p className="eyebrow pb-[var(--spacing-3xs)]">
                    {c.chapterCount(program.chapters.length, program.unitLabel)}
                  </p>
                  <h2
                    className="pb-[var(--spacing-3xs)]"
                    style={{ fontSize: "var(--text-heading-xl)" }}
                  >
                    {program.title}
                  </h2>
                  <p
                    className="text-ink-secondary"
                    style={{ fontSize: "var(--text-body-sm)" }}
                  >
                    {program.description}
                  </p>
                </Link>

                <div className="pt-[var(--spacing-sm)]">
                  {core ? (
                    <span
                      className="inline-flex items-center rounded-round border border-hairline px-[var(--spacing-sm)] py-[var(--spacing-2xs)] text-ink-tertiary"
                      style={{ fontSize: "var(--text-body-sm)" }}
                    >
                      {c.coreLabel}
                    </span>
                  ) : (
                    <button
                      onClick={() =>
                        following ? unfollow(program.slug) : follow(program.slug)
                      }
                      aria-pressed={following}
                      className={`inline-flex min-h-[44px] items-center rounded-round px-[var(--spacing-md)] ${
                        following
                          ? "border border-hairline bg-transparent text-heading"
                          : "bg-action text-action-ink"
                      }`}
                      style={{
                        fontSize: "var(--text-body-sm)",
                        fontWeight: 500,
                        transitionProperty: "background-color, color, border-color",
                        transitionDuration: "var(--duration-fast)",
                        transitionTimingFunction: "var(--ease-brand)",
                      }}
                    >
                      {following ? c.following : c.follow}
                    </button>
                  )}
                </div>
              </Card>
            </li>
          );
        })}
      </ul>

      <p
        className="pt-[var(--spacing-md)] text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {c.scopeNote}
      </p>
    </>
  );
}

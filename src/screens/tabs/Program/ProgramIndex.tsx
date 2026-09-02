import { Link } from "react-router";
import { PROGRAM_ART } from "@/assets/program";
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
 * The programs library — the followable programs, with follow state.
 *
 * The core six-week program is not listed: it is always followed and lives on
 * the Program tab itself, so the library only offers the extras.
 *
 * SCOPE: only the core six-week program is inside Deliverable 7. The programs
 * listed here are the website's and shipping them is a Change Request; this
 * screen exists so the browse-and-follow IA can be judged.
 */
export function ProgramIndex({ embedded = false }: { embedded?: boolean }) {
  const c = APP.programIndex;
  const { isFollowing, follow, unfollow } = useFollowedPrograms();
  const library = PROGRAMS.filter((p) => p.slug !== CORE_PROGRAM_SLUG);

  return (
    <>
      <p
        className="pb-[var(--spacing-md)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {embedded ? c.emptyIntro : c.intro}
      </p>

      <ul className="flex list-none flex-col gap-[var(--spacing-sm)] p-0">
        {library.map((program) => {
          const following = isFollowing(program.slug);

          return (
            <li key={program.slug}>
              <Card>
                {/* Program artwork is a Corveo asset that has not been
                    supplied; a placeholder tile spans the card's height. */}
                <div className="flex gap-[var(--spacing-xs)]">
                  <img
                    src={PROGRAM_ART[program.slug]}
                    alt=""
                    aria-hidden
                    className="w-[96px] flex-none self-stretch rounded-sm object-cover"
                  />

                  <div className="flex min-w-0 flex-1 flex-col">
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
                    </div>
                  </div>
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

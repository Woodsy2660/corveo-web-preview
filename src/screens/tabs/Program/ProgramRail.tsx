import { Link } from "react-router";
import { Button } from "@/components/ui/Button";
import { CheckIcon, PlusIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import { CORE_PROGRAM_SLUG, PROGRAMS } from "@/lib/programs";
import { PROGRAM_ART } from "@/assets/photos";

/**
 * The other programs, as a rail at the foot of the Program tab.
 *
 * This is the tab's only route to the rest of the library, so it carries
 * both jobs the header used to: `+` follows a program, and tapping one you
 * already follow makes it the program the tab opens on — the switcher that
 * used to be a row of pills. A program you do not follow opens its own page,
 * where the full description and the Follow button live.
 *
 * Follow state is passed in rather than read here: `useFollowedPrograms`
 * keeps its own copy of the state, so a second call would not re-render the
 * tab around it.
 */
export function ProgramRail({
  active,
  following,
  onToggleFollow,
  onSwitch,
}: {
  active: string;
  following: string[];
  onToggleFollow: (slug: string) => void;
  onSwitch: (slug: string) => void;
}) {
  const c = APP.program.rail;
  const ci = APP.programIndex;
  const rest = PROGRAMS.filter((p) => p.slug !== active);

  return (
    <section aria-label={c.heading} className="pt-[var(--spacing-lg)]">
      <div className="flex items-baseline gap-[var(--spacing-2xs)] pb-[var(--spacing-sm)]">
        <h2 style={{ fontSize: "var(--text-heading-xl)" }}>{c.heading}</h2>
        <span className="eyebrow">{c.sub}</span>
      </div>

      {/* Full-bleed rail: cards run to the screen edge so a part-visible
          card reads as "more to swipe" rather than as a clipped one. */}
      <ul className="no-scrollbar -mx-[var(--spacing-md)] m-0 flex list-none gap-[var(--spacing-xs)] overflow-x-auto px-[var(--spacing-md)]">
        {rest.map((program) => {
          const followed = following.includes(program.slug);
          // The core program is what the app is for: always followed, so it
          // carries no follow control, only the way back to it.
          const core = program.slug === CORE_PROGRAM_SLUG;

          return (
            <li key={program.slug} className="w-[150px] flex-none">
              <div className="relative">
                {/* Program artwork is a Corveo asset that has not been
                    supplied; a placeholder tile stands in. */}
                <img
                  src={PROGRAM_ART[program.slug]}
                  alt=""
                  aria-hidden
                  className="h-[96px] w-full rounded-sm object-cover"
                />

                {core ? null : (
                  <button
                    onClick={() => onToggleFollow(program.slug)}
                    aria-pressed={followed}
                    aria-label={
                      followed
                        ? c.unfollowAria(program.title)
                        : c.followAria(program.title)
                    }
                    className={`absolute right-0 -bottom-[14px] flex size-[44px] items-center justify-center rounded-round ${
                      followed
                        ? "border border-hairline bg-card text-heading"
                        : "bg-action text-action-ink"
                    }`}
                    style={{
                      transitionProperty: "background-color, color, border-color",
                      transitionDuration: "var(--duration-fast)",
                      transitionTimingFunction: "var(--ease-brand)",
                    }}
                  >
                    {followed ? <CheckIcon /> : <PlusIcon />}
                  </button>
                )}
              </div>

              {followed ? (
                <button
                  onClick={() => onSwitch(program.slug)}
                  aria-label={c.switchAria(program.title)}
                  className="block w-full pt-[var(--spacing-sm)] text-left"
                >
                  <RailCardText program={program} note={ci.following} />
                </button>
              ) : (
                <Link
                  to={`/app/program/${program.slug}`}
                  aria-label={c.openAria(program.title)}
                  className="block pt-[var(--spacing-sm)]"
                >
                  <RailCardText
                    program={program}
                    note={ci.chapterCount(program.chapters.length, program.unitLabel)}
                  />
                </Link>
              )}
            </li>
          );
        })}
      </ul>

      {/* The library page, where every program has its description and its
          own Follow: reached from here, not from a page of the core program. */}
      <Link to="/app/program/browse" className="block pt-[var(--spacing-md)]">
        <Button variant="secondary" tabIndex={-1}>
          {c.seeAll}
        </Button>
      </Link>
    </section>
  );
}

function RailCardText({
  program,
  note,
}: {
  program: (typeof PROGRAMS)[number];
  note: string;
}) {
  return (
    <>
      <h3
        className="pb-[var(--spacing-3xs)]"
        style={{
          fontSize: "var(--text-body-base)",
          lineHeight: "var(--leading-heading)",
        }}
      >
        {program.title}
      </h3>
      <span className="eyebrow">{note}</span>
    </>
  );
}

import { Screen, ProfileLink } from "@/components/ui/Screen";
import { SegmentedProgress } from "@/components/ui/SegmentedProgress";
import { APP } from "@/copy/app";
import { useProgramProgress } from "@/lib/api/hooks";
import { findProgram, readCount } from "@/lib/programs";
import { useFollowedPrograms } from "@/lib/useFollowedPrograms";
import { ChapterList } from "@/screens/tabs/Program/ChapterRow";
import { ProgramIndex } from "@/screens/tabs/Program/ProgramIndex";
import { ProgramRail } from "@/screens/tabs/Program/ProgramRail";

/**
 * Program tab (Deliverable 7).
 *
 * Opens on the program you are following, under a fixed title: the program's
 * own name is the subheading, so the page does not re-shape itself when you
 * switch. Follow none and the tab becomes the library instead of an empty
 * screen.
 *
 * Switching between followed programs, and following new ones, both happen
 * in the rail at the foot of the page — see ProgramRail.
 *
 * Content is authored and clinically reviewed by Corveo (client dependency
 * 5) and is static: it never varies with the reader's readings. The core
 * program releases a chapter a week — a calendar rhythm, not a response to
 * anything recorded.
 */
export function Program() {
  const { data: progress } = useProgramProgress();
  const { following, active, isFollowing, follow, unfollow, setActive } =
    useFollowedPrograms();
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
  const total = program.chapters.length;

  return (
    <Screen title={c.title} withTabBar action={<ProfileLink />} scrollKey={program.slug}>
      <SegmentedProgress read={read} total={total} label={c.progressAria(read, total)} />

      <h2
        className="pt-[var(--spacing-md)] pb-[var(--spacing-3xs)]"
        style={{ fontSize: "var(--text-heading-2xl)" }}
      >
        {program.title}
      </h2>

      <p
        className="pb-[var(--spacing-sm)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-base)" }}
      >
        {program.description}
      </p>

      <ChapterList program={program} progress={progress} />

      <ProgramRail
        active={active}
        following={following}
        onToggleFollow={(slug) => (isFollowing(slug) ? unfollow(slug) : follow(slug))}
        onSwitch={setActive}
      />
    </Screen>
  );
}

import { Link, Navigate, useNavigate, useParams } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { APP } from "@/copy/app";
import { useProgramProgress } from "@/lib/api/hooks";
import { CORE_PROGRAM_SLUG, findProgram, readCount } from "@/lib/programs";
import { useFollowedPrograms } from "@/lib/useFollowedPrograms";
import { ChapterList } from "@/screens/tabs/Program/ChapterRow";

/**
 * One program's chapter list, reached from the library. Same layout as the
 * tab, plus a follow control and a way back to the library.
 */
export function ProgramDetail() {
  const { slug } = useParams();
  const navigate = useNavigate();
  const { data: progress } = useProgramProgress();
  const { isFollowing, follow, unfollow, setActive } = useFollowedPrograms();

  const c = APP.program;
  const ci = APP.programIndex;

  // The route used to be /app/program/:week; the deployed preview is
  // bookmarked, so a bare number still resolves to the core program.
  if (slug && /^\d+$/.test(slug)) {
    return <Navigate to={`/app/program/${CORE_PROGRAM_SLUG}/${slug}`} replace />;
  }

  const program = findProgram(slug);

  const back = (
    <Link to="/app/program/browse" className="eyebrow underline underline-offset-4">
      {c.browseAll}
    </Link>
  );

  if (!program) {
    return (
      <Screen action={back} title={APP.chapter.notFound}>
        <Button onClick={() => navigate("/app/program/browse")}>{c.browseAll}</Button>
      </Screen>
    );
  }

  const following = isFollowing(program.slug);
  const core = program.slug === CORE_PROGRAM_SLUG;
  const read = readCount(progress, program);

  return (
    <Screen
      overline={ci.chapterCount(program.chapters.length, program.unitLabel)}
      title={program.title}
      action={back}
      footer={
        core ? undefined : (
          <Button
            variant={following ? "secondary" : "primary"}
            onClick={() => {
              if (following) {
                unfollow(program.slug);
              } else {
                follow(program.slug);
                setActive(program.slug);
                navigate("/app/program");
              }
            }}
          >
            {following ? ci.following : ci.follow}
          </Button>
        )
      }
    >
      <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-base)" }}>
        {program.description}
      </p>

      <p
        className="pt-[var(--spacing-2xs)] pb-[var(--spacing-sm)] text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {c.progress(read, program.chapters.length)}
      </p>

      <ChapterList program={program} progress={progress} />
    </Screen>
  );
}

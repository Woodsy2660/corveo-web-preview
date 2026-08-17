import { Link } from "react-router";
import { Screen, ProfileLink } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { APP } from "@/copy/app";
import { SAFETY, VALIDATED_CUFFS } from "@/copy/safety";

/**
 * Education tab — the reference library that sits alongside the six-week
 * program.
 *
 * Holds the two in-scope surfaces that are things to read rather than
 * things to administer: the safety surface ("what Corveo does and doesn't
 * do", Deliverable 12) and the validated-monitor list (Deliverable 8).
 * Both previously sat under Settings, which is now account and data only.
 *
 * Neither deliverable's content changed — only where it is reached from.
 * Worth reflecting in the Stage 2 and Stage 3 test scripts.
 *
 * The Pulse / In Focus / Corveo Picks are NOT in the sixteen deliverables.
 * If Corveo wants the publication's articles in the app, that is a change
 * request; this tab is where they would land.
 */
export function Education() {
  const c = APP.education;

  return (
    <Screen title={c.title} withTabBar action={<ProfileLink />}>
      <p
        className="pb-[var(--spacing-md)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {c.intro}
      </p>

      <div className="flex flex-col gap-[var(--spacing-sm)]">
        <Card label={c.aboutTitle}>
          <h2 className="pb-[var(--spacing-2xs)]" style={{ fontSize: "var(--text-heading-xl)" }}>
            {SAFETY.title}
          </h2>

          <p className="eyebrow pb-[var(--spacing-3xs)]">{SAFETY.does.title}</p>
          <ul
            className="list-disc pb-[var(--spacing-xs)] pl-[var(--spacing-sm)] text-ink-secondary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {SAFETY.does.items.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>

          <p className="eyebrow pb-[var(--spacing-3xs)]">{SAFETY.doesNot.title}</p>
          <ul
            className="list-disc pb-[var(--spacing-xs)] pl-[var(--spacing-sm)] text-ink-secondary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {SAFETY.doesNot.items.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>

          <p className="pb-[var(--spacing-2xs)]" style={{ fontSize: "var(--text-body-sm)" }}>
            {SAFETY.seekAdvice}
          </p>
          <p className="text-ink-tertiary" style={{ fontSize: "var(--text-label)" }}>
            {SAFETY.disclaimer}
          </p>
        </Card>

        <Card label={c.cuffsTitle}>
          <p
            className="pb-[var(--spacing-xs)] text-ink-secondary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {VALIDATED_CUFFS.intro}
          </p>
          <Link
            to="/app/cuffs"
            className="underline underline-offset-4"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {VALIDATED_CUFFS.title}
          </Link>
        </Card>
      </div>

      <p
        className="pt-[var(--spacing-md)] text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {c.moreNote}
      </p>
    </Screen>
  );
}

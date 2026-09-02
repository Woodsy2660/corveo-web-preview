import { Link, useNavigate } from "react-router";
import { Screen, ProfileLink } from "@/components/ui/Screen";
import { ChevronRightIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import { JOURNEY } from "@/copy/journey";
import { HEALTH_SYNC } from "@/copy/health-sync";
import { useConsentStatus, useProgramProgress, useReadings } from "@/lib/api/hooks";
import { CORE_PROGRAM_SLUG, findProgram } from "@/lib/programs";
import { useFollowedPrograms } from "@/lib/useFollowedPrograms";
import { useJourney } from "@/lib/journey/state";
import { fmtFullDate } from "@/lib/format";

/**
 * Settings, which is as much the patient's page as the app's: it opens on
 * who they are in the program (week, how readings arrive, the rhythm they
 * chose), then a short menu, each row a page: Apple Health (status,
 * refresh, pause), about this app (the safety surface, Deliverable 12),
 * your data (export, deletion, consent receipt, and the dev-only demo
 * reset) and the validated monitors (Deliverable 8).
 */
export function Settings() {
  const navigate = useNavigate();
  const { connectChoice, cadence } = useJourney();
  const { data: progress } = useProgramProgress();
  const { data: readings } = useReadings(400);
  const { data: consent } = useConsentStatus();
  const { following } = useFollowedPrograms();
  const c = APP.settings;

  const program = findProgram(CORE_PROGRAM_SLUG);
  const followedTitles = following
    .filter((slug) => slug !== CORE_PROGRAM_SLUG)
    .map((slug) => findProgram(slug)?.title)
    .filter((title): title is string => Boolean(title));
  // The list arrives newest first; the record began with the last of it.
  const earliest = readings && readings.length > 0 ? readings[readings.length - 1] : undefined;

  const profileRows: [string, string][] = [
    [
      c.profile.programLabel,
      program ? c.profile.program(progress?.current_week ?? 1, program.chapters.length) : "",
    ],
    [c.profile.followingLabel, followedTitles.length > 0 ? followedTitles.join(", ") : c.profile.followingNone],
    [
      c.profile.readingsLabel,
      `${connectChoice ? c.profile.readings[connectChoice] : c.profile.readings.none} · ${c.profile.readingCount(readings?.length ?? 0)}`,
    ],
    [c.profile.beganLabel, earliest ? fmtFullDate(earliest.effective_time) : c.profile.beganNone],
    [c.profile.rhythmLabel, cadence ? JOURNEY.cadence.options[cadence].title : c.profile.rhythmUnset],
    [
      c.profile.consentLabel,
      consent?.has_active_consent && consent.version && consent.last_event_at
        ? c.profile.consentGiven(fmtFullDate(consent.last_event_at), consent.version)
        : c.profile.consentNone,
    ],
  ];

  const menu: [string, string][] = [
    [c.menu.appleHealth, "/app/settings/apple-health"],
    [c.menu.about, "/app/settings/about"],
    [c.menu.data, "/app/settings/data"],
    [c.menu.monitors, "/app/cuffs"],
  ];

  return (
    <Screen title={c.title} action={<ProfileLink />}>
      <div className="flex flex-col gap-[var(--spacing-sm)]">
        {/* — You — the facts the patient set on the way in, as a quiet list. */}
        <section aria-label={c.profile.title} className="pb-[var(--spacing-2xs)]">
          <p className="eyebrow pb-[var(--spacing-2xs)]">{c.profile.title}</p>
          <dl className="m-0 flex flex-col">
            {profileRows.map(([label, value]) => (
              <div
                key={label}
                className="flex items-baseline justify-between gap-[var(--spacing-sm)] border-b border-hairline py-[var(--spacing-2xs)]"
              >
                <dt className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
                  {label}
                </dt>
                <dd className="m-0 text-right" style={{ fontSize: "var(--text-body-sm)" }}>
                  {value}
                </dd>
              </div>
            ))}
          </dl>
        </section>

        {/* — Menu — each row is a page of its own; the whole row is the tap. */}
        <nav aria-label={c.menuAria}>
          <ul className="m-0 flex list-none flex-col p-0">
            {menu.map(([label, to]) => (
              <li key={to} className="border-b border-hairline">
                <Link
                  to={to}
                  className="flex items-center justify-between py-[var(--spacing-sm)] text-heading"
                  style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}
                >
                  {label}
                  <span className="text-ink-tertiary" style={{ fontSize: "var(--text-body-lg)" }}>
                    <ChevronRightIcon />
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        </nav>

        {/*
         * Quiet entry to the presentation. Deliberately the last thing on the
         * last screen: a patient never needs it, and anyone being walked
         * through the build will be shown where it is.
         */}
        <button
          onClick={() => navigate("/behind")}
          className="pt-[var(--spacing-2xs)] pb-[var(--spacing-md)] text-center text-ink-tertiary underline underline-offset-4"
          style={{ fontSize: "var(--text-label)" }}
        >
          {HEALTH_SYNC.behindLink}
        </button>
      </div>
    </Screen>
  );
}

import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router";
import { Screen, ProfileLink } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ChevronRightIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import { JOURNEY } from "@/copy/journey";
import { HEALTH_SYNC } from "@/copy/health-sync";
import { resetApi } from "@/lib/api";
import { useProgramProgress } from "@/lib/api/hooks";
import { CORE_PROGRAM_SLUG, findProgram, readCount } from "@/lib/programs";
import { getHealthPlugin, resetHealthPlugin, type AuthorizationState } from "@/lib/health";
import { useJourney } from "@/lib/journey/state";
import { useQueryClient } from "@tanstack/react-query";

/**
 * Settings, which is as much the patient's page as the app's: it opens on
 * who they are in the program (week, how readings arrive, the rhythm they
 * chose), then Apple Health status, then a short menu to the longer
 * reading: about this app (the safety surface, Deliverable 12), your data
 * (export, deletion, consent receipt) and the validated monitors
 * (Deliverable 8). The dev-only demo reset stays at the foot.
 */
export function Settings() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { resetJourney, connectChoice, cadence } = useJourney();
  const { data: progress } = useProgramProgress();
  const [health, setHealth] = useState<AuthorizationState | null>(null);
  const c = APP.settings;

  useEffect(() => {
    void getHealthPlugin().getAuthorizationState().then(setHealth);
  }, []);

  const resetDemo = async () => {
    resetApi();
    resetHealthPlugin();
    resetJourney();
    qc.clear();
    navigate("/journey/welcome", { replace: true });
  };

  const connected = health?.state === "requested";
  const program = findProgram(CORE_PROGRAM_SLUG);
  const profileRows: [string, string][] = [
    [
      c.profile.programLabel,
      program
        ? `${c.profile.program(progress?.current_week ?? 1, program.chapters.length)} · ${APP.program.progress(readCount(progress, program), program.chapters.length)}`
        : "",
    ],
    [c.profile.readingsLabel, connectChoice ? c.profile.readings[connectChoice] : c.profile.readings.none],
    [c.profile.rhythmLabel, cadence ? JOURNEY.cadence.options[cadence].title : c.profile.rhythmUnset],
  ];

  const menu: [string, string][] = [
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

        <Card label={c.appleHealth.title}>
          <p style={{ fontSize: "var(--text-body-sm)" }}>
            {connected ? c.appleHealth.readsOnly : c.appleHealth.notConnected}
          </p>
          {connected && health && !health.samplesEverReceived ? (
            // Neutral nudge, verbatim from docs/03 §4 — absence of data is
            // indistinguishable from denial, and we never imply denial.
            <p className="pt-[var(--spacing-2xs)]" style={{ fontSize: "var(--text-body-sm)" }}>
              {JOURNEY.healthAuth.noSamplesNudge}
            </p>
          ) : null}
          <p className="pt-[var(--spacing-3xs)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
            {c.appleHealth.manageHint}
          </p>
        </Card>

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

        {import.meta.env.DEV || import.meta.env.VITE_DEMO === "true" ? (
          <Card label={c.demo.title}>
            <Button variant="secondary" onClick={resetDemo}>
              {c.demo.resetCta}
            </Button>
            <p className="pt-[var(--spacing-2xs)] text-ink-tertiary" style={{ fontSize: "var(--text-label)" }}>
              {c.demo.note}
            </p>
          </Card>
        ) : null}

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

import { Link, useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { Chip } from "@/components/ui/Chip";
import { Card } from "@/components/ui/Card";
import { APP } from "@/copy/app";
import { useReadings } from "@/lib/api/hooks";
import { fmtDateTime } from "@/lib/format";

/** Readings tab — the reading history, exactly as recorded. */
export function Readings() {
  const navigate = useNavigate();
  const { data: readings, isLoading } = useReadings(30);
  const c = APP.readings;

  return (
    <Screen
      eyebrow={c.eyebrow}
      title={c.title}
      withTabBar
      action={
        <Link to="/app/settings" className="eyebrow underline underline-offset-4">
          Settings
        </Link>
      }
    >
      <div className="pb-[var(--spacing-sm)]">
        <Button onClick={() => navigate("/app/add")}>{c.addCta}</Button>
      </div>

      {isLoading ? null : !readings || readings.length === 0 ? (
        <Card>
          <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
            {c.empty}
          </p>
        </Card>
      ) : (
        <>
          {readings.length < 8 ? (
            <p className="pb-[var(--spacing-xs)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
              {c.sparse}
            </p>
          ) : null}
          <ul className="flex flex-col gap-[var(--spacing-2xs)]">
            {readings.map((r) => (
              <li
                key={r.id}
                className="flex items-center justify-between rounded-md bg-card px-[var(--spacing-sm)] py-[var(--spacing-xs)]"
              >
                <div>
                  <span style={{ fontSize: "var(--text-body-lg)", fontWeight: 500 }}>
                    {r.systolic}/{r.diastolic}
                  </span>
                  <span className="pl-[var(--spacing-2xs)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
                    mmHg
                  </span>
                  <span className="block text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
                    {fmtDateTime(r.effective_time)}
                  </span>
                </div>
                <div className="flex flex-col items-end gap-[var(--spacing-3xs)]">
                  <Chip>{r.source_type === "healthkit" ? c.sourceHealth : c.sourceManual}</Chip>
                  {r.body_site_display ? <Chip>{r.body_site_display}</Chip> : null}
                </div>
              </li>
            ))}
          </ul>
        </>
      )}
    </Screen>
  );
}

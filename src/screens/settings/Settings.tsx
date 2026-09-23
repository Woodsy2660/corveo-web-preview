import { Link, useNavigate } from "react-router";
import { Screen, ProfileLink } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { ChevronRightIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import { JOURNEY } from "@/copy/journey";
import { useJourney } from "@/lib/journey/state";

/**
 * Settings: the signed-in line, then only things the patient can change or
 * act on — account, how readings arrive, reminder, validated monitors,
 * the record (export, deletion, consent), and what Corveo does. Sign out
 * lives on Account. Program week and reading counts live on those tabs.
 */

function MenuRow({ label, value, to }: { label: string; value?: string; to: string }) {
  return (
    <li className="border-b border-hairline">
      <Link
        to={to}
        className="flex items-center justify-between gap-[var(--spacing-sm)] py-[var(--spacing-sm)] text-heading"
        style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}
      >
        <span className="min-w-0">{label}</span>
        <span
          className="flex min-w-0 shrink-0 items-center gap-[var(--spacing-2xs)] text-ink-tertiary"
          style={{ fontSize: "var(--text-body-sm)", fontWeight: 400 }}
        >
          {value ? <span className="max-w-[11rem] truncate">{value}</span> : null}
          <span style={{ fontSize: "var(--text-body-lg)" }}>
            <ChevronRightIcon />
          </span>
        </span>
      </Link>
    </li>
  );
}

export function Settings() {
  const navigate = useNavigate();
  const { connectChoice, cadence, email } = useJourney();
  const c = APP.settings;

  const arriveValue = connectChoice ? c.profile.readings[connectChoice] : c.profile.readings.none;
  const reminderValue = cadence ? JOURNEY.cadence.options[cadence].title : c.menu.reminderUnset;

  return (
    <Screen
      title={c.title}
      action={<ProfileLink />}
      footer={
        <Button variant="ghost" onClick={() => navigate("/app/record")}>
          {APP.common.back}
        </Button>
      }
    >
      <div className="flex flex-col gap-[var(--spacing-sm)]">
        {email ? (
          <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
            {c.account.signedInAs(email)}
          </p>
        ) : null}

        <nav aria-label={c.menuAria}>
          <ul className="m-0 flex list-none flex-col p-0">
            <MenuRow label={c.menu.account} value={email ?? c.account.none} to="/app/settings/account" />
          </ul>
        </nav>

        <nav aria-label={c.menu.readingsGroup}>
          <p className="eyebrow pb-[var(--spacing-2xs)]">{c.menu.readingsGroup}</p>
          <ul className="m-0 flex list-none flex-col p-0">
            <MenuRow label={c.menu.readingsArrive} value={arriveValue} to="/app/settings/readings" />
            <MenuRow label={c.menu.reminder} value={reminderValue} to="/app/settings/reminder" />
            <MenuRow label={c.menu.monitors} to="/app/cuffs" />
          </ul>
        </nav>

        <nav aria-label={c.menuAria}>
          <ul className="m-0 flex list-none flex-col p-0">
            <MenuRow label={c.menu.record} to="/app/settings/data" />
            <MenuRow label={c.menu.about} to="/app/settings/about" />
          </ul>
        </nav>
      </div>
    </Screen>
  );
}

import { useState } from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { ChevronDownIcon } from "@/components/ui/icons";
import { ValidatedCuffList } from "@/components/ui/ValidatedCuffList";
import { APP } from "@/copy/app";
import { JOURNEY } from "@/copy/journey";
import { getHealthPlugin } from "@/lib/health";
import { useAppleHealthSync } from "@/lib/health/useAppleHealthSync";
import { useJourney, type ConnectChoice } from "@/lib/journey/state";

const ORDER: ConnectChoice[] = ["healthkit", "manual", "none"];

/**
 * How readings arrive, from Settings. Same choices as the journey connect
 * step; a tap writes the choice immediately.
 *
 * Leaving Apple Health stops Corveo looking for new readings. It does not
 * (and cannot) revoke the iOS permission — that stays in Settings › Health.
 */
export function ReadingsArrive() {
  const navigate = useNavigate();
  const { connectChoice, setConnectChoice } = useJourney();
  const health = useAppleHealthSync();
  const [cuffsOpen, setCuffsOpen] = useState(false);
  const page = APP.settings.readingsArrive;
  const c = JOURNEY.connect;

  const choose = async (key: ConnectChoice) => {
    setConnectChoice(key);
    const plugin = getHealthPlugin();
    if (key === "healthkit") {
      const auth = await plugin.getAuthorizationState();
      if (auth.state === "requested") await plugin.startObserving();
    } else {
      await plugin.stopObserving();
    }
  };

  return (
    <Screen
      title={page.title}
      footer={
        <Button variant="ghost" onClick={() => navigate(-1)}>
          {APP.common.back}
        </Button>
      }
    >
      <p
        className="pb-[var(--spacing-lg)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-body-relaxed)" }}
      >
        {page.intro}
      </p>

      <div className="flex flex-col" role="radiogroup" aria-label={page.title}>
        {ORDER.map((key, i) => {
          const opt = c.options[key];
          const selected = connectChoice === key;
          return (
            <button
              key={key}
              role="radio"
              aria-checked={selected}
              onClick={() => void choose(key)}
              className={`flex items-start gap-[var(--spacing-sm)] border-b border-hairline py-[var(--spacing-sm)] text-left ${
                i === 0 ? "border-t" : ""
              }`}
            >
              <span
                className="mt-[3px] flex size-[20px] flex-none items-center justify-center rounded-round border-2"
                style={{
                  borderColor: selected ? "var(--app-heading)" : "var(--app-hairline)",
                }}
              >
                {selected ? <span className="block size-[10px] rounded-round bg-heading" /> : null}
              </span>
              <div className="min-w-0">
                <span
                  className={selected ? "text-heading" : ""}
                  style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}
                >
                  {opt.title}
                </span>
                {selected ? (
                  <p
                    className="pt-[var(--spacing-3xs)] text-ink-secondary"
                    style={{ fontSize: "var(--text-body-sm)", lineHeight: "var(--leading-body)" }}
                  >
                    {opt.body}
                  </p>
                ) : null}
              </div>
            </button>
          );
        })}
      </div>

      {connectChoice !== "healthkit" && health.active ? (
        <p className="pt-[var(--spacing-md)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
          {page.leavingHealth}
        </p>
      ) : null}

      {connectChoice === "none" ? (
        <div className="pt-[var(--spacing-sm)]">
          <button
            type="button"
            onClick={() => setCuffsOpen((v) => !v)}
            aria-expanded={cuffsOpen}
            className="flex w-full items-center justify-between py-[var(--spacing-xs)] text-left"
          >
            <span
              className="text-ink-secondary underline underline-offset-4"
              style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}
            >
              {c.cuffsLink}
            </span>
            <span
              className="flex-none text-ink-tertiary"
              style={{
                fontSize: "var(--text-body-sm)",
                transform: cuffsOpen ? "rotate(180deg)" : "rotate(0deg)",
                transition: "transform var(--duration-fast) var(--ease-brand)",
              }}
            >
              <ChevronDownIcon />
            </span>
          </button>
          {cuffsOpen ? (
            <div className="pb-[var(--spacing-xs)]">
              <ValidatedCuffList />
            </div>
          ) : null}
        </div>
      ) : null}
    </Screen>
  );
}

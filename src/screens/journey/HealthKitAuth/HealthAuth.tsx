import { useState } from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { APP } from "@/copy/app";
import { JOURNEY } from "@/copy/journey";
import { getHealthPlugin } from "@/lib/health";

/**
 * HealthKit authorisation (healthkit branch of connect).
 *
 * Permission-state rule (docs/03 §4): the outcome of the request is
 * unknowable by design. After requesting, we proceed on `requested` and
 * never render or store a "denied" state.
 */
export function HealthAuth() {
  const navigate = useNavigate();
  const c = JOURNEY.healthAuth;
  const [requesting, setRequesting] = useState(false);

  const request = async () => {
    setRequesting(true);
    try {
      const plugin = getHealthPlugin();
      await plugin.requestAuthorization();
      await plugin.startObserving();
      navigate("/journey/capture");
    } finally {
      setRequesting(false);
    }
  };

  return (
    <Screen
      eyebrow={c.eyebrow}
      title={c.title}
      footer={
        <div className="flex flex-col gap-[var(--spacing-xs)]">
          <Button disabled={requesting} onClick={request}>
            {requesting ? APP.common.busy : c.cta}
          </Button>
          <Button variant="ghost" onClick={() => navigate("/journey/capture")}>
            {c.skip}
          </Button>
        </div>
      }
    >
      <StepDots total={5} current={3} />
      <p className="text-ink-secondary">{c.intro}</p>
    </Screen>
  );
}

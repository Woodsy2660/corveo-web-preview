import { useState } from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { AppleHealthSheet } from "@/components/ui/AppleHealthSheet";
import { APP } from "@/copy/app";
import { JOURNEY } from "@/copy/journey";
import { CORVEO_WORDMARK } from "@/copy/product";
import { getHealthPlugin } from "@/lib/health";
import { setStoreReadable } from "@/lib/health/demo";

/**
 * HealthKit authorisation (healthkit branch of connect).
 *
 * Permission-state rule (docs/03 §4): the outcome of the request is
 * unknowable by design. After requesting, we proceed on `requested` and
 * never render or store a "denied" state.
 *
 * The sheet is Apple's, and so is the decision. Both of its buttons land
 * here in exactly the same place — `onDismiss` carries no verdict, because
 * on a real device there is none to carry.
 */
export function HealthAuth() {
  const navigate = useNavigate();
  const c = JOURNEY.healthAuth;
  const [sheetOpen, setSheetOpen] = useState(false);
  const [requesting, setRequesting] = useState(false);

  const settle = async (readable: boolean) => {
    setSheetOpen(false);
    setRequesting(true);
    try {
      // Demo only: tells the simulated Health store whether it will hand
      // anything over. The plugin is not told, and cannot be.
      setStoreReadable(readable);

      const plugin = getHealthPlugin();
      await plugin.requestAuthorization();
      await plugin.startObserving();
      navigate("/journey/capture");
    } finally {
      setRequesting(false);
    }
  };

  return (
    <>
      <Screen
        overline={c.eyebrow}
        title={c.title}
        footer={
          <div className="flex flex-col gap-[var(--spacing-xs)]">
            <Button disabled={requesting} onClick={() => setSheetOpen(true)}>
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

      <AppleHealthSheet
        open={sheetOpen}
        appName={CORVEO_WORDMARK}
        onDismiss={settle}
      />
    </>
  );
}

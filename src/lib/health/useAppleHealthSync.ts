import { useCallback, useEffect, useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { HEALTH_SYNC } from "@/copy/health-sync";
import { queryKeys } from "@/lib/api/hooks";
import { getHealthPlugin, type AuthorizationState, type SyncResult } from "@/lib/health";
import { subscribeDemoHealth, takeCuffReading, unreadCount } from "@/lib/health/demo";
import { useJourney } from "@/lib/journey/state";
import { fmtTime } from "@/lib/format";

export type SyncPhase = "idle" | "busy" | "done";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * The Apple Health surface, as state: whether authorisation was requested,
 * when the app last looked, and a way to look now. It reports mechanism —
 * never anything about a value, and never a "denied" state we are not
 * entitled to claim.
 *
 * One quiet check runs when the record opens, the way the native app catches
 * up on every activation (docs/03 §5), so the patient arrives to "Updated"
 * rather than "Waiting". `sync` runs the same check on demand. In the web
 * preview, where no cuff exists, `sync` also stands in for the cuff having
 * taken a reading since you last looked — that part, and only that part, is
 * gated to the demo build.
 */
export function useAppleHealthSync() {
  const qc = useQueryClient();
  const { connectChoice } = useJourney();
  const c = HEALTH_SYNC.card;
  const [auth, setAuth] = useState<AuthorizationState | null>(null);
  const [phase, setPhase] = useState<SyncPhase>("idle");
  const [arrived, setArrived] = useState(false);
  const openedCheck = useRef(false);

  /** Re-read the authorisation state, after connecting from Settings. */
  const refresh = useCallback(async () => {
    setAuth(await getHealthPlugin().getAuthorizationState());
  }, []);

  useEffect(() => {
    void refresh();
    return subscribeDemoHealth(() => {});
  }, [refresh]);

  /** The check itself: look, record when we looked, refresh the record if anything came. */
  const check = useCallback(async (): Promise<SyncResult> => {
    const result = await getHealthPlugin().syncNow();
    setAuth(await getHealthPlugin().getAuthorizationState());
    if (result.inserted > 0) {
      await qc.invalidateQueries({ queryKey: queryKeys.readings });
      await qc.invalidateQueries({ queryKey: queryKeys.trend });
    }
    return result;
  }, [qc]);

  const active = auth?.state === "requested";
  const looking = active && connectChoice === "healthkit";

  useEffect(() => {
    if (!looking || openedCheck.current) return;
    openedCheck.current = true;
    void check();
  }, [looking, check]);

  const sync = async () => {
    setPhase("busy");
    setArrived(false);

    const isDemoBuild = import.meta.env.DEV || import.meta.env.VITE_DEMO === "true";
    if (isDemoBuild && unreadCount() === 0) takeCuffReading();

    // A held beat. Returning instantly reads as "nothing happened" rather
    // than "it looked and there was nothing".
    const [result] = await Promise.all([check(), sleep(420)]);
    if (result.inserted > 0) setArrived(true);

    setPhase("done");
    window.setTimeout(() => setPhase("idle"), 2200);
    if (result.inserted > 0) window.setTimeout(() => setArrived(false), 4000);
  };

  const status = !active
    ? null
    : arrived
      ? c.arrived
      : auth?.lastSuccessfulSyncAt
        ? c.updated(fmtTime(auth.lastSuccessfulSyncAt))
        : c.waiting;

  const label = phase === "busy" ? c.sync.busy : phase === "done" ? c.sync.done : c.sync.idle;

  return {
    active,
    status,
    arrived,
    phase,
    label,
    sync,
    refresh,
    samplesEverReceived: auth?.samplesEverReceived ?? true,
  };
}

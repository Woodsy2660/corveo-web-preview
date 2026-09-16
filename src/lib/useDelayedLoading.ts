import { useEffect, useState } from "react";

/**
 * Delays showing a loading indicator by a grace period.
 *
 * The loading-state orchestration from the motion research
 * (docs/UI animation research.md, Loading states) says:
 *   0–300ms: show nothing
 *   300ms–1s: spinner or skeleton
 *   >4s: progress message
 *
 * This hook returns `true` only after `isLoading` has been true for
 * longer than `delayMs` (default 300ms), preventing skeleton flashes
 * on fast loads.
 */
export function useDelayedLoading(isLoading: boolean, delayMs = 300): boolean {
  const [show, setShow] = useState(false);

  useEffect(() => {
    if (!isLoading) {
      setShow(false);
      return;
    }
    const t = setTimeout(() => setShow(true), delayMs);
    return () => clearTimeout(t);
  }, [isLoading, delayMs]);

  return isLoading && show;
}

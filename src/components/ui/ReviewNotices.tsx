/**
 * Review notices for draft content (CON-03).
 *
 * DISABLED: All review notices hidden per user request.
 * The user requested removal of all draft/preview markers for the
 * designer review prototype.
 */

/** App-wide banner - DISABLED */
export function PreviewBanner() {
  return null;
}

/** Review hold marker on week cards - DISABLED */
export function ReviewHoldMarker(_props: { holds: readonly string[] }) {
  return null;
}

/** Week 4 interstitial - DISABLED */
export function Week4Interstitial(_props: {
  open: boolean;
  onContinue: () => void;
  onBack: () => void;
}) {
  return null;
}

/** Hook for Week 4 interstitial - returns no-op */
export function useWeek4Interstitial() {
  return {
    showInterstitial: false,
    pendingWeek: null,
    checkWeek4: (_week: number, callback: () => void) => callback(),
    handleContinue: (callback: () => void) => callback(),
    handleBack: () => {},
  };
}

/** Chapter holds notice - DISABLED */
export function ChapterHoldsNotice(_props: { holds: readonly string[] }) {
  return null;
}

/** Takeaway review note - DISABLED */
export function TakeawayReviewNote(_props: { show: boolean }) {
  return null;
}

/** Chapter draft notice - DISABLED */
export function ChapterDraftNotice(_props: {
  publishable: boolean;
  holds?: readonly string[];
}) {
  return null;
}

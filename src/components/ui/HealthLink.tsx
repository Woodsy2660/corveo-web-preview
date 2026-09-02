import { CORVEO_WORDMARK } from "@/copy/product";
import healthIconUrl from "@/assets/brand/apple-health.png";
import logoUrl from "@/assets/brand/logo.svg";

/**
 * The Health-to-Corveo link, drawn: the Health app icon, one arrow, the
 * Corveo mark. The arrow points one way because the data only ever goes one
 * way (docs/03 §1: read-only; Corveo never writes to HealthKit). Decorative;
 * the copy above it carries the meaning, for screen readers and everyone else.
 */
export function HealthLink() {
  return (
    <figure className="m-0 flex items-center justify-center gap-[var(--spacing-sm)]" aria-hidden>
      <img src={healthIconUrl} alt="" style={{ width: "88px", height: "88px" }} />

      <svg
        viewBox="0 0 24 24"
        width="24"
        height="24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="text-ink-tertiary"
      >
        <path d="M3 12h18" />
        <path d="M14 5l7 7-7 7" />
      </svg>

      <div
        className="flex items-center justify-center rounded-lg border border-hairline bg-card"
        style={{ width: "88px", height: "88px" }}
      >
        <img src={logoUrl} alt={CORVEO_WORDMARK} style={{ width: "64px", height: "auto" }} />
      </div>
    </figure>
  );
}

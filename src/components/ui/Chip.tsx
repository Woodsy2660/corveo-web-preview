import type { ReactNode } from "react";

/**
 * Provenance chip (source, arm, time of day). Informational only.
 *
 * This is Userkind's `Tag / sm` — 28px tall, radius/sm, hairline border on
 * white, Body/sm at regular weight. The system sets the label black; we hold
 * it at secondary because provenance is subordinate to the reading it
 * annotates. Horizontal padding is 12px rather than the system's 14px to
 * stay on the spacing scale.
 */
export function Chip({ children }: { children: ReactNode }) {
  return (
    <span
      className="inline-block rounded-sm border border-hairline bg-card px-[var(--spacing-xs)] py-[var(--spacing-3xs)] text-ink-secondary"
      style={{
        fontSize: "var(--text-body-sm)",
        lineHeight: "var(--leading-body-relaxed)",
        letterSpacing: "0.01em",
      }}
    >
      {children}
    </span>
  );
}

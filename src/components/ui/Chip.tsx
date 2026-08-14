import type { ReactNode } from "react";

/** Small mono provenance chip (source, arm, time of day). Informational only. */
export function Chip({ children }: { children: ReactNode }) {
  return (
    <span
      className="inline-block rounded-round border border-hairline px-[var(--spacing-2xs)] py-[2px] font-mono text-ink-tertiary"
      style={{ fontSize: "11px", letterSpacing: "0.06em" }}
    >
      {children}
    </span>
  );
}

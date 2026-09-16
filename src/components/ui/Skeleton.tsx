/**
 * Loading placeholder that mirrors the shape of incoming content.
 * Uses a gentle opacity pulse (skeleton-pulse in app.css), never a
 * shimmer — a single-cycle pulse is less vestibular-triggering and
 * compliant with WCAG 2.2 SC 2.2.2 (docs/UI animation research.md §5).
 *
 * Under prefers-reduced-motion the pulse is disabled and it renders
 * as a static grey block.
 */
export function Skeleton({
  width,
  height = 16,
  className = "",
}: {
  width?: number | string;
  height?: number | string;
  className?: string;
}) {
  return (
    <div
      className={`skeleton ${className}`}
      style={{ width, height }}
      aria-hidden
    />
  );
}

/** A row-shaped skeleton matching the reading list row layout. */
export function ReadingRowSkeleton() {
  return (
    <div className="flex items-center justify-between gap-[var(--spacing-sm)] border-b border-hairline py-[var(--spacing-xs)]">
      <div className="flex items-center gap-[var(--spacing-2xs)]">
        <Skeleton width={72} height={18} />
        <Skeleton width={40} height={14} />
      </div>
      <div className="flex items-center gap-[var(--spacing-2xs)]">
        <Skeleton width={96} height={14} />
        <Skeleton width={48} height={14} />
      </div>
    </div>
  );
}

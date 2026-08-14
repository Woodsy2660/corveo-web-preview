/** Journey progress indicator — one dot per step, current dot elongated. */
export function StepDots({ total, current }: { total: number; current: number }) {
  return (
    <div
      className="flex items-center gap-[var(--spacing-2xs)] pb-[var(--spacing-sm)]"
      role="progressbar"
      aria-valuemin={1}
      aria-valuemax={total}
      aria-valuenow={current}
    >
      {Array.from({ length: total }, (_, i) => (
        <span
          key={i}
          className={`h-[6px] rounded-round transition-all ${
            i + 1 === current ? "w-[24px] bg-heading" : "w-[6px] bg-hairline"
          }`}
        />
      ))}
    </div>
  );
}

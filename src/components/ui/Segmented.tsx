/**
 * Segmented control (e.g. trend range 1W / 6W / All). A row of pills on the
 * page ground: the chosen one filled, the others outlined so they read as
 * choices rather than labels. No shared box, so it sits as a line of
 * controls over the chart rather than a second card.
 */
export function Segmented<T extends string>({
  options,
  value,
  onChange,
  ariaLabel,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
  ariaLabel: string;
}) {
  return (
    <div
      className="inline-flex gap-[var(--spacing-2xs)]"
      role="radiogroup"
      aria-label={ariaLabel}
    >
      {options.map((opt) => (
        <button
          key={opt.value}
          role="radio"
          aria-checked={value === opt.value}
          onClick={() => onChange(opt.value)}
          className={`rounded-round border px-[var(--spacing-sm)] py-[var(--spacing-3xs)] transition-colors ${
            value === opt.value
              ? "border-heading bg-action text-action-ink"
              : "border-hairline bg-transparent text-ink-secondary"
          }`}
          style={{ fontSize: "var(--text-body-sm)" }}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}

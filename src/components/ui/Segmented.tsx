/**
 * Segmented control (e.g. trend range 1W / 6W / All). Sits on the page
 * ground with no box of its own: the selected pill is the only ink, so the
 * control reads as a label on the chart rather than a second card.
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
      className="inline-flex rounded-round"
      role="radiogroup"
      aria-label={ariaLabel}
    >
      {options.map((opt) => (
        <button
          key={opt.value}
          role="radio"
          aria-checked={value === opt.value}
          onClick={() => onChange(opt.value)}
          className={`rounded-round px-[var(--spacing-sm)] py-[var(--spacing-3xs)] transition-colors ${
            value === opt.value ? "bg-action text-action-ink" : "text-ink-tertiary"
          }`}
          style={{ fontSize: "var(--text-body-sm)" }}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}

/**
 * Segmented control (e.g. trend range 1W / 6W / All). One outlined pill
 * holding the options, the chosen one filled: the same shape as the tab
 * bar, so the two read as the same kind of thing. Transparent inside, so
 * it sits on the page ground rather than as a second card.
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
      className="inline-flex gap-[2px] rounded-round border border-hairline p-[2px]"
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
            value === opt.value ? "bg-action text-action-ink" : "text-ink-secondary"
          }`}
          style={{ fontSize: "var(--text-body-sm)" }}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}

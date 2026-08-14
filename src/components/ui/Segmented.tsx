/** Segmented control (e.g. trend range 2W / 6W / All). */
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
      className="inline-flex rounded-round border border-hairline bg-card p-[2px]"
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

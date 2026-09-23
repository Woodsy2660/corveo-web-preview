import { useEffect, useId, useRef, useState } from "react";
import { CheckIcon, ChevronDownIcon } from "@/components/ui/icons";

/**
 * App-styled listbox. Native <select> paints the OS menu (white chrome,
 * system type) which does not match the page. This one uses the same
 * pill, hairline, and selected fill as Segmented.
 */
export function Select<T extends string>({
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
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const listId = useId();
  const selected = options.find((opt) => opt.value === value) ?? options[0];
  if (!selected) return null;

  useEffect(() => {
    if (!open) return;
    const onPointer = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("pointerdown", onPointer);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("pointerdown", onPointer);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        aria-label={ariaLabel}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listId}
        onClick={() => setOpen((v) => !v)}
        className={`inline-flex min-h-[36px] items-center gap-[var(--spacing-2xs)] whitespace-nowrap rounded-round border px-[var(--spacing-xs)] py-[var(--spacing-3xs)] ${
          open ? "border-heading bg-action text-action-ink" : "border-hairline bg-transparent text-ink-secondary"
        }`}
        style={{
          fontSize: "var(--text-body-sm)",
          fontWeight: 500,
          letterSpacing: "-0.01em",
          transitionProperty: "background-color, color, border-color",
          transitionDuration: "var(--duration-micro)",
          transitionTimingFunction: "var(--ease-brand)",
        }}
      >
        {selected.label}
        <span
          className="flex size-[12px] items-center justify-center"
          style={{ transform: open ? "rotate(180deg)" : undefined }}
        >
          <ChevronDownIcon />
        </span>
      </button>

      {open ? (
        <ul
          id={listId}
          role="listbox"
          aria-label={ariaLabel}
          className="absolute right-0 z-20 mt-[var(--spacing-3xs)] min-w-full overflow-hidden rounded-md border border-hairline bg-page py-[var(--spacing-3xs)]"
        >
          {options.map((opt) => {
            const isSelected = opt.value === value;
            return (
              <li key={opt.value} role="presentation">
                <button
                  type="button"
                  role="option"
                  aria-selected={isSelected}
                  onClick={() => {
                    onChange(opt.value);
                    setOpen(false);
                  }}
                  className={`flex w-full items-center justify-between gap-[var(--spacing-xs)] whitespace-nowrap px-[var(--spacing-xs)] py-[var(--spacing-2xs)] text-left ${
                    isSelected ? "bg-action text-action-ink" : "bg-transparent text-heading"
                  }`}
                  style={{
                    fontSize: "var(--text-body-sm)",
                    fontWeight: 500,
                    minHeight: 36,
                  }}
                >
                  {opt.label}
                  {isSelected ? (
                    <span className="flex size-[12px] items-center justify-center">
                      <CheckIcon />
                    </span>
                  ) : null}
                </button>
              </li>
            );
          })}
        </ul>
      ) : null}
    </div>
  );
}

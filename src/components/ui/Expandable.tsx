import { useState, type ReactNode } from "react";
import { ChevronDownIcon } from "@/components/ui/icons";

/**
 * Expandable card — progressive disclosure for dense screens.
 *
 * Title is always visible; body expands on tap. Uses the same visual
 * language as Card (white, hairline border, radius-md) so it reads as
 * the same surface with a disclosure affordance.
 *
 * Built for the 60+ audience: the entire card is the tap target, the
 * chevron rotates to signal state, and the transition is short enough
 * to feel immediate but long enough to show direction.
 */
export function Expandable({
  title,
  children,
  defaultOpen = false,
}: {
  title: string;
  children: ReactNode;
  defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <div className="rounded-md border border-hairline bg-card">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        className="flex w-full items-center justify-between gap-[var(--spacing-xs)] p-[var(--spacing-sm)] text-left"
      >
        <h2
          className="m-0"
          style={{ fontSize: "var(--text-heading-xl)" }}
        >
          {title}
        </h2>
        <span
          className="flex-none text-ink-tertiary"
          style={{
            fontSize: "var(--text-body-base)",
            transform: open ? "rotate(180deg)" : "rotate(0deg)",
            transition: "transform var(--duration-fast) var(--ease-brand)",
          }}
        >
          <ChevronDownIcon />
        </span>
      </button>
      {open ? (
        <div className="expand-enter px-[var(--spacing-sm)] pb-[var(--spacing-sm)]">
          {children}
        </div>
      ) : null}
    </div>
  );
}

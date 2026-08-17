import type { HTMLAttributes, ReactNode } from "react";

export function Card({
  label,
  children,
  className = "",
  ...rest
}: HTMLAttributes<HTMLDivElement> & { label?: string; children: ReactNode }) {
  return (
    <div
      className={`rounded-md border border-hairline bg-card p-[var(--spacing-sm)] ${className}`}
      {...rest}
    >
      {label ? <div className="eyebrow pb-[var(--spacing-2xs)]">{label}</div> : null}
      {children}
    </div>
  );
}

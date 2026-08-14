import type { ButtonHTMLAttributes } from "react";

type Variant = "primary" | "secondary" | "ghost";

const styles: Record<Variant, string> = {
  primary:
    "bg-action text-action-ink active:opacity-80 disabled:bg-ink-disabled disabled:text-card",
  secondary:
    "bg-transparent text-heading border border-hairline active:bg-card",
  ghost: "bg-transparent text-ink-secondary underline underline-offset-4",
};

export function Button({
  variant = "primary",
  className = "",
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
  return (
    <button
      className={`block w-full rounded-round px-[var(--spacing-md)] py-[var(--spacing-sm)] text-center transition-opacity ${styles[variant]} ${className}`}
      style={{ fontSize: "var(--text-label-button)" }}
      {...rest}
    />
  );
}

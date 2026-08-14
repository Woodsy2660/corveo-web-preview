import type { InputHTMLAttributes } from "react";

/**
 * Labelled input. Error copy is mechanical only (src/copy/validation.ts) —
 * never evaluative.
 */
export function Field({
  label,
  error,
  id,
  className = "",
  ...rest
}: InputHTMLAttributes<HTMLInputElement> & { label: string; error?: string }) {
  return (
    <label htmlFor={id} className={`block ${className}`}>
      <span
        className="block pb-[var(--spacing-3xs)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {label}
      </span>
      <input
        id={id}
        className={`w-full rounded-md border bg-card px-[var(--spacing-sm)] py-[var(--spacing-xs)] outline-none focus:border-heading ${
          error ? "border-heading" : "border-hairline"
        }`}
        {...rest}
      />
      {error ? (
        <span
          className="block pt-[var(--spacing-3xs)] text-ink-secondary"
          style={{ fontSize: "var(--text-body-sm)" }}
          role="alert"
        >
          {error}
        </span>
      ) : null}
    </label>
  );
}

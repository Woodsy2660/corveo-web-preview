import type { ReactNode } from "react";
import { CORVEO_WORDMARK } from "@/copy/product";
import logoUrl from "@/assets/brand/logo.svg";

/**
 * Page wrapper: safe-area padding, Corveo wordmark header with eyebrow
 * label, scrollable content column. Every screen renders inside one.
 */
export function Screen({
  eyebrow,
  title,
  children,
  footer,
  action,
  withTabBar = false,
}: {
  eyebrow?: string;
  title?: string;
  children: ReactNode;
  footer?: ReactNode;
  action?: ReactNode;
  withTabBar?: boolean;
}) {
  return (
    <div className="screen-shell" style={{ paddingTop: "var(--safe-top)" }}>
      <header className="flex items-center justify-between px-[var(--spacing-md)] pt-[var(--spacing-md)] pb-[var(--spacing-sm)]">
        {/* Brand logotype served from the shipped Corveo web app (brand/logo.svg) */}
        <img src={logoUrl} alt={CORVEO_WORDMARK} style={{ height: "18px", width: "auto" }} />
        <span className="flex items-baseline gap-[var(--spacing-sm)]">
          {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
          {action}
        </span>
      </header>

      <main
        className={`flex-1 overflow-y-auto px-[var(--spacing-md)] ${
          withTabBar ? "pb-[calc(96px+var(--safe-bottom))]" : "pb-[var(--spacing-md)]"
        }`}
      >
        {title ? (
          <h1
            className="fade-up pb-[var(--spacing-sm)]"
            style={{ fontSize: "var(--text-heading-3xl)", lineHeight: 1.15 }}
          >
            {title}
          </h1>
        ) : null}
        {children}
      </main>

      {footer ? (
        <footer
          className="px-[var(--spacing-md)] pt-[var(--spacing-xs)]"
          style={{ paddingBottom: "calc(var(--spacing-md) + var(--safe-bottom))" }}
        >
          {footer}
        </footer>
      ) : null}
    </div>
  );
}

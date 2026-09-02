import { useEffect, useRef, type ReactNode } from "react";
import { Link } from "react-router";
import { CORVEO_WORDMARK } from "@/copy/product";
import { APP } from "@/copy/app";
import { ProfileIcon } from "@/components/ui/icons";
import logoUrl from "@/assets/brand/logo.svg";

/**
 * Header affordance for the tab screens: profile and settings behind a
 * single icon, so the top of the app is the wordmark and nothing else.
 * Account, data export, deletion and the consent receipt all live behind it.
 */
export function ProfileLink() {
  return (
    <Link
      to="/app/settings"
      aria-label={APP.common.profileAria}
      title={APP.common.profileAria}
      /* 44px hit area for a 23px glyph; negative margin keeps the icon
         optically on the header edge rather than inset by the padding. */
      className="-my-[11px] -mr-[11px] flex size-[44px] items-center justify-center text-ink-tertiary"
      style={{ fontSize: "var(--text-body-lg)" }}
    >
      <ProfileIcon />
    </Link>
  );
}

/**
 * Page wrapper: safe-area padding, Corveo wordmark header with eyebrow
 * label, scrollable content column. Every screen renders inside one.
 */
export function Screen({
  eyebrow,
  overline,
  title,
  children,
  footer,
  action,
  scrollKey,
  withTabBar = false,
}: {
  eyebrow?: string;
  /**
   * Small label directly above the page title, the way the site sets a
   * chapter count or a content type over an article headline. Distinct from
   * `eyebrow`, which sits up in the header bar.
   */
  overline?: string;
  title?: string;
  children: ReactNode;
  footer?: ReactNode;
  action?: ReactNode;
  /**
   * Changes when the content swaps underneath a screen that stays mounted —
   * switching program, say. The scroll resets so the reader lands at the top
   * of what they just chose rather than partway down it.
   */
  scrollKey?: string;
  withTabBar?: boolean;
}) {
  const main = useRef<HTMLElement>(null);

  useEffect(() => {
    if (main.current) main.current.scrollTop = 0;
  }, [scrollKey]);

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
        ref={main}
        className={`flex-1 overflow-y-auto px-[var(--spacing-md)] ${
          withTabBar ? "pb-[calc(96px+var(--safe-bottom))]" : "pb-[var(--spacing-md)]"
        }`}
      >
        {overline ? <p className="eyebrow pb-[var(--spacing-3xs)]">{overline}</p> : null}
        {title ? (
          <h1
            className="fade-up pb-[var(--spacing-sm)]"
            style={{ fontSize: "var(--text-heading-2xl)", lineHeight: 1.15 }}
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

import { useEffect, useRef, type ReactNode } from "react";
import { Link, useLocation, useNavigate } from "react-router";
import { CORVEO_WORDMARK } from "@/copy/product";
import { APP } from "@/copy/app";
import { ProfileIcon } from "@/components/ui/icons";
import logoUrl from "@/assets/brand/logo.svg";

/**
 * Header affordance: profile and settings behind a single icon, so the top
 * of the app is the wordmark and nothing else. Account, data export,
 * deletion and the consent receipt all live behind it.
 *
 * It toggles. On any page it opens Settings; on Settings it is drawn
 * pressed and takes you back to where you came from, so the same spot in
 * the header opens and closes the one drawer the app has.
 */
export function ProfileLink() {
  const navigate = useNavigate();
  const location = useLocation();
  const onSettings = location.pathname === "/app/settings";
  // Where Settings was opened from, carried on the history entry so a trip
  // into a sub-page and back does not change where "close" lands.
  const openedFrom = (location.state as { from?: string } | null)?.from ?? "/app/record";
  const className = `-my-[11px] -mr-[11px] flex size-[44px] items-center justify-center ${
    onSettings ? "text-heading" : "text-ink-tertiary"
  }`;
  const style = { fontSize: "var(--text-body-lg)" };

  // 44px hit area for a 23px glyph; negative margin keeps the icon
  // optically on the header edge rather than inset by the padding.
  return onSettings ? (
    <button
      onClick={() => navigate(openedFrom)}
      aria-label={APP.common.profileCloseAria}
      title={APP.common.profileCloseAria}
      aria-pressed
      className={className}
      style={style}
    >
      <ProfileIcon />
    </button>
  ) : (
    <Link
      to="/app/settings"
      state={{ from: location.pathname }}
      aria-label={APP.common.profileAria}
      title={APP.common.profileAria}
      className={className}
      style={style}
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
  className = "",
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
  /** Extra classes on the shell, e.g. an entrance animation. */
  className?: string;
}) {
  const main = useRef<HTMLElement>(null);

  useEffect(() => {
    if (main.current) main.current.scrollTop = 0;
  }, [scrollKey]);

  return (
    <div className={`screen-shell ${className}`} style={{ paddingTop: "var(--safe-top)" }}>
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
          className="relative z-[15] bg-page px-[var(--spacing-md)] pt-[var(--spacing-xs)]"
          style={{
            paddingBottom: withTabBar
              ? "calc(96px + var(--safe-bottom))"
              : "calc(var(--spacing-md) + var(--safe-bottom))",
          }}
        >
          {footer}
        </footer>
      ) : null}
    </div>
  );
}

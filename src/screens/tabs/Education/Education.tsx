import { Link } from "react-router";
import { Screen, ProfileLink } from "@/components/ui/Screen";
import { ClockIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import {
  IN_FOCUS_ARTICLES,
  PULSE_ITEMS,
  type InFocusArticle,
  type PulseItem,
} from "@/copy/library-placeholder";

/**
 * Learn tab — the publication's two collections, in the app.
 *
 * The Pulse (short reads) is a horizontal rail of portrait cards; tapping one
 * opens the full-screen swipe-through viewer. In Focus (long reads) is a list
 * on the Program-tab idiom, opening the article reading template.
 *
 * CHANGE REQUEST: neither collection is in the sixteen deliverables — see
 * copy/library-placeholder.ts. Built for IA review, pending Corveo's
 * decision and a content pipeline (CMS feed vs. bundled).
 *
 * The safety surface (Deliverable 12) and validated-monitor list
 * (Deliverable 8) moved back to Settings — this tab is the publication only.
 * The Stage 2 and Stage 3 test scripts reference their location and need
 * updating with the move.
 */

/** The three Userkind accent surfaces, cycled across the rail. Decorative only. */
const RAIL_SURFACES = ["bg-accent-1", "bg-accent-3", "bg-accent-2"] as const;

function PulseCard({ item, index }: { item: PulseItem; index: number }) {
  const c = APP.education;
  return (
    <Link
      to={`/app/education/pulse/${item.slug}`}
      aria-label={c.openPulseAria(item.title)}
      className={`flex h-[152px] w-[112px] flex-none flex-col justify-end rounded-md p-[var(--spacing-xs)] ${
        RAIL_SURFACES[index % RAIL_SURFACES.length]
      }`}
    >
      <span
        style={{
          fontFamily: "var(--font-display)",
          fontSize: "var(--text-body-base)",
          lineHeight: "var(--leading-heading)",
          letterSpacing: "-0.02em",
          color: "var(--color-text-heading-inverse)",
        }}
      >
        {item.title}
      </span>
    </Link>
  );
}

/**
 * One long read, on the Program-tab row idiom: the whole row is the tap
 * target. Article artwork is a Corveo asset that has not been supplied, so
 * the tile is a placeholder that spans the row's height.
 */
function InFocusRow({ article }: { article: InFocusArticle }) {
  return (
    <li className="border-b border-hairline last:border-b-0">
      <Link
        to={`/app/education/in-focus/${article.slug}`}
        className="flex gap-[var(--spacing-xs)] py-[var(--spacing-sm)]"
      >
        <div
          aria-hidden
          className="w-[96px] flex-none self-stretch rounded-sm"
          style={{ background: "var(--color-surface-neutral-lighter)" }}
        />
        <div className="flex min-w-0 flex-1 flex-col gap-[var(--spacing-3xs)]">
          <h2 style={{ fontSize: "var(--text-heading-xl)" }}>{article.title}</h2>
          <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
            {article.excerpt}
          </p>
          <span
            className="flex items-center gap-[var(--spacing-3xs)] text-ink-tertiary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            <ClockIcon />
            {APP.program.duration(article.readMinutes, "read")}
          </span>
        </div>
      </Link>
    </li>
  );
}

export function Education() {
  const c = APP.education;

  return (
    <Screen title={c.title} withTabBar action={<ProfileLink />}>
      <p
        className="pb-[var(--spacing-md)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {c.intro}
      </p>

      <section aria-label={c.pulseHeading}>
        <div className="flex items-baseline gap-[var(--spacing-2xs)] pb-[var(--spacing-2xs)]">
          <h2 style={{ fontSize: "var(--text-heading-xl)" }}>{c.pulseHeading}</h2>
          <span className="eyebrow">{c.pulseSub}</span>
        </div>
        {/* Full-bleed rail: escapes the screen padding so cards run to the edge. */}
        <div className="no-scrollbar -mx-[var(--spacing-md)] flex gap-[var(--spacing-2xs)] overflow-x-auto px-[var(--spacing-md)] pb-[var(--spacing-md)]">
          {PULSE_ITEMS.map((item, i) => (
            <PulseCard key={item.slug} item={item} index={i} />
          ))}
        </div>
      </section>

      <section aria-label={c.inFocusHeading}>
        <div className="flex items-baseline gap-[var(--spacing-2xs)]">
          <h2 style={{ fontSize: "var(--text-heading-xl)" }}>{c.inFocusHeading}</h2>
          <span className="eyebrow">{c.inFocusSub}</span>
        </div>
        <ul className="flex list-none flex-col p-0">
          {IN_FOCUS_ARTICLES.map((article) => (
            <InFocusRow key={article.slug} article={article} />
          ))}
        </ul>
      </section>

      <p
        className="pt-[var(--spacing-md)] text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {c.scopeNote}
      </p>
    </Screen>
  );
}

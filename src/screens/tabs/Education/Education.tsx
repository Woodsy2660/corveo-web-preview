import { Link } from "react-router";
import { Screen, ProfileLink } from "@/components/ui/Screen";
import { ClockIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import { ARTICLE_ART, PULSE_ART } from "@/assets/photos";
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

/**
 * A Pulse card: a photograph with the title over it. One even scrim, no
 * gradient, keeps the white serif legible on any picture.
 */
function PulseCard({ item, index }: { item: PulseItem; index: number }) {
  const c = APP.education;
  return (
    <Link
      to={`/app/education/pulse/${item.slug}`}
      aria-label={c.openPulseAria(item.title)}
      className="card-enter relative flex h-[152px] w-[112px] flex-none flex-col justify-end overflow-hidden rounded-md p-[var(--spacing-xs)]"
      style={{ "--stagger-index": Math.min(index, 4) } as React.CSSProperties}
    >
      <img
        src={PULSE_ART[item.slug]}
        alt=""
        aria-hidden
        className="absolute inset-0 h-full w-full object-cover"
      />
      <span aria-hidden className="absolute inset-0" style={{ background: "rgba(0, 0, 0, 0.55)" }} />
      <span
        className="relative"
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
 * One long read, on the chapter-row pattern: every row the same height,
 * photograph left, title and excerpt at the top, the read time as a quiet
 * line at the bottom. The whole row is the tap target. Article artwork is
 * a Corveo asset that has not been supplied; a placeholder photograph
 * stands in.
 */
function InFocusRow({ article, index }: { article: InFocusArticle; index: number }) {
  return (
    <li className="card-enter border-b border-hairline last:border-b-0" style={{ "--stagger-index": Math.min(index, 4) } as React.CSSProperties}>
      <Link
        to={`/app/education/in-focus/${article.slug}`}
        className="flex h-[112px] gap-[var(--spacing-xs)] py-[var(--spacing-xs)]"
      >
        <img
          src={ARTICLE_ART[article.slug]}
          alt=""
          aria-hidden
          className="h-full w-[66px] flex-none rounded-sm object-cover"
        />
        <div className="flex min-w-0 flex-1 flex-col justify-between">
          <div className="min-w-0">
            {/* Article titles run longer than chapter titles: two lines for
                the title, one for the excerpt, same row height. */}
            <h2
              className="line-clamp-2"
              style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-heading)" }}
            >
              {article.title}
            </h2>
            <p
              className="line-clamp-1 text-ink-secondary"
              style={{ fontSize: "var(--text-body-sm)" }}
            >
              {article.excerpt}
            </p>
          </div>
          <span
            className="flex items-center gap-[var(--spacing-3xs)] text-ink-tertiary"
            style={{ fontSize: "var(--text-label)", lineHeight: "var(--leading-label)" }}
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
          {IN_FOCUS_ARTICLES.map((article, i) => (
            <InFocusRow key={article.slug} article={article} index={i} />
          ))}
        </ul>
      </section>

    </Screen>
  );
}

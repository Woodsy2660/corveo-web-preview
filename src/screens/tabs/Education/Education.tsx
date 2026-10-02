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
 * Learn tab — the publication's two collections.
 *
 * Pulse cards show a card summary when one is supplied (CORV-EDU-002);
 * without a summary they stay title-led. In Focus still has no bodies.
 */

function PulseCard({ item, index }: { item: PulseItem; index: number }) {
  const c = APP.education;
  const hasSummary = Boolean(item.excerpt);
  return (
    <Link
      to={`/app/education/pulse/${item.slug}`}
      aria-label={c.openPulseAria(item.title)}
      className={`card-enter relative flex w-[148px] flex-none flex-col justify-end overflow-hidden rounded-md p-[var(--spacing-xs)] ${
        hasSummary ? "h-[196px]" : "h-[152px]"
      }`}
      style={{ "--stagger-index": Math.min(index, 4) } as React.CSSProperties}
    >
      <img
        src={PULSE_ART[item.slug] ?? ""}
        alt=""
        aria-hidden
        className="absolute inset-0 h-full w-full object-cover"
      />
      <span aria-hidden className="absolute inset-0" style={{ background: "rgba(0, 0, 0, 0.55)" }} />
      <span className="relative flex flex-col gap-[var(--spacing-3xs)]">
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
        {hasSummary ? (
          <span
            className="line-clamp-3"
            style={{
              fontFamily: "var(--font-body)",
              fontSize: "var(--text-label)",
              lineHeight: "var(--leading-label)",
              color: "var(--color-text-secondary-inverse)",
            }}
          >
            {item.excerpt}
          </span>
        ) : null}
      </span>
    </Link>
  );
}

function InFocusRow({ article, index }: { article: InFocusArticle; index: number }) {
  return (
    <li className="card-enter border-b border-hairline last:border-b-0" style={{ "--stagger-index": Math.min(index, 4) } as React.CSSProperties}>
      <Link
        to={`/app/education/in-focus/${article.slug}`}
        className="flex h-[112px] gap-[var(--spacing-xs)] py-[var(--spacing-xs)]"
      >
        <img
          src={ARTICLE_ART[article.slug] ?? ""}
          alt=""
          aria-hidden
          className="h-full w-[66px] flex-none rounded-sm object-cover"
        />
        <div className="flex min-w-0 flex-1 flex-col justify-between">
          <div className="min-w-0">
            <h2
              className="line-clamp-2"
              style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-heading)" }}
            >
              {article.title}
            </h2>
            {article.excerpt ? (
              <p
                className="line-clamp-1 text-ink-secondary"
                style={{ fontSize: "var(--text-body-sm)" }}
              >
                {article.excerpt}
              </p>
            ) : null}
          </div>
          {article.displayReadingTime ? (
            <span
              className="flex items-center gap-[var(--spacing-3xs)] text-ink-tertiary"
              style={{ fontSize: "var(--text-label)", lineHeight: "var(--leading-label)" }}
            >
              <ClockIcon />
              {APP.program.duration(article.readMinutes, "read")}
            </span>
          ) : null}
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

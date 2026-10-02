import { useEffect, useRef, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { APP } from "@/copy/app";
import { PULSE_ITEMS, findPulseItem } from "@/copy/library-placeholder";

/**
 * Pulse article reader. Body copy is CORV-EDU-002, rendered verbatim.
 * Navigation matches Your program: Next read / Back fade in at the bottom
 * in the last quarter of the page. No CTA back into the Program.
 */
export function PulseViewer() {
  const { slug } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  const item = findPulseItem(slug);
  const c = APP.pulse;
  const inJourney = location.pathname.startsWith("/journey");
  const listRoot = inJourney ? "/journey/pulse" : "/app/education/pulse";

  const [fade, setFade] = useState(0);
  const endRef = useRef<HTMLDivElement>(null);

  const index = item ? PULSE_ITEMS.findIndex((p) => p.slug === item.slug) : -1;
  const next = index >= 0 ? PULSE_ITEMS[index + 1] : undefined;

  useEffect(() => {
    setFade(0);
  }, [slug]);

  useEffect(() => {
    if (!endRef.current) return;
    const root = endRef.current.closest("main");
    if (!(root instanceof HTMLElement)) return;

    const onScroll = () => {
      const max = root.scrollHeight - root.clientHeight;
      if (max <= 0) {
        setFade(1);
        return;
      }
      const progress = root.scrollTop / max;
      setFade(Math.min(1, Math.max(0, (progress - 0.75) / 0.25)));
    };
    onScroll();
    root.addEventListener("scroll", onScroll, { passive: true });
    return () => root.removeEventListener("scroll", onScroll);
  }, [slug]);

  if (!item) {
    return (
      <Screen title={APP.education.pulseHeading}>
        <Button onClick={() => (inJourney ? navigate(-1) : navigate("/app/education"))}>{APP.inFocus.back}</Button>
      </Screen>
    );
  }

  const paragraphs = item.body;
  const goBack = () => (inJourney ? navigate(-1) : navigate("/app/education"));

  const actions = (
    <div className="flex flex-col gap-[var(--spacing-2xs)]">
      {next ? (
        <Button onClick={() => navigate(`${listRoot}/${next.slug}`)}>{c.next}</Button>
      ) : (
        <Button onClick={goBack}>{APP.inFocus.back}</Button>
      )}
      {next ? (
        <Button variant="ghost" onClick={goBack}>
          {APP.common.back}
        </Button>
      ) : null}
    </div>
  );

  return (
    <>
      <Screen
        overline={c.overline}
        title={item.title}
        className="step-enter"
        scrollKey={item.slug}
      >
        {item.standfirst ? (
          <p
            className="pb-[var(--spacing-sm)]"
            style={{
              fontSize: "var(--text-body-lg)",
              lineHeight: "var(--leading-body-relaxed)",
            }}
          >
            {item.standfirst}
          </p>
        ) : null}

        {paragraphs && paragraphs.length > 0 ? (
          <article className="flex flex-col gap-[var(--spacing-sm)]">
            {paragraphs.map((paragraph) => (
              <p
                key={paragraph.slice(0, 48)}
                style={{
                  fontSize: "var(--text-body-lg)",
                  lineHeight: "var(--leading-body-relaxed)",
                  color: "var(--app-ink)",
                }}
              >
                {paragraph}
              </p>
            ))}
          </article>
        ) : (
          <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-lg)" }}>
            {item.emptyReaderMessage}
          </p>
        )}

        {item.keyTakeaway ? (
          <div className="mt-[var(--spacing-md)] border-t border-hairline pt-[var(--spacing-sm)]">
            <p className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}>
              {APP.chapter.keyTakeaway}
            </p>
            <p
              className="pt-[var(--spacing-2xs)]"
              style={{
                fontSize: "var(--text-body-lg)",
                lineHeight: "var(--leading-body-relaxed)",
              }}
            >
              {item.keyTakeaway}
            </p>
          </div>
        ) : null}

        {item.byline ? (
          <p
            className="mt-[var(--spacing-md)] border-t border-hairline pt-[var(--spacing-sm)] text-ink-secondary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {item.byline}
            {item.bylineStatus ? ` · ${item.bylineStatus}` : null}
          </p>
        ) : null}

        {item.sharedFooter ? (
          <p
            className="mt-[var(--spacing-sm)] text-ink-tertiary"
            style={{ fontSize: "var(--text-body-sm)", lineHeight: "var(--leading-body)" }}
          >
            {item.sharedFooter}
          </p>
        ) : null}

        <div ref={endRef} aria-hidden />
        <div aria-hidden className="h-[7.5rem]" />
      </Screen>
      {fade > 0 ? (
        <div
          className="fixed inset-x-0 bottom-0 z-[15] bg-page px-[var(--spacing-md)] pt-[var(--spacing-xs)]"
          style={{
            paddingBottom: "calc(var(--spacing-md) + var(--safe-bottom))",
            opacity: fade,
            pointerEvents: fade > 0.2 ? "auto" : "none",
            transition: "opacity var(--duration-slow) var(--ease-brand)",
          }}
        >
          {actions}
        </div>
      ) : null}
    </>
  );
}

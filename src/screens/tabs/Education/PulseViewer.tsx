import { useLayoutEffect, useRef, useState } from "react";
import { Navigate, useNavigate, useParams } from "react-router";
import { ChevronUpIcon, CloseIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import { SAFETY } from "@/copy/safety";
import { PULSE_ITEMS, type PulseItem } from "@/copy/library-placeholder";

/**
 * The Pulse — full-screen swipe-through viewer for the short reads.
 *
 * One read per screen, swiped vertically, on the model of short-form video
 * feeds: the page is a scroll-snap container and each read is one snap stop.
 * Native momentum scrolling does the gesture work; no gesture library.
 *
 * Deliberately a destination you enter from the Learn rail, not the tab
 * itself — the tab stays a calm library and this is the immersive mode.
 * Close returns to the rail.
 *
 * `position: fixed` anchors to #root on the desktop preview (the frame sets
 * a transform, making it the containing block), so the viewer fills the
 * phone frame there and the real viewport on device.
 *
 * Content register: each read is display-only education. The education
 * disclaimer travels on every screen, exactly as it does at the foot of a
 * chapter — the format invites punchy copy, which is exactly where the
 * IPS discipline matters most.
 */

function PulseSlide({ item }: { item: PulseItem }) {
  const pending = !item.body;

  return (
    <section
      className="flex h-full w-full snap-start flex-col justify-between px-[var(--spacing-md)]"
      style={{
        paddingTop: "calc(var(--safe-top) + 72px)",
        paddingBottom: "calc(var(--safe-bottom) + 64px)",
      }}
      aria-label={item.title}
    >
      <div className="flex flex-1 flex-col justify-center gap-[var(--spacing-sm)]">
        <h2
          style={{
            fontFamily: "var(--font-display)",
            fontWeight: 400,
            fontSize: "var(--text-heading-2xl)",
            lineHeight: "var(--leading-heading)",
            letterSpacing: "-0.02em",
            color: "var(--color-text-heading-inverse)",
          }}
        >
          {item.title}
        </h2>

        {(item.body ?? [APP.pulse.pendingBody]).map((paragraph) => (
          <p
            key={paragraph.slice(0, 32)}
            style={{
              fontSize: "var(--text-body-lg)",
              lineHeight: "var(--leading-body-relaxed)",
              color: pending
                ? "var(--color-text-tertiary)"
                : "var(--color-text-secondary-inverse)",
            }}
          >
            {paragraph}
          </p>
        ))}
      </div>

      <p style={{ fontSize: "var(--text-label)", color: "var(--color-text-tertiary)" }}>
        {SAFETY.educationNote}
      </p>
    </section>
  );
}

export function PulseViewer() {
  const { slug } = useParams();
  const navigate = useNavigate();
  const containerRef = useRef<HTMLDivElement>(null);
  const startIndex = PULSE_ITEMS.findIndex((p) => p.slug === slug);
  const [index, setIndex] = useState(Math.max(startIndex, 0));
  const c = APP.pulse;

  // Jump (not smooth-scroll) to the tapped read before first paint. If the
  // container has no height yet (layout not settled), wait for it — a jump
  // computed against zero height silently lands on slide one.
  useLayoutEffect(() => {
    const el = containerRef.current;
    if (!el || startIndex <= 0) return;
    if (el.clientHeight > 0) {
      el.scrollTop = startIndex * el.clientHeight;
      return;
    }
    const ro = new ResizeObserver(() => {
      if (el.clientHeight > 0) {
        el.scrollTop = startIndex * el.clientHeight;
        ro.disconnect();
      }
    });
    ro.observe(el);
    return () => ro.disconnect();
    // Run once on mount only — later scrollTop changes are the user's swipes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (startIndex === -1) return <Navigate to="/app/education" replace />;

  const onScroll = () => {
    const el = containerRef.current;
    if (!el || el.clientHeight === 0) return;
    setIndex(Math.round(el.scrollTop / el.clientHeight));
  };

  return (
    <div className="fixed inset-0 z-20 bg-action">
      <div
        className="absolute inset-x-0 z-10 flex items-center justify-between px-[var(--spacing-md)]"
        style={{ top: "calc(var(--safe-top) + var(--spacing-sm))" }}
      >
        <span className="eyebrow" style={{ color: "var(--color-text-secondary-inverse)" }}>
          {`${APP.education.pulseHeading} · ${c.counter(index + 1, PULSE_ITEMS.length)}`}
        </span>
        <button
          type="button"
          aria-label={c.closeAria}
          onClick={() => navigate("/app/education")}
          className="flex size-[44px] items-center justify-center text-action-ink"
          style={{ fontSize: "var(--text-body-lg)" }}
        >
          <CloseIcon />
        </button>
      </div>

      <div
        ref={containerRef}
        onScroll={onScroll}
        className="h-full snap-y snap-mandatory overflow-y-auto overscroll-contain"
      >
        {PULSE_ITEMS.map((item) => (
          <PulseSlide key={item.slug} item={item} />
        ))}
      </div>

      {index < PULSE_ITEMS.length - 1 ? (
        <div
          aria-hidden
          className="pointer-events-none absolute inset-x-0 flex flex-col items-center gap-[var(--spacing-3xs)]"
          style={{
            bottom: "calc(var(--safe-bottom) + var(--spacing-sm))",
            color: "var(--color-text-tertiary)",
          }}
        >
          <ChevronUpIcon />
          <span style={{ fontSize: "var(--text-label)" }}>{c.swipeHint}</span>
        </div>
      ) : null}
    </div>
  );
}

import { useCallback, useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { useLocation, useNavigate } from "react-router";
import { BEHIND } from "@/copy/behind";
import { Visual } from "./Visual";

/**
 * A presentation, not a screen.
 *
 * It portals to <body> deliberately: the app previews inside a 393px phone
 * frame on desktop, and this is the one thing meant to be shown on a wall.
 * Escaping the frame is the difference between a demo and a slide.
 *
 * Set in the system typeface rather than Corveo's, because this section is
 * about the machinery underneath the product rather than the product itself.
 *
 * Every colour is declared inline. app.css styles `h2` inside `@layer base`
 * with `color: var(--app-heading)` — which is black — and that rule reaches
 * anything portalled to <body> too. Inheriting here would put black type on
 * a black ground.
 */

const INK = {
  ground: "#000000",
  ink: "#F5F5F7",
  ink2: "rgba(235,235,245,0.66)",
  /* Measured over black: 0.34 gave 2.61:1, which fails the 4.5:1 floor for
     text this size and vanishes entirely on a projector. 0.55 measures
     5.8:1 and still reads as clearly secondary. */
  ink3: "rgba(235,235,245,0.55)",
  ink4: "rgba(235,235,245,0.28)",
  indigo: "#7C8CF8",
  font: '-apple-system, "SF Pro Display", "SF Pro Text", system-ui, "Segoe UI", Roboto, sans-serif',
  ease: "cubic-bezier(0.22, 1, 0.36, 1)",
} as const;

/** The key light behind the object, per scene. Low saturation, low opacity. */
const TINT: Record<string, string> = {
  intro: "rgba(124,140,248,0.13)",
  health: "rgba(124,140,248,0.12)",
  read: "rgba(124,140,248,0.13)",
  wake: "rgba(79,209,230,0.11)",
  hold: "rgba(124,140,248,0.12)",
  once: "rgba(124,140,248,0.10)",
  plain: "rgba(235,235,245,0.06)",
  end: "rgba(79,209,230,0.12)",
};

/** 2.5% grain — the difference between "black" and "photographed black". */
const GRAIN =
  "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='3'/%3E%3C/filter%3E%3Crect width='160' height='160' filter='url(%23n)' opacity='0.5'/%3E%3C/svg%3E\")";

/** -1 is the title card; beats.length is the closing card. */
type Step = number;

export function BehindTheScenes() {
  const navigate = useNavigate();
  const location = useLocation();
  const [step, setStep] = useState<Step>(-1);
  const total = BEHIND.beats.length;

  /**
   * Going back is right when this was opened from Settings. On a direct hit
   * — a bookmarked link, or the URL typed during a walkthrough — there is
   * nothing behind it, and `navigate(-1)` would leave the app entirely.
   */
  const close = useCallback(() => {
    if (location.key === "default") navigate("/app/record", { replace: true });
    else navigate(-1);
  }, [location.key, navigate]);

  const next = useCallback(() => setStep((s) => Math.min(s + 1, total)), [total]);
  const prev = useCallback(() => setStep((s) => Math.max(s - 1, -1)), []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") close();
      else if (e.key === "ArrowRight" || e.key === " ") {
        e.preventDefault();
        next();
      } else if (e.key === "ArrowLeft") prev();
    };
    window.addEventListener("keydown", onKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = prevOverflow;
    };
  }, [close, next, prev]);

  const beat = step >= 0 && step < total ? BEHIND.beats[step] : null;
  const atEnd = step === total;
  const sceneId = beat ? beat.id : step < 0 ? "intro" : "end";

  const title = beat ? beat.title : step < 0 ? BEHIND.intro.title : BEHIND.end.title;
  const sub = beat ? beat.sub : step < 0 ? BEHIND.intro.sub : BEHIND.end.sub;
  /** The mechanism, for anyone who wants it. Skippable by design. */
  const note: string | null = beat ? beat.note : step < 0 ? null : BEHIND.end.note;

  return createPortal(
    <div
      role="dialog"
      aria-modal="true"
      aria-label={BEHIND.intro.eyebrow}
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 100,
        background: INK.ground,
        color: INK.ink,
        fontFamily: INK.font,
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
        WebkitFontSmoothing: "antialiased",
      }}
    >
      {/* Key light — one soft source, repositioned and retinted per scene. */}
      <div
        aria-hidden="true"
        style={{
          position: "absolute",
          inset: 0,
          background: `radial-gradient(46% 38% at 50% 38%, ${TINT[sceneId] ?? TINT.intro} 0%, transparent 72%)`,
          transition: `background 1100ms ${INK.ease}`,
          pointerEvents: "none",
        }}
      />
      {/* Vignette, so the frame edges fall away rather than ending. */}
      <div
        aria-hidden="true"
        style={{
          position: "absolute",
          inset: 0,
          background: "radial-gradient(120% 90% at 50% 45%, transparent 40%, rgba(0,0,0,0.85) 100%)",
          pointerEvents: "none",
        }}
      />
      <div
        aria-hidden="true"
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage: GRAIN,
          opacity: 0.025,
          mixBlendMode: "overlay",
          pointerEvents: "none",
        }}
      />

      <header
        style={{
          position: "relative",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "26px clamp(20px, 3vw, 40px)",
          flex: "0 0 auto",
        }}
      >
        <span
          style={{
            fontSize: 11,
            fontWeight: 500,
            letterSpacing: "0.16em",
            textTransform: "uppercase",
            color: INK.ink3,
          }}
        >
          {BEHIND.intro.eyebrow}
        </span>
        <button
          onClick={close}
          aria-label={BEHIND.close}
          style={{
            width: 48,
            height: 48,
            borderRadius: "50%",
            border: "none",
            background: "rgba(235,235,245,0.08)",
            color: INK.ink2,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            cursor: "pointer",
            transition: `background 200ms ${INK.ease}`,
          }}
        >
          <svg width="13" height="13" viewBox="0 0 14 14" aria-hidden="true">
            <path
              d="M1 1 L13 13 M13 1 L1 13"
              stroke="currentColor"
              strokeWidth="1.6"
              strokeLinecap="round"
            />
          </svg>
        </button>
      </header>

      <main
        onClick={() => (atEnd ? close() : next())}
        style={{
          position: "relative",
          flex: 1,
          minHeight: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: "clamp(22px, 4.6vh, 58px)",
          padding: "0 clamp(24px, 5vw, 72px)",
          cursor: "pointer",
          textAlign: "center",
        }}
      >
        <div
          key={`v-${step}`}
          style={{
            height: "clamp(232px, 40vh, 430px)",
            /*
             * The text takes the room it needs and the artwork absorbs what
             * is left. Without this the visual holds its full height and the
             * note gets clipped off the bottom on a 720p projector — six of
             * the eight steps did exactly that.
             */
            flex: "0 1 auto",
            minHeight: 0,
            width: "100%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            animation: `bts-rise 820ms ${INK.ease} both`,
          }}
        >
          <Visual id={sceneId} />
        </div>

        <div
          key={`t-${step}`}
          style={{
            animation: `bts-rise 820ms 110ms ${INK.ease} both`,
            maxWidth: 900,
            flex: "0 0 auto",
          }}
        >
          <h2
            style={{
              margin: 0,
              color: INK.ink,
              fontFamily: INK.font,
              fontSize: "clamp(29px, 4.4vw, 66px)",
              lineHeight: 1.03,
              letterSpacing: "-0.035em",
              fontWeight: 600,
              maxWidth: "16ch",
              textWrap: "balance",
              marginInline: "auto",
            }}
          >
            {title}
          </h2>
          <p
            style={{
              margin: "clamp(16px, 2.2vh, 26px) auto 0",
              color: INK.ink2,
              fontSize: "clamp(15px, 1.35vw, 20px)",
              lineHeight: 1.5,
              letterSpacing: "-0.008em",
              maxWidth: "46ch",
            }}
          >
            {sub}
          </p>
          {note ? (
            <p
              style={{
                margin: "clamp(13px, 1.7vh, 20px) auto 0",
                color: INK.ink3,
                fontSize: "clamp(12px, 0.95vw, 14px)",
                lineHeight: 1.45,
                letterSpacing: "0.005em",
                maxWidth: "52ch",
              }}
            >
              {note}
            </p>
          ) : null}
        </div>
      </main>

      <footer
        style={{
          position: "relative",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          gap: 20,
          padding: "18px clamp(20px, 3vw, 40px) calc(26px + env(safe-area-inset-bottom, 0px))",
          flex: "0 0 auto",
        }}
      >
        <button
          onClick={prev}
          disabled={step === -1}
          style={{
            background: "none",
            border: "none",
            color: INK.ink3,
            fontSize: 14.5,
            padding: 0,
            minWidth: 92,
            textAlign: "left",
            cursor: step === -1 ? "default" : "pointer",
            opacity: step === -1 ? 0 : 1,
            transition: `opacity 260ms ${INK.ease}`,
          }}
        >
          {BEHIND.back}
        </button>

        <div style={{ display: "flex", alignItems: "center", gap: 6 }} aria-hidden="true">
          {BEHIND.beats.map((b, i) => (
            <span
              key={b.id}
              style={{
                width: i === step ? 20 : 5,
                height: 5,
                borderRadius: 5,
                background: i === step ? INK.indigo : i < step ? INK.ink4 : "rgba(235,235,245,0.12)",
                transition: `all 480ms ${INK.ease}`,
              }}
            />
          ))}
        </div>

        <div style={{ minWidth: 92, display: "flex", justifyContent: "flex-end" }}>
          <button
            onClick={() => (atEnd ? close() : next())}
            style={{
              background: INK.ink,
              border: "none",
              color: INK.ground,
              fontSize: 14.5,
              fontWeight: 500,
              letterSpacing: "-0.01em",
              padding: "11px 22px",
              borderRadius: 980,
              cursor: "pointer",
              transition: `transform 200ms ${INK.ease}, opacity 200ms ${INK.ease}`,
            }}
          >
            {step === -1 ? BEHIND.intro.start : atEnd ? BEHIND.end.done : BEHIND.next}
          </button>
        </div>
      </footer>

      <style>{`
        @keyframes bts-rise {
          from { opacity: 0; transform: translateY(18px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        @keyframes bts-breathe {
          0%, 100% { transform: scale(1);    opacity: 0.92; }
          50%      { transform: scale(1.035); opacity: 1; }
        }
        @keyframes bts-ripple {
          0%   { transform: scale(1);    opacity: 0; }
          18%  { opacity: 0.5; }
          100% { transform: scale(1.22); opacity: 0; }
        }
        @keyframes bts-draw {
          from { stroke-dashoffset: var(--len); }
          to   { stroke-dashoffset: 0; }
        }
        @media (prefers-reduced-motion: reduce) {
          [style*="bts-rise"], [style*="bts-breathe"],
          [style*="bts-ripple"], [style*="bts-draw"] {
            animation: none !important;
          }
        }
      `}</style>
    </div>,
    document.body,
  );
}

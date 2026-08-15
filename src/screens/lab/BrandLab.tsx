import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";

/**
 * BRAND LAB — internal design exploration, not a product surface.
 *
 * Motion and iconography concepts derived from the corveo logotype: the 'o'
 * emerging from the C's mouth like a droplet. Everything here is monochrome
 * ink and calm by design — no evaluative colour, nothing value-triggered
 * (SOW A.3.3 applies to explorations too). Honours prefers-reduced-motion.
 *
 * Route: /lab (unlinked). Remove before App Store submission.
 */

/** The C of the logotype as an explicit arc, mouth facing right. */
function CArc({ cx, cy, r, sw }: { cx: number; cy: number; r: number; sw: number }) {
  const a = (40 * Math.PI) / 180;
  const x = cx + r * Math.cos(a);
  const y1 = cy + r * Math.sin(a);
  const y2 = cy - r * Math.sin(a);
  return (
    <path
      d={`M ${x} ${y1} A ${r} ${r} 0 1 1 ${x} ${y2}`}
      fill="none"
      stroke="var(--app-heading)"
      strokeWidth={sw}
      strokeLinecap="round"
    />
  );
}

/** Concept 1 — the droplet emergence: o buds from the C, detaches, settles. */
function DropletMark() {
  return (
    <svg viewBox="0 0 220 120" className="w-full" role="img" aria-label="Animated Corveo mark: the o emerging from the C like a droplet">
      <CArc cx={52} cy={60} r={30} sw={9} />
      {/* liquid phase — a filled droplet budding from the C's mouth */}
      <circle className="lab-droplet" cx="0" cy="0" r="15" fill="var(--app-heading)" />
      {/* letterform phase — the droplet resolves into the stroked o */}
      <circle
        className="lab-o-settle"
        cx="142"
        cy="60"
        r="25"
        fill="none"
        stroke="var(--app-heading)"
        strokeWidth="9"
      />
    </svg>
  );
}

/** Concept 2 — droplet loader: small, looping, for waits and syncs. */
function DropletLoader() {
  return (
    <svg viewBox="0 0 88 44" width="88" height="44" role="img" aria-label="Loading indicator concept">
      <CArc cx={20} cy={22} r={11} sw={4} />
      <circle className="lab-loader-drop" cx="0" cy="0" r="5.5" fill="var(--app-heading)" />
      <circle className="lab-loader-o" cx="56" cy="22" r="9" fill="none" stroke="var(--app-heading)" strokeWidth="4" />
    </svg>
  );
}

/** Concept 3 — breathing ring: a calm "measuring / syncing" state. */
function BreathingRing() {
  return (
    <svg viewBox="0 0 64 64" width="64" height="64" role="img" aria-label="Breathing ring concept">
      <circle className="lab-breathe" cx="32" cy="32" r="20" fill="none" stroke="var(--app-heading)" strokeWidth="6" />
    </svg>
  );
}

/** Concept 4 — journey dots as droplets: the active step swells. */
function DropletDots() {
  return (
    <div className="flex items-center gap-[var(--spacing-2xs)]" aria-label="Step indicator concept">
      {[0, 1, 2, 3, 4].map((i) => (
        <span key={i} className="lab-dot" style={{ animationDelay: `${i * 1.2}s` }} />
      ))}
    </div>
  );
}

const STROKE = {
  fill: "none",
  stroke: "var(--app-heading)",
  strokeWidth: 2,
  strokeLinecap: "round" as const,
};

/** Derived icon set — every glyph built from the ring / gap / droplet vocabulary. */
const ICONS: { name: string; note: string; svg: React.ReactNode }[] = [
  {
    name: "Readings",
    note: "the pair — one reading, two numbers",
    svg: (
      <svg viewBox="0 0 28 28" width="28" height="28">
        <circle cx="11" cy="11" r="6.5" {...STROKE} />
        <circle cx="19" cy="20" r="4" fill="var(--app-heading)" />
      </svg>
    ),
  },
  {
    name: "Trend",
    note: "the o with its history trailing behind",
    svg: (
      <svg viewBox="0 0 28 28" width="28" height="28">
        <circle cx="21" cy="9" r="4.5" {...STROKE} />
        <path d="M3 23 C 8 21, 10 17, 16 14" {...STROKE} strokeDasharray="0.1 4.5" />
      </svg>
    ),
  },
  {
    name: "Program",
    note: "six weeks, the current one filled",
    svg: (
      <svg viewBox="0 0 28 28" width="28" height="28">
        {[0, 1, 2, 3, 4, 5].map((i) => {
          const a = (i / 6) * Math.PI * 2 - Math.PI / 2;
          const x = 14 + 9 * Math.cos(a);
          const y = 14 + 9 * Math.sin(a);
          return i === 0 ? (
            <circle key={i} cx={x} cy={y} r="3" fill="var(--app-heading)" />
          ) : (
            <circle key={i} cx={x} cy={y} r="2.2" {...STROKE} strokeWidth={1.6} />
          );
        })}
      </svg>
    ),
  },
  {
    name: "Add",
    note: "a new drop for the record",
    svg: (
      <svg viewBox="0 0 28 28" width="28" height="28">
        <circle cx="14" cy="14" r="9.5" {...STROKE} />
        <path d="M14 10 v8 M10 14 h8" {...STROKE} />
      </svg>
    ),
  },
  {
    name: "Export",
    note: "the record leaves through the C's mouth",
    svg: (
      <svg viewBox="0 0 28 28" width="28" height="28">
        <path d="M20.3 19.5 A 9 9 0 1 1 20.3 8.5" {...STROKE} />
        <path d="M15 14 h10 M21.5 10.5 L 25 14 l-3.5 3.5" {...STROKE} />
      </svg>
    ),
  },
  {
    name: "Connect",
    note: "two rings meeting — the logotype's own oo",
    svg: (
      <svg viewBox="0 0 28 28" width="28" height="28">
        <circle cx="10.5" cy="14" r="6.5" {...STROKE} />
        <circle cx="18.5" cy="14" r="6.5" {...STROKE} />
      </svg>
    ),
  },
  {
    name: "Settings",
    note: "a dial in the brand geometry",
    svg: (
      <svg viewBox="0 0 28 28" width="28" height="28">
        <path d="M20.1 19.1 A 8 8 0 1 1 20.1 8.9" {...STROKE} />
        <circle cx="14" cy="14" r="2.4" fill="var(--app-heading)" />
        <circle cx="22.5" cy="14" r="1.6" fill="var(--app-heading)" />
      </svg>
    ),
  },
  {
    name: "Rhythm",
    note: "cadence as a row of drops",
    svg: (
      <svg viewBox="0 0 28 28" width="28" height="28">
        <circle cx="6" cy="14" r="3.2" fill="var(--app-heading)" />
        <circle cx="14" cy="14" r="3.2" {...STROKE} strokeWidth={1.8} />
        <circle cx="22" cy="14" r="3.2" {...STROKE} strokeWidth={1.8} />
      </svg>
    ),
  },
];

export function BrandLab() {
  return (
    <Screen eyebrow="Brand lab" title="The o, emerging.">
      <style>{`
        @keyframes lab-emerge {
          0%        { transform: translate(80px, 60px) scale(0); opacity: 1; }
          18%       { transform: translate(84px, 60px) scale(0.35); opacity: 1; }
          38%       { transform: translate(102px, 60px) scale(0.6) scaleX(1.15); opacity: 1; }
          58%       { transform: translate(138px, 60px) scale(0.95); opacity: 1; }
          64%, 76%  { transform: translate(142px, 60px) scale(1); opacity: 1; }
          82%       { transform: translate(142px, 60px) scale(1); opacity: 0; }
          100%      { transform: translate(142px, 60px) scale(1); opacity: 0; }
        }
        @keyframes lab-o-in {
          0%, 60%   { opacity: 0; transform: scale(0.6); }
          66%       { opacity: 1; transform: scale(1.08); }
          72%       { opacity: 1; transform: scale(0.98); }
          78%, 92%  { opacity: 1; transform: scale(1); }
          100%      { opacity: 0; transform: scale(1); }
        }
        .lab-droplet { animation: lab-emerge 3.6s cubic-bezier(0.4, 0, 0.2, 1) infinite; }
        .lab-o-settle { transform-origin: 142px 60px; animation: lab-o-in 3.6s cubic-bezier(0.4, 0, 0.2, 1) infinite; }

        @keyframes lab-loader-emerge {
          0%       { transform: translate(30px, 22px) scale(0); opacity: 1; }
          30%      { transform: translate(36px, 22px) scale(0.6); opacity: 1; }
          55%      { transform: translate(56px, 22px) scale(0.9); opacity: 0.9; }
          62%      { transform: translate(56px, 22px) scale(1); opacity: 0; }
          100%     { transform: translate(56px, 22px) scale(1); opacity: 0; }
        }
        @keyframes lab-loader-ring {
          0%, 50%  { opacity: 0.15; }
          62%      { opacity: 1; }
          80%      { opacity: 1; }
          100%     { opacity: 0.15; }
        }
        .lab-loader-drop { animation: lab-loader-emerge 1.8s ease-in-out infinite; }
        .lab-loader-o { animation: lab-loader-ring 1.8s ease-in-out infinite; }

        @keyframes lab-breathe-kf {
          0%, 100% { transform: scale(1); opacity: 0.55; }
          50%      { transform: scale(1.1); opacity: 1; }
        }
        .lab-breathe { transform-origin: 32px 32px; animation: lab-breathe-kf 3.2s ease-in-out infinite; }

        .lab-dot {
          display: inline-block;
          width: 7px; height: 7px;
          border-radius: var(--radius-round);
          background: var(--app-hairline);
        }
        @keyframes lab-dot-swell {
          0%, 70%, 100% { transform: scale(1); background: var(--app-hairline); }
          78%           { transform: scale(1.7) scaleX(1.3); background: var(--app-heading); }
          88%           { transform: scale(1.4); background: var(--app-heading); }
        }
        .lab-dot { animation: lab-dot-swell 6s ease-in-out infinite; }

        @media (prefers-reduced-motion: reduce) {
          .lab-droplet, .lab-o-settle, .lab-loader-drop, .lab-loader-o,
          .lab-breathe, .lab-dot { animation: none; }
          .lab-droplet { transform: translate(142px, 60px) scale(1); opacity: 0; }
          .lab-o-settle { opacity: 1; }
        }
      `}</style>

      <p className="pb-[var(--spacing-md)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
        Internal design exploration — not a product surface. Motion and icon
        concepts drawn from one idea in the logotype: the o emerges from the C
        like a droplet. Monochrome ink only; nothing here reacts to a reading.
      </p>

      <div className="flex flex-col gap-[var(--spacing-sm)]">
        <Card label="1 · The mark">
          <DropletMark />
          <p className="pt-[var(--spacing-2xs)] text-ink-tertiary" style={{ fontSize: "12px" }}>
            Splash / empty-state moment. A drop buds from the C's mouth,
            travels, and settles into the o — liquid becomes letterform.
          </p>
        </Card>

        <Card label="2 · Loader">
          <div className="flex items-center gap-[var(--spacing-md)]">
            <DropletLoader />
            <p className="text-ink-tertiary" style={{ fontSize: "12px" }}>
              The same gesture at 44px, looping — replaces the "…" busy label
              on buttons and sync states.
            </p>
          </div>
        </Card>

        <Card label="3 · Breathing ring">
          <div className="flex items-center gap-[var(--spacing-md)]">
            <BreathingRing />
            <p className="text-ink-tertiary" style={{ fontSize: "12px" }}>
              Calm inhale/exhale for "waiting for Apple Health" — deliberately
              slower than a heartbeat, so it never reads as one.
            </p>
          </div>
        </Card>

        <Card label="4 · Journey dots">
          <div className="flex items-center gap-[var(--spacing-md)]">
            <DropletDots />
            <p className="text-ink-tertiary" style={{ fontSize: "12px" }}>
              The active step swells like a drop about to leave the C.
            </p>
          </div>
        </Card>

        <Card label="5 · Icon direction">
          <div className="grid grid-cols-4 gap-[var(--spacing-sm)]">
            {ICONS.map((icon) => (
              <div key={icon.name} className="flex flex-col items-center gap-[var(--spacing-3xs)] text-center">
                {icon.svg}
                <span style={{ fontSize: "11px", fontWeight: 500 }}>{icon.name}</span>
              </div>
            ))}
          </div>
          <ul className="list-disc pt-[var(--spacing-sm)] pl-[var(--spacing-sm)] text-ink-tertiary" style={{ fontSize: "12px" }}>
            {ICONS.map((icon) => (
              <li key={icon.name}>
                <span style={{ fontWeight: 500 }}>{icon.name}</span> — {icon.note}
              </li>
            ))}
          </ul>
        </Card>
      </div>
    </Screen>
  );
}

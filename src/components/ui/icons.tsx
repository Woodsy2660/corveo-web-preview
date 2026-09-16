/**
 * Interface icons.
 *
 * Line glyphs at a single 1.6 weight, sized in em so they scale with the
 * element they sit in, and drawn in `currentColor` so a tab or button
 * controls its own colour. Userkind's own `icon--end` runs a 1.5 stroke;
 * 1.6 holds up slightly better against the black tab bar.
 *
 * These are UI icons, not brand assets. The metallic gradient marks Corveo
 * supplied are identity artwork — they collapse into a grey smudge below
 * about 32px and belong in empty states and section openers, not here.
 */

type IconProps = { className?: string };

const base = {
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.6,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
  "aria-hidden": true,
  focusable: false,
};

/** Record — the heart of the app, and where readings live. */
export function HeartIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1.25em" height="1.25em">
      <path d="M12 20S3.8 14.6 3.8 9.3A4.5 4.5 0 0 1 12 6.8a4.5 4.5 0 0 1 8.2 2.5C20.2 14.6 12 20 12 20Z" />
    </svg>
  );
}

/**
 * Program — a checked sequence. Encodes the thing that is actually true
 * about it: six chapters you move through in order.
 */
export function ProgramIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1.25em" height="1.25em">
      <path d="m3.2 7.2 1.9 1.9 3-3.2" />
      <path d="m3.2 16.4 1.9 1.9 3-3.2" />
      <path d="M11.4 7.4h9.4" />
      <path d="M11.4 16.6h9.4" />
    </svg>
  );
}

/**
 * Education — an open book. Deliberately not a lightbulb: a bulb reads as
 * "idea, tip, suggestion", which is the register of advice, and advice is
 * exactly what the Intended Purpose Statement bars. A book says reading
 * material.
 */
export function EducationIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1.25em" height="1.25em">
      <path d="M12 6.6C10.4 5.3 8.4 4.7 5.2 4.7A1.2 1.2 0 0 0 4 5.9v11a1.2 1.2 0 0 0 1.2 1.2c3.2 0 5.2.6 6.8 1.9 1.6-1.3 3.6-1.9 6.8-1.9A1.2 1.2 0 0 0 20 16.9v-11a1.2 1.2 0 0 0-1.2-1.2c-3.2 0-5.2.6-6.8 1.9Z" />
      <path d="M12 6.6V20" />
    </svg>
  );
}

/** Profile — account, data and settings live behind this. */
export function ProfileIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1.25em" height="1.25em">
      <circle cx="12" cy="8.2" r="3.9" />
      <path d="M4.8 20.2a7.4 7.4 0 0 1 14.4 0" />
    </svg>
  );
}

/** Estimated time, paired with a duration label. Userkind's Date-time pattern. */
export function ClockIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1em" height="1em">
      <circle cx="12" cy="12" r="8.6" />
      <path d="M12 7.4V12l3 1.8" />
    </svg>
  );
}

/** Chapter already read. */
/**
 * Sync — two arcs chasing each other. Both are 132° of the same 8.3 radius,
 * so the glyph reads as one continuous loop rather than two unrelated
 * curves, and each chevron lands exactly on its arc's endpoint.
 */
export function SyncIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1em" height="1em">
      <path d="M20.3 12a8.3 8.3 0 0 1-13.9 6.1" />
      <path d="M3.7 12a8.3 8.3 0 0 1 13.9-6.1" />
      <path d="M17.6 2.2v3.7h-3.7" />
      <path d="M6.4 21.8v-3.7h3.7" />
    </svg>
  );
}

export function CheckIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1em" height="1em">
      <path d="m4.8 12.4 4.6 4.6L19.2 7.2" />
    </svg>
  );
}

/** Dismiss the full-screen Pulse viewer. */
export function CloseIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1.25em" height="1.25em">
      <path d="m6 6 12 12M18 6 6 18" />
    </svg>
  );
}

/** Expandable disclosure indicator. */
export function ChevronDownIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1em" height="1em">
      <path d="m6 10 6 6 6-6" />
    </svg>
  );
}

/** Swipe-up affordance in the Pulse viewer. */
export function ChevronUpIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1em" height="1em">
      <path d="m6 14 6-6 6 6" />
    </svg>
  );
}

/** Leads to a page of its own. */
export function ChevronRightIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1em" height="1em">
      <path d="m9 6 6 6-6 6" />
    </svg>
  );
}

/** Navigate back to the previous screen. */
export function ChevronLeftIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1em" height="1em">
      <path d="m15 6-6 6 6 6" />
    </svg>
  );
}

/** Add a reading. */
export function PlusIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1.25em" height="1.25em">
      <path d="M12 5.6v12.8M5.6 12h12.8" />
    </svg>
  );
}

/* ─────────────────────────────────────────────────────────────────────────────
 * Solid/filled icons — used in highlight lists (Intro, Consent) where the
 * design calls for a compact, solid glyph without a container box.
 * ───────────────────────────────────────────────────────────────────────────── */

const solidBase = {
  viewBox: "0 0 24 24",
  fill: "currentColor",
  "aria-hidden": true,
  focusable: false,
};

/** Solid heart — Home readings highlight. */
export function HeartSolidIcon({ className = "" }: IconProps) {
  return (
    <svg {...solidBase} className={className} width="1.25em" height="1.25em">
      <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
    </svg>
  );
}

/** Solid checkmark in circle — Technique/measuring well highlight. */
export function CheckCircleSolidIcon({ className = "" }: IconProps) {
  return (
    <svg {...solidBase} className={className} width="1.25em" height="1.25em">
      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
    </svg>
  );
}

/** Solid book — Education highlight. */
export function BookSolidIcon({ className = "" }: IconProps) {
  return (
    <svg {...solidBase} className={className} width="1.25em" height="1.25em">
      <path d="M21 5c-1.11-.35-2.33-.5-3.5-.5-1.95 0-4.05.4-5.5 1.5-1.45-1.1-3.55-1.5-5.5-1.5S2.45 4.9 1 6v14.65c0 .25.25.5.5.5.1 0 .15-.05.25-.05C3.1 20.45 5.05 20 6.5 20c1.95 0 4.05.4 5.5 1.5 1.35-.85 3.8-1.5 5.5-1.5 1.65 0 3.35.3 4.75 1.05.1.05.15.05.25.05.25 0 .5-.25.5-.5V6c-.6-.45-1.25-.75-2-1zm0 13.5c-1.1-.35-2.3-.5-3.5-.5-1.7 0-4.15.65-5.5 1.5V8c1.35-.85 3.8-1.5 5.5-1.5 1.2 0 2.4.15 3.5.5v11.5z" />
    </svg>
  );
}

/** Solid clipboard — What is collected. */
export function ClipboardSolidIcon({ className = "" }: IconProps) {
  return (
    <svg {...solidBase} className={className} width="1.25em" height="1.25em">
      <path d="M19 3h-4.18C14.4 1.84 13.3 1 12 1s-2.4.84-2.82 2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 0c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1z" />
    </svg>
  );
}

/** Solid lock — Where it lives. */
export function LockSolidIcon({ className = "" }: IconProps) {
  return (
    <svg {...solidBase} className={className} width="1.25em" height="1.25em">
      <path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zM9 8V6c0-1.66 1.34-3 3-3s3 1.34 3 3v2H9z" />
    </svg>
  );
}

/** Solid eye — What Corveo does with it. */
export function EyeSolidIcon({ className = "" }: IconProps) {
  return (
    <svg {...solidBase} className={className} width="1.25em" height="1.25em">
      <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z" />
    </svg>
  );
}

/** Solid shield — Your control. */
export function ShieldSolidIcon({ className = "" }: IconProps) {
  return (
    <svg {...solidBase} className={className} width="1.25em" height="1.25em">
      <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z" />
    </svg>
  );
}

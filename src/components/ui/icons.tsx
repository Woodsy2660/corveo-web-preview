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

/** Add a reading. */
export function PlusIcon({ className = "" }: IconProps) {
  return (
    <svg {...base} className={className} width="1.25em" height="1.25em">
      <path d="M12 5.6v12.8M5.6 12h12.8" />
    </svg>
  );
}

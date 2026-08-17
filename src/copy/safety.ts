/**
 * Safety surface — "what Corveo does and doesn't do" (Deliverable 12).
 *
 * STATUS: DRAFT. The final safety wording comes from Corveo (the accountable
 * entity). Drafted from the Intended Purpose Statement so the surface can be
 * built and reviewed. Language must stay within the IPS verb set and must
 * never drift toward diagnosis, urgency, or interpretation.
 */

export const SAFETY = {
  eyebrow: "About this app",
  title: "What Corveo does — and doesn't do.",
  does: {
    title: "Corveo BP Reset:",
    items: [
      "Displays and organises the blood pressure readings you record with your own monitor",
      "Shows your readings and their history exactly as recorded",
      "Provides general education about blood pressure over a six-week program",
      "Keeps your record in your control — export or deletion at any time",
    ],
  },
  doesNot: {
    title: "It does not:",
    items: [
      "Measure blood pressure — your validated cuff does that",
      "Analyse, interpret, score or classify your readings",
      "Diagnose, treat, or monitor any condition",
      "Alert you or anyone else based on a reading's value",
      "Send your readings to a doctor or clinic",
      "Replace advice from your own doctor",
    ],
  },
  seekAdvice:
    "If you are worried about a reading or how you feel, speak with your GP or cardiologist. If you feel seriously unwell, call 000.",
  disclaimer:
    "Corveo BP Reset displays and plots your blood pressure readings and provides general education. It does not diagnose, treat, or replace advice from your doctor.",
  /**
   * Shown at the foot of every education chapter. The shipped Corveo site
   * carries an equivalent line on every article; putting it at the point of
   * reading rather than only in Settings matches that, and puts it where the
   * education is actually consumed.
   */
  educationNote:
    "This is general education and is not a substitute for personalised advice from your own clinician.",
} as const;

/**
 * Validated upper-arm cuff list (Deliverable 8).
 *
 * Source: STRIDE BP — the international scientific initiative for accurate
 * BP measurement (stridebp.org), which maintains the authoritative list of
 * clinically validated monitors. The in-app screen cites this source, per
 * the acceptance medium ("in-app screen and written source reference").
 * Model list to be confirmed against the current STRIDE BP register before
 * Stage 3 acceptance.
 */
export const VALIDATED_CUFFS = {
  eyebrow: "Choosing a monitor",
  title: "Validated upper-arm cuffs.",
  intro:
    "Corveo recommends clinically validated upper-arm monitors. These models appear on the STRIDE BP validated device register. Corveo doesn't sell monitors and has no affiliation with any manufacturer.",
  devices: [
    { brand: "Omron", model: "HEM-7361T (Gold / Platinum)", connectivity: "Bluetooth via OMRON connect → Apple Health" },
    { brand: "Withings", model: "BPM Connect", connectivity: "Wi-Fi / Bluetooth via Withings app → Apple Health" },
    { brand: "Omron", model: "HEM-7156 (Standard)", connectivity: "Manual entry" },
  ],
  sourceNote:
    "Validation status per STRIDE BP (stridebp.org), accessed August 2026.",
} as const;

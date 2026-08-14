/**
 * Express-consent step copy (Deliverable 5 + 13).
 *
 * STATUS: DRAFT. The final consent and collection-notice text is Deliverable
 * 13 — supplied to Corveo, who adopts and publishes it as the accountable
 * entity. Do not treat this draft as approved wording; it exists so the flow
 * can be built and demonstrated. The version string and hash mechanics are
 * real: consent_event stores a SHA-256 of the exact text shown
 * (docs/02 §1 consent_event), so this text must be frozen per release.
 */

export const CONSENT_VERSION = "0.1-draft";

export const CONSENT = {
  eyebrow: "Your consent",
  title: "Before your record begins.",
  intro:
    "Corveo asks for your express consent to collect and store the blood pressure readings you choose to record. Please read this before continuing.",
  points: [
    {
      title: "What is collected",
      body: "Blood pressure readings you enter or share through Apple Health, with the time and source of each reading, and your program progress.",
    },
    {
      title: "Where it lives",
      body: "Your record is stored securely in Australia, in Corveo's systems. It is not sold, shared for advertising, or used to train AI models.",
    },
    {
      title: "What Corveo does with it",
      body: "Corveo displays your readings back to you and organises them alongside the education program. Corveo does not analyse or interpret your readings and does not send them to any clinician.",
    },
    {
      title: "Your control",
      body: "You can export your record or ask for it to be deleted at any time from Settings. Health-records law sets a minimum retention period; deletion is carried out against that, and every access to your record is logged.",
    },
  ],
  checkboxLabel:
    "I have read and understood the above, and I expressly consent to Corveo collecting and storing my blood pressure readings as described.",
  cta: "I consent",
} as const;

/**
 * SHA-256 of the exact consent copy shown, computed at runtime from the
 * rendered text. Proves which words were shown, not just that a box was
 * ticked (docs/02 §1).
 */
export async function hashConsentText(): Promise<string> {
  const text = [
    CONSENT.eyebrow,
    CONSENT.title,
    CONSENT.intro,
    ...CONSENT.points.map((p) => `${p.title}: ${p.body}`),
    CONSENT.checkboxLabel,
    CONSENT.cta,
  ].join("\n");
  const data = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

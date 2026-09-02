/**
 * Journey (onboarding) copy.
 *
 * Copy discipline (Intended Purpose Statement §2–3): only the verbs
 * understand · learn · track · organise, qualified with "alongside your
 * care". No outcome verbs (lower, reduce, control, manage, improve). No
 * interpretation of readings, ever. Mechanical validation copy lives in
 * validation.ts and is fixed verbatim.
 */

export const JOURNEY = {
  /** Landing screen: the brand, a greeting, one action. Nothing to read yet. */
  welcome: {
    title: "Welcome.",
    cta: "Get started",
  },

  intro: {
    eyebrow: "Six-week program",
    title: "Understand your blood pressure.",
    intro:
      "A clearer way to understand your blood pressure. Track your readings and learn week by week, alongside the care of your own doctor.",
    cards: [
      {
        title: "Why home readings matter",
        body: "Readings taken quietly at home, over weeks, build a fuller picture than any single measurement can. That picture is what you and your doctor can talk about.",
      },
      {
        title: "How to measure well",
        body: "Seated, rested, arm supported at heart level. Same times each day. The program walks you through this in week one.",
      },
      {
        title: "What this program is",
        body: "Six weeks of short, evidence-based education about blood pressure, minus the wellness hype, with your own readings organised alongside it. Corveo displays your readings and their history. It does not diagnose or replace your doctor.",
      },
    ],
    cta: "Begin",
  },

  signup: {
    eyebrow: "Your account",
    title: "A place for your record.",
    intro:
      "Your readings are stored securely in Australia and stay yours. You can export or delete them whenever you like.",
    emailLabel: "Email address",
    passwordLabel: "Password",
    adultAttestation: "I am 18 years or older.",
    cta: "Create account",
  },

  connect: {
    eyebrow: "Your monitor",
    title: "How will readings arrive?",
    intro:
      "Corveo organises readings from a validated upper-arm cuff. Choose how yours will come in. You can change this later in Settings.",
    options: {
      healthkit: {
        title: "My monitor's app connects to Apple Health",
        body: "Your monitor's own app writes readings to Apple Health, and Corveo reads them from there. It reads blood pressure only, and it never writes.",
      },
      manual: {
        title: "I'll enter readings myself",
        body: "Manual entry takes about ten seconds per reading.",
      },
      none: {
        title: "I don't have a monitor yet",
        body: "No worries. The education program starts either way, and we'll show you a list of validated upper-arm cuffs worth a look.",
      },
    },
    cta: "Continue",
  },

  healthAuth: {
    eyebrow: "Apple Health",
    title: "Connect Apple Health.",
    intro:
      "Corveo asks Apple Health for permission to read blood pressure readings. Apple will show you exactly what is shared. Corveo only ever reads, and it never writes to Apple Health.",
    cta: "Connect Apple Health",
    skip: "Not now, I'll enter readings myself",
    /** Neutral nudge — verbatim from docs/03-plugin-bridge-spec.md §4. Never imply denial. */
    noSamplesNudge:
      "We haven't seen any readings yet. You can check Corveo's access in Settings › Health › Data Access & Devices.",
  },

  firstCapture: {
    eyebrow: "First reading",
    title: "A starting point.",
    intro:
      "Enter your most recent reading. One reading is just a starting point. The picture builds over the coming weeks.",
    systolicLabel: "Systolic (top)",
    diastolicLabel: "Diastolic (bottom)",
    timeLabel: "When was it taken?",
    armLabel: "Which arm?",
    armLeft: "Left",
    armRight: "Right",
    cta: "Save reading",
    healthkitWaiting:
      "Once your monitor's app syncs with Apple Health, readings will appear here on their own. You can also add one yourself now.",
    /** Health users only. Goes to the rhythm step; the record begins when the sync does. */
    skipHealth: "My readings come from Apple Health",
  },

  result: {
    eyebrow: "Your record",
    title: "Your record has begun.",
    body: "One reading is a starting point. What matters is how your readings sit over the coming weeks. That pattern is what you and your doctor can talk about, alongside your care.",
    cta: "Choose your rhythm",
  },

  cadence: {
    eyebrow: "Your rhythm",
    title: "A light rhythm.",
    intro:
      "A steady rhythm of readings builds the clearest record. Choose whatever fits your days. You can change this at any time.",
    options: {
      twice_daily: {
        title: "Morning and evening",
        body: "Suggested for the first two weeks of the program.",
      },
      daily: { title: "Once a day", body: "A steady, sustainable record." },
      few_weekly: {
        title: "A few times a week",
        body: "A lighter rhythm that still builds your picture.",
      },
    },
    reminderNote:
      "Corveo can remind you at your chosen times. Reminders follow the rhythm you choose and are never triggered by a reading.",
    cta: "Go to My Heart Record",
  },
} as const;

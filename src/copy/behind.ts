/**
 * "Behind the scenes" — the six things worth knowing about how a reading
 * gets from the cuff into the record.
 *
 * Written for someone who is not an engineer but is not going to be
 * patronised either. The `sub` line stays conversational; the `note` under
 * it names the actual mechanism for anyone who wants it, in one line, and
 * is safe to skip. Every claim is a property of the build rather than a
 * promise about it.
 */

export const BEHIND = {
  close: "Close",
  next: "Next",
  back: "Back",
  intro: {
    eyebrow: "Behind the scenes",
    title: "How a reading finds its way here.",
    sub: "Six steps between the cuff on your arm and the row in your record. None of them need anything from you.",
    start: "Begin",
  },
  beats: [
    {
      id: "health",
      title: "Your cuff already talks to Apple Health.",
      sub: "Omron, Withings and the rest already write into Apple Health through their own apps. Corveo picks it up from there — no second device to pair.",
      note: "HealthKit · systolic and diastolic, paired as one reading",
    },
    {
      id: "read",
      title: "Corveo only reads.",
      sub: "We ask Apple for read access to systolic and diastolic, and nothing else. The permission to write isn't in the app at all.",
      note: "No write entitlement compiled into the build — checkable in the shipped app",
    },
    {
      id: "wake",
      title: "Readings arrive with the app closed.",
      sub: "When something new lands in Apple Health, iOS wakes Corveo for a few seconds to collect it. Think within the hour, not within the second.",
      note: "Observer query plus background delivery · iOS decides the timing, and throttles it",
    },
    {
      id: "hold",
      title: "They wait on your phone until you sign in.",
      sub: "Encrypted on the phone, kept out of iCloud backups, and sent nowhere until there's a signed-in session to send them to.",
      note: "File-protected storage · excluded from device backup",
    },
    {
      id: "once",
      title: "Then written once — even when something fails.",
      sub: "If an upload drops halfway the reading stays queued and goes again, and the record still can't gain a duplicate.",
      note: "Idempotent on the identifier Apple assigned · a retry collapses to one row",
    },
    {
      id: "plain",
      title: "Nothing is ever interpreted.",
      sub: "No thresholds, no colour bands, no risk scores, no alert tied to a number. Corveo shows your readings and keeps them in order.",
      note: "The chart's two colours mean systolic and diastolic — never a value",
    },
  ],
  end: {
    title: "That's the whole of it.",
    sub: "All of it runs on the phone itself, and all of it gets demonstrated on a real iPhone — background delivery can't be faked in a simulator.",
    note: "Stage 2 acceptance · physical device, against the written test script",
    done: "Back to the app",
  },
} as const;

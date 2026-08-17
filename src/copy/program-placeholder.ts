/**
 * PLACEHOLDER program content — development only.
 *
 * The real six-week curriculum is authored, clinically reviewed and supplied
 * by Corveo (Deliverable 7, client dependency 5) and replaces this file
 * verbatim. Placeholder text follows the same discipline as everything else:
 * general education, no interpretation, no outcome claims, and the IPS verb
 * set (understand · learn · track · organise).
 *
 * The shape mirrors Userkind's Programs collection so the container does not
 * change when real content lands: a chapter has a card title, a card excerpt,
 * an estimated time, and body content. `cardImage` is in their model and not
 * here — chapter artwork is a Corveo asset that hasn't been supplied.
 *
 * Program content is static. It never varies with the reader's readings.
 */

/**
 * Userkind's chapters carry a medium — the site renders "12 min watch" and
 * "Watch video" off it. Modelled here so the list survives real content, but
 * every placeholder chapter is `read`: the app has no player, and whether
 * the six weeks include video or audio is an open scope question.
 */
export type ChapterMedium = "read" | "watch" | "listen";

/** Program-level header, mirroring a Programs record on the site. */
export const PROGRAM = {
  title: "The six-week program",
  description:
    "Short, practical education about blood pressure, alongside the record you build yourself.",
} as const;

export interface ProgramSection {
  heading: string;
  body: readonly string[];
}

export interface ProgramChapter {
  week: number;
  /** Userkind `cardTitle`. */
  title: string;
  /** Userkind `cardExcerpt` — the one-line summary on the chapter card. */
  excerpt: string;
  /** Standfirst shown under the title in the reading view. */
  deck: string;
  readMinutes: number;
  /** Defaults to "read" — see ChapterMedium. */
  medium?: ChapterMedium;
  /**
   * Attribution slot. The shipped site bylines articles to a named
   * cardiologist; placeholder text is deliberately attributed to nobody.
   */
  reviewStatus: string;
  sections: readonly ProgramSection[];
}

const PENDING_REVIEW = "Pending";

export const PROGRAM_PLACEHOLDER_WEEKS: readonly ProgramChapter[] = [
  {
    week: 1,
    title: "Understanding blood pressure",
    excerpt: "What the two numbers describe, and why readings vary through the day.",
    deck: "Every reading is two numbers taken at one moment. Knowing what each one describes makes the rest of the program easier to follow.",
    readMinutes: 3,
    reviewStatus: PENDING_REVIEW,
    sections: [
      {
        heading: "What the two numbers describe",
        body: [
          "A blood pressure reading is written as one number over another, in millimetres of mercury — mmHg. The first is systolic pressure, measured as the heart contracts. The second is diastolic pressure, measured as the heart relaxes between beats.",
          "Both are recorded together because they describe different parts of the same cycle. Your record keeps them as a pair, exactly as your monitor reported them.",
        ],
      },
      {
        heading: "Why one reading is only one moment",
        body: [
          "Blood pressure is not a fixed property like height. It shifts through the day and responds to posture, activity, conversation, caffeine, sleep and the time since you last moved.",
          "This is why the program asks you to record over weeks rather than to read anything into a single measurement. What a clinician looks at is the shape of a record over time, and that is what your doctor can discuss with you.",
        ],
      },
    ],
  },
  {
    week: 2,
    title: "Measuring well",
    excerpt: "Position, timing and rhythm — how a good home reading is taken.",
    deck: "Home monitors are accurate when they are used consistently. Most of that is technique, and it takes a minute to learn.",
    readMinutes: 4,
    reviewStatus: PENDING_REVIEW,
    sections: [
      {
        heading: "Setting up",
        body: [
          "Use a validated upper-arm cuff sized to your arm. Sit with your back supported and both feet flat on the floor, and rest for a few minutes before starting. Place the cuff on bare skin, level with your heart, and keep your arm supported on a table.",
          "Stay quiet during the measurement. Talking, holding your arm up, or crossing your legs all change what the monitor records.",
        ],
      },
      {
        heading: "Building a rhythm",
        body: [
          "Recording at roughly the same times makes a record easier to read later. Many people take one reading in the morning and one in the evening, though the rhythm you chose during setup is the one to follow.",
          "If a reading looks unlike the others, take it again after a short rest and record both. Your record is meant to hold what happened, not a tidied version of it.",
        ],
      },
    ],
  },
  {
    week: 3,
    title: "Reading your record",
    excerpt: "Why patterns over weeks matter more than any single reading.",
    deck: "Your record is a history, not a score. This chapter is about reading it as one.",
    readMinutes: 3,
    reviewStatus: PENDING_REVIEW,
    sections: [
      {
        heading: "What the trend view shows",
        body: [
          "The trend view plots a daily summary of the readings you have recorded, drawn exactly as they were entered. There are no bands, zones or colour coding on it, because Corveo does not assess your readings — it organises and displays them.",
          "Gaps in the line are days without a reading. They are not failures; they are simply days with nothing recorded.",
        ],
      },
      {
        heading: "What to bring to an appointment",
        body: [
          "A record covering several weeks gives your doctor more to work with than a handful of recent numbers. Export your record before an appointment if it helps, and note anything unusual about particular days.",
          "Any judgement about what your record means belongs with your own clinician, who knows your history and the rest of your care.",
        ],
      },
    ],
  },
  {
    week: 4,
    title: "Everyday influences",
    excerpt: "Salt, sleep, movement and medication timing — what research has looked at.",
    deck: "A short tour of the everyday factors research has examined, and why none of them applies to everyone equally.",
    readMinutes: 5,
    reviewStatus: PENDING_REVIEW,
    sections: [
      {
        heading: "What has been studied",
        body: [
          "Blood pressure research has examined dietary sodium, sleep quality and duration, physical activity, alcohol, body weight and stress. Each has been studied across large populations, and the findings describe averages across groups rather than what will happen for one person.",
          "Medication timing has also been studied. If you take medication, the timing question is one for your prescriber, not something to change on your own.",
        ],
      },
      {
        heading: "Why individual answers come from your clinician",
        body: [
          "How much any of these matter for you depends on your history, your other conditions and your medication. That is knowledge your doctor holds and this app does not.",
          "The purpose of this chapter is to help you understand what is being discussed when these topics come up, so the conversation alongside your care is a more useful one.",
        ],
      },
    ],
  },
  {
    week: 5,
    title: "Talking with your doctor",
    excerpt: "Bringing your record to appointments, and the questions worth asking.",
    deck: "Appointments are short. Arriving organised makes the time go further.",
    readMinutes: 4,
    reviewStatus: PENDING_REVIEW,
    sections: [
      {
        heading: "Before the appointment",
        body: [
          "Export your record, or have it open, so the history is available rather than remembered. Note the dates of anything that might be relevant — an illness, a change in medication, a period of poor sleep, a holiday.",
          "Write your questions down beforehand. It is easy to leave without asking the one that mattered.",
        ],
      },
      {
        heading: "Questions people commonly ask",
        body: [
          "What does my record suggest to you? How often should I be recording? Is my monitor a suitable one? Should anything about my medication change, and if so when would we review it? Is there anything in my record you would like me to watch for and report?",
          "These are prompts, not a script. Your clinician will have their own questions too.",
        ],
      },
    ],
  },
  {
    week: 6,
    title: "Keeping the rhythm",
    excerpt: "Carrying the habit forward after the program ends.",
    deck: "The program finishes; the record does not have to.",
    readMinutes: 3,
    reviewStatus: PENDING_REVIEW,
    sections: [
      {
        heading: "After six weeks",
        body: [
          "The app stays available and your record stays yours. Many people keep recording at a lower frequency than during the program — your clinician can tell you what suits your situation.",
          "Everything you have recorded remains exportable and deletable at any time, from Settings.",
        ],
      },
      {
        heading: "What Corveo will and won't do",
        body: [
          "Corveo will keep displaying and organising what you record, and will keep this education available to re-read.",
          "It will not tell you whether a reading is good or bad, will not alert anyone, and will not send your record to a clinic. Those boundaries are deliberate, and they are described in full under Settings.",
        ],
      },
    ],
  },
] as const;

/**
 * PLACEHOLDER program catalogue — development only.
 *
 * Mirrors the Programs collection on corveo.vercel.app so the app's library
 * has the same shape the CMS already publishes. Real programs arrive from
 * Supabase; this exists so the browse-and-follow flow can be built and
 * reviewed.
 *
 * SCOPE: only the six-week BP Reset program is inside Deliverable 7. The
 * other four are the website's programs, reproduced here as catalogue
 * entries so the IA can be judged. Shipping them is a Change Request.
 *
 * Deliberately card-metadata only for everything except BP Reset. Titles and
 * one-line excerpts are topic labels; writing placeholder *body* copy about
 * medication or cardiac recovery would put words in Corveo's mouth on
 * exactly the subjects where that matters most. A chapter with no
 * `sections` renders as content pending.
 */

import { PROGRAM, PROGRAM_PLACEHOLDER_WEEKS, type ProgramChapter } from "./program-placeholder";

export interface ProgramSummary {
  slug: string;
  title: string;
  description: string;
  /** BP Reset runs to a weekly cadence; the library programs are chaptered. */
  unitLabel: "Week" | "Chapter";
  chapters: readonly ProgramChapter[];
  /**
   * The product's own program. Always followed and cannot be dropped — it is
   * what the app is for.
   */
  core?: boolean;
}

const PENDING = "Pending";

/** Card-level entry for a library chapter whose body content is not ours to write. */
function card(
  n: number,
  title: string,
  excerpt: string,
  readMinutes: number,
  medium: ProgramChapter["medium"] = "read",
): ProgramChapter {
  return { week: n, title, excerpt, readMinutes, medium, reviewStatus: PENDING };
}

export const PROGRAMS: readonly ProgramSummary[] = [
  {
    slug: "bp-reset",
    title: PROGRAM.title,
    description: PROGRAM.description,
    unitLabel: "Week",
    core: true,
    chapters: PROGRAM_PLACEHOLDER_WEEKS,
  },
  {
    slug: "primary-prevention",
    title: "Primary prevention program",
    description:
      "A guided sequence covering the fundamentals of protecting your heart before problems start.",
    unitLabel: "Chapter",
    chapters: [
      card(1, "Understanding cholesterol", "What LDL and HDL describe, and what the numbers refer to.", 3),
      card(2, "Risk factors and screening", "What clinicians look at, and which checks happen when.", 5),
      card(3, "The evidence base", "A cardiologist-written look at what the research supports.", 6),
      card(4, "Movement and the heart", "What has been studied about activity and cardiovascular health.", 4),
      card(5, "Sleep and stress", "How the research treats rest, and where the evidence is thinner.", 4),
      card(6, "Bringing it together", "Where prevention sits alongside the rest of your care.", 3),
    ],
  },
  {
    slug: "understanding-medication",
    title: "Understanding your medication",
    description:
      "What common heart medications do, why they are prescribed, and how to take them with confidence.",
    unitLabel: "Chapter",
    chapters: [
      card(1, "Why medication is prescribed", "The reasoning a prescriber works from.", 4),
      card(2, "Common classes explained", "What the main groups of heart medication do.", 6),
      card(3, "Taking them consistently", "Timing, routine, and what to raise at a review.", 4),
      card(4, "Questions for your prescriber", "What is worth asking, and when.", 3),
      card(5, "Reviews and changes", "How and why a prescription gets revisited.", 4),
    ],
  },
  {
    slug: "life-after-a-cardiac-event",
    title: "Life after a cardiac event",
    description:
      "Practical, reassuring guidance for recovery and building sustainable heart-healthy habits.",
    unitLabel: "Chapter",
    chapters: [
      card(1, "The first weeks", "What recovery commonly involves, and who is involved in it.", 5),
      card(2, "Cardiac rehabilitation", "What a rehabilitation program is and how referral works.", 9, "watch"),
      card(3, "Returning to activity", "How activity is usually reintroduced, and by whom it is guided.", 4),
      card(4, "Keeping the habit", "Carrying a routine forward once the program ends.", 4),
    ],
  },
  {
    slug: "nutrition",
    title: "Nutrition for a healthy heart",
    description:
      "Evidence-based eating: what the research actually supports, minus the fad-diet noise.",
    unitLabel: "Chapter",
    chapters: [
      card(1, "What the research examines", "The dietary factors most studied in cardiovascular research.", 7),
      card(2, "Reading a food label", "What the numbers on a package describe.", 5),
      card(3, "Sodium in everyday food", "Where it turns up, and how it is measured.", 4),
      card(4, "Eating patterns, not rules", "Why research describes patterns rather than prescriptions.", 21, "listen"),
      card(5, "Talking it through", "Bringing questions about diet to your own clinician.", 3),
    ],
  },
] as const;

export const CORE_PROGRAM_SLUG = "bp-reset";

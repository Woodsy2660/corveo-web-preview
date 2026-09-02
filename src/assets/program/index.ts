import week1 from "./week-1.svg";
import week2 from "./week-2.svg";
import week3 from "./week-3.svg";
import week4 from "./week-4.svg";
import week5 from "./week-5.svg";
import week6 from "./week-6.svg";
import bpReset from "./bp-reset.svg";
import primaryPrevention from "./primary-prevention.svg";
import understandingMedication from "./understanding-medication.svg";
import lifeAfterACardiacEvent from "./life-after-a-cardiac-event.svg";
import nutrition from "./nutrition.svg";

/**
 * Chapter tiles by week. Placeholders: one flat tint from the brand palette
 * and one abstract stroke each, so nothing reads as a medical image. Corveo's chapter artwork
 * (a client asset, not yet supplied) replaces these files verbatim.
 */
export const CHAPTER_ART: Record<number, string> = {
  1: week1,
  2: week2,
  3: week3,
  4: week4,
  5: week5,
  6: week6,
};

/** Program tiles by slug, for the rail and the library. Same placeholder rule. */
export const PROGRAM_ART: Record<string, string> = {
  "bp-reset": bpReset,
  "primary-prevention": primaryPrevention,
  "understanding-medication": understandingMedication,
  "life-after-a-cardiac-event": lifeAfterACardiacEvent,
  nutrition,
};

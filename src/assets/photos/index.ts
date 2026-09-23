import week1 from "./week-1.jpg";
import week2 from "./week-2.jpg";
import week3 from "./week-3.jpg";
import week4 from "./week-4.jpg";
import week5 from "./week-5.jpg";
import week6 from "./week-6.jpg";
import bpReset from "./bp-reset.jpg";
import primaryPrevention from "./primary-prevention.jpg";
import understandingMedication from "./understanding-medication.jpg";
import lifeAfterACardiacEvent from "./life-after-a-cardiac-event.jpg";
import nutrition from "./nutrition.jpg";
import homeRecord from "./home-record.jpg";
import monitorWorks from "./monitor-works.jpg";
import clinician from "./clinician.jpg";
import history from "./history.jpg";
import alarmClock from "./alarm-clock.jpg";
import whiteCoat from "./white-coat.jpg";

/**
 * PLACEHOLDER photography for the preview: stock images under the Unsplash
 * licence, chosen for mood, not meaning. Corveo's own artwork (a client
 * asset, not yet supplied) replaces these files verbatim. Sources and
 * licence in ./SOURCES.md.
 */

/** Chapter tiles by week. */
export const CHAPTER_ART: Record<number, string> = {
  1: week1,
  2: week2,
  3: week3,
  4: week4,
  5: week5,
  6: week6,
};

/** Program tiles by slug, for the rail and the library. */
export const PROGRAM_ART: Record<string, string> = {
  "bp-reset": bpReset,
  "primary-prevention": primaryPrevention,
  "understanding-medication": understandingMedication,
  "life-after-a-cardiac-event": lifeAfterACardiacEvent,
  nutrition,
};

/** In Focus article tiles by prototype key from the education package. */
export const ARTICLE_ART: Record<string, string> = {
  "demo-editorial-07": homeRecord,
  "demo-editorial-08": monitorWorks,
  "demo-editorial-09": clinician,
  "demo-editorial-10": history,
};

/** Pulse card backgrounds by prototype key from the education package. */
export const PULSE_ART: Record<string, string> = {
  "demo-editorial-01": alarmClock,
  "demo-editorial-02": history,
  "demo-editorial-03": whiteCoat,
  "demo-editorial-04": week2,
  "demo-editorial-05": week6,
  "demo-editorial-06": clinician,
};

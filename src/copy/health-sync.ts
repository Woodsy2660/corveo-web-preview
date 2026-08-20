/**
 * Apple Health connection and sync copy.
 *
 * The sheet strings reproduce iOS's own wording, because the sheet is drawn
 * by iOS and not by us — including the last line, which is the system telling
 * the patient the thing our whole permission model is built around: an app is
 * never told that it was refused.
 */

export const HEALTH_SYNC = {
  sheet: {
    dontAllow: "Don't Allow",
    allow: "Allow",
    title: (app: string) => `"${app}" Would Like to Access Your Health Data`,
    body: "Choose the data you would like to share. You can change this at any time in the Health app.",
    turnOnAll: "Turn On All",
    readSection: (app: string) => `ALLOW "${app.toUpperCase()}" TO READ DATA`,
    types: [
      { id: "bloodPressureSystolic", label: "Blood Pressure Systolic" },
      { id: "bloodPressureDiastolic", label: "Blood Pressure Diastolic" },
    ],
    /** iOS's own footnote, verbatim. */
    footnote: "Apps are not notified if you deny access to data.",
  },

  card: {
    title: "Apple Health",
    connected: "Connected",
    readsOnly: "Corveo reads blood pressure only. It never writes to Apple Health.",
    waiting: "Waiting for your next reading.",
    updated: (when: string) => `Updated ${when}`,
    arrived: "New reading from OMRON connect",
    sync: {
      idle: "Sync",
      busy: "Syncing",
      done: "Synced",
      aria: "Check Apple Health for new readings",
    },
  },

  behindLink: "Behind the scenes",
} as const;

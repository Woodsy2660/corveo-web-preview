/**
 * Main app (tabs + settings) copy.
 *
 * Same discipline as journey.ts: display, never interpret. Nothing here may
 * reference whether a value is high, low, normal, or concerning.
 */

import { MY_HEART_RECORD } from "./product";

export const APP = {
  common: {
    unitMmHg: "mmHg",
    settingsLink: "Settings",
    cancel: "Cancel",
    back: "Back",
    busy: "…",
  },

  tabs: {
    readings: "Readings",
    trend: "Trend",
    program: "Program",
  },

  readings: {
    eyebrow: MY_HEART_RECORD,
    title: "Your readings.",
    empty:
      "No readings yet. Your record begins with the first reading you add or share.",
    sparse: "Building your picture — a small number of readings so far.",
    addCta: "Add a reading",
    sourceHealth: "Apple Health",
    sourceManual: "Manual",
  },

  trend: {
    eyebrow: MY_HEART_RECORD,
    title: "Your pattern over time.",
    intro:
      "Each point is a daily summary of your readings, shown exactly as recorded. The pattern across weeks is what's worth discussing with your doctor.",
    ranges: { twoWeeks: "2W", sixWeeks: "6W", all: "All" },
    rangeAria: "Trend range",
    chartAria: "Blood pressure readings over time, shown as recorded",
    legendSystolic: "Systolic",
    legendDiastolic: "Diastolic",
    empty: "Your trend appears once readings begin to arrive.",
  },

  program: {
    eyebrow: "Six-week program",
    title: "Learn, week by week.",
    weekLabel: (n: number) => `Week ${n}`,
    contentPendingNotice:
      "Education content is being prepared and clinically reviewed by the Corveo team. Placeholder content is shown during development.",
    lockedNote: "Opens as your program progresses.",
    progress: (read: number, total: number) => `${read} of ${total} read`,
    readTime: (min: number) => `${min} min read`,
    readLabel: "Read",
    openChapterAria: (n: number, title: string) => `Week ${n}: ${title}`,
  },

  chapter: {
    back: "Program",
    metaWeek: "Week",
    metaWeekValue: (n: number, total: number) => `${n} of ${total}`,
    metaReadTime: "Estimated read time",
    metaReadTimeValue: (min: number) => `${min} minutes`,
    metaReview: "Clinical review",
    markRead: "Mark as read",
    markedRead: "Read",
    previous: "Previous chapter",
    next: "Next chapter",
    notFound: "That chapter isn't available.",
  },

  manualEntry: {
    eyebrow: "New reading",
    title: "Add a reading.",
    timeNote: "Recorded readings keep the time you set here.",
    cta: "Save reading",
    saveFailed: "The reading couldn't be saved. Please try again.",
  },

  settings: {
    eyebrow: "Settings",
    title: "Your data, your record.",
    appleHealth: {
      title: "Apple Health",
      readsOnly: "Corveo reads blood pressure only. It never writes.",
      manageHint: "Manage access in Settings › Health › Data Access & Devices.",
      notConnected: "Not connected. You can connect Apple Health at any time.",
    },
    yourData: {
      title: "Your data",
      body: "Your readings are yours. Export or request deletion at any time.",
      exportCta: "Export my record",
      exportNote: "Your full record as a file you can keep or share yourself.",
      deleteCta: "Request deletion",
      deleteConfirmTitle: "Request deletion of your record?",
      deleteConfirmBody:
        "Your account and readings will be deleted. Health-records law sets a minimum retention period — deletion is carried out and logged against it. This cannot be undone from the app.",
      deleteConfirmCta: "Request deletion",
      deleteCancelCta: "Keep my record",
      consentReceipt: (version: string, date: string) =>
        `You gave express consent (v${version}) on ${date}.`,
    },
    cuffs: {
      title: "Validated monitors",
      cta: "See validated upper-arm cuffs",
    },
    about: {
      title: "About Corveo BP Reset",
    },
    demo: {
      title: "Demo",
      resetCta: "Reset demo data",
      note: "Development build only — restores the synthetic dataset.",
    },
  },
} as const;

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
    /** Accessible name for the header profile icon — no visible label. */
    profileAria: "Profile and settings",
    cancel: "Cancel",
    back: "Back",
    busy: "…",
  },

  /** Tab labels are accessible names only; the bar itself is icon-only. */
  tabs: {
    navAria: "Main",
    record: "Record",
    program: "Program",
    education: "Learn",
  },

  education: {
    title: "Learn.",
    intro:
      "Short reads and long reads from the Corveo publication, alongside your program.",
    pulseHeading: "The Pulse",
    pulseSub: "Short reads",
    inFocusHeading: "In Focus",
    inFocusSub: "Long reads",
    openPulseAria: (title: string) => `Open short read: ${title}`,
    contentPendingNotice:
      "Education content is being prepared and clinically reviewed by the Corveo team. Placeholder content is shown during development.",
    scopeNote:
      "The Pulse and In Focus are the website's collections, shown here so the library can be reviewed. Publishing them in the app is a change request.",
  },

  pulse: {
    /** Position indicator in the full-screen viewer — "2 of 6". */
    counter: (n: number, total: number) => `${n} of ${total}`,
    closeAria: "Close",
    swipeHint: "Swipe up for the next read",
    pendingBody:
      "This read is being prepared and clinically reviewed by the Corveo team.",
  },

  inFocus: {
    back: "Learn",
    overline: "In Focus",
    notFound: "That article isn't available.",
  },

  /**
   * The Record tab holds the trend and the history together — they are the
   * same data at two grains, and splitting them made people toggle tabs to
   * answer one question.
   */
  record: {
    eyebrow: MY_HEART_RECORD,
    title: "Your record.",
    historyHeading: "History",
  },

  readings: {
    empty:
      "No readings yet. Your record begins with the first reading you add or share.",
    sparse: "Your picture is building. Only a few readings so far.",
    addCta: "Add a reading",
    sourceHealth: "Apple Health",
    sourceManual: "Manual",
  },

  trend: {
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
    /** Stable one-line heading: the program's own name is the subheading. */
    title: "Your program.",
    weekLabel: (n: number) => `Week ${n}`,
    lockedNote: "Opens as your program progresses.",
    progress: (read: number, total: number) => `${read} of ${total} read`,
    progressAria: (read: number, total: number) => `${read} of ${total} chapters read`,
    /** "3 min read" / "12 min watch" / "21 min listen" — matches the site. */
    duration: (min: number, medium: "read" | "watch" | "listen") =>
      `${min} min ${medium}`,
    readLabel: "Read",
    contentPending: "Content pending",
    browseAll: "All programs",
    openChapterAria: (n: number, title: string) => `Chapter ${n}: ${title}`,

    /** The rail at the foot of the tab: the way to the other programs. */
    rail: {
      heading: "More programs",
      sub: "Follow to add",
      followAria: (title: string) => `Follow ${title}`,
      unfollowAria: (title: string) => `Unfollow ${title}`,
      switchAria: (title: string) => `Switch to ${title}`,
      openAria: (title: string) => `About ${title}`,
    },
  },

  programIndex: {
    title: "Programs",
    intro:
      "Guided sequences you can follow alongside your own record. Follow as many as you like.",
    emptyIntro: "You are not following a program yet. Choose one to begin.",
    chapterCount: (n: number, unit: string) => `${n} ${unit}s`,
    follow: "Follow",
    following: "Following",
    scopeNote:
      "Only the six-week program is part of this release. The others are shown so the library can be reviewed.",
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
    aboutTitle: "About this app",
    cuffsTitle: "Validated monitors",
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
        "Your account and readings will be deleted. Health-records law sets a minimum retention period, and deletion is carried out and logged against it. This cannot be undone from the app.",
      deleteConfirmCta: "Request deletion",
      deleteCancelCta: "Keep my record",
      consentReceipt: (version: string, date: string) =>
        `You gave express consent (v${version}) on ${date}.`,
    },
    demo: {
      title: "Demo",
      resetCta: "Reset demo data",
      note: "Development build only. Restores the synthetic dataset.",
    },
  },
} as const;

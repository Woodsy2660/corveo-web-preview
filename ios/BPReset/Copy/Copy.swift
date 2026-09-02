import Foundation

/*
 Every user-facing string lives in this file or in Placeholders.swift, ported verbatim from
 `src/copy` on frontend/presentation (F-06 voice: Australian English, no em dashes on
 screen, the intended-purpose verb set).

 Discipline: display, never interpret. Nothing here may reference whether a value is high,
 low, normal or concerning.
 */

enum ProductCopy {
    /// Trade mark clearance is Corveo's responsibility. A rename is a one-line change.
    static let myHeartRecord = "My Heart Record"
    static let corveoWordmark = "Corveo"
}

enum ValidationCopy {
    static let pleaseCheck = "Please check this value."
    static let systolicGreater = "Systolic should be higher than diastolic."
}

enum AppCopy {
    enum common {
        static let unitMmHg = "mmHg"
        static let settingsLink = "Settings"
        static let profileAria = "Profile and settings"
        static let profileCloseAria = "Close settings"
        static let cancel = "Cancel"
        static let back = "Back"
        static let busy = "…"
    }

    enum tabs {
        static let navAria = "Main"
        static let record = "Record"
        static let program = "Program"
        static let education = "Learn"
    }

    enum education {
        static let title = "Learn."
        static let intro = "Short reads and long reads from the Corveo publication, alongside your program."
        static let pulseHeading = "The Pulse"
        static let pulseSub = "Short reads"
        static let inFocusHeading = "In Focus"
        static let inFocusSub = "Long reads"
        static func openPulseAria(_ title: String) -> String { "Open short read: \(title)" }
        static let contentPendingNotice = "Education content is being prepared and clinically reviewed by the Corveo team. Placeholder content is shown during development."
    }

    enum pulse {
        static func counter(_ n: Int, _ total: Int) -> String { "\(n) of \(total)" }
        static let closeAria = "Close"
        static let swipeHint = "Swipe up for the next read"
        static let pendingBody = "This read is being prepared and clinically reviewed by the Corveo team."
    }

    enum inFocus {
        static let back = "Learn"
        static let overline = "In Focus"
        static let notFound = "That article isn't available."
    }

    enum record {
        static let eyebrow = ProductCopy.myHeartRecord
        static let title = "Your record."
        static let historyHeading = "History"
    }

    enum readings {
        static let empty = "No readings yet. Your record begins with the first reading you add or share."
        static let sparse = "Your picture is building. Only a few readings so far."
        static let loadMore = "Show earlier readings"
        /// History shows the latest few; the rest unfold on request.
        static let showAll = "See all readings"
        static let showFewer = "Show fewer"
        static let addCta = "Add a reading"
        static let sourceHealth = "Apple Health"
        static let sourceManual = "Manual"
    }

    enum trend {
        static let intro = "Each point is a daily summary of your readings, shown exactly as recorded. The pattern across weeks is what's worth discussing with your doctor."
        static let oneWeek = "1W"
        static let sixWeeks = "6W"
        static let all = "All"
        static let rangeAria = "Trend range"
        /// The mean of the readings on screen. A summary, never a threshold or a target.
        static let averageWeek = "Average of this week"
        static let averageSixWeeks = "Average of these 6 weeks"
        static let averageAll = "Average of all your readings"
        static let chartAria = "Blood pressure readings over time, shown as recorded"
        static let legendSystolic = "Systolic"
        static let legendDiastolic = "Diastolic"
        static let empty = "Your trend appears once readings begin to arrive."
    }

    enum program {
        /// Stable one-line heading: the program's own name is the subheading.
        static let title = "Your program."
        static func weekLabel(_ n: Int) -> String { "Week \(n)" }
        static let lockedNote = "Opens as your program progresses."
        static func progress(_ read: Int, _ total: Int) -> String { "\(read) of \(total) read" }
        static func progressAria(_ read: Int, _ total: Int) -> String { "\(read) of \(total) chapters read" }
        static func duration(_ min: Int, _ medium: ChapterMedium) -> String { "\(min) min \(medium.rawValue)" }
        static let readLabel = "Read"
        static let contentPending = "Content pending"
        static let browseAll = "All programs"
        static func openChapterAria(_ n: Int, _ title: String) -> String { "Chapter \(n): \(title)" }

        enum rail {
            static let heading = "More programs"
            static let sub = "Follow to add"
            static let seeAll = "See all programs"
            static func followAria(_ t: String) -> String { "Follow \(t)" }
            static func unfollowAria(_ t: String) -> String { "Unfollow \(t)" }
            static func switchAria(_ t: String) -> String { "Switch to \(t)" }
            static func openAria(_ t: String) -> String { "About \(t)" }
        }
    }

    enum programIndex {
        static let title = "Programs"
        static let intro = "Guided sequences you can follow alongside your own record. Follow as many as you like."
        static let emptyIntro = "You are not following a program yet. Choose one to begin."
        static func chapterCount(_ n: Int, _ unit: String) -> String { "\(n) \(unit)s" }
        static let follow = "Follow"
        static let following = "Following"
        static let scopeNote = "Only the six-week program is part of this release. The others are shown so the library can be reviewed."
    }

    enum chapter {
        static let back = "Program"
        static let metaWeek = "Week"
        static func metaWeekValue(_ n: Int, _ total: Int) -> String { "\(n) of \(total)" }
        static let metaReadTime = "Estimated read time"
        static func metaReadTimeValue(_ min: Int) -> String { "\(min) minutes" }
        static let metaReview = "Clinical review"
        static let markRead = "Mark as read"
        static let markedRead = "Read"
        static let previous = "Previous chapter"
        static let next = "Next chapter"
        static let notFound = "That chapter isn't available."
    }

    enum manualEntry {
        static let eyebrow = "New reading"
        static let title = "Add a reading."
        static let timeNote = "Recorded readings keep the time you set here."
        static let cta = "Save reading"
        static let saveFailed = "The reading couldn't be saved. Please try again."
        static let consentRequired = "Your consent is needed before readings can be saved. Review consent in Settings."
    }

    enum settings {
        static let title = "Profile and settings"
        /// The page opens on the patient: where they are, how readings arrive, the rhythm chosen.
        enum profile {
            static let title = "You"
            static let programLabel = "Program"
            static func program(_ week: Int, _ total: Int) -> String { "Week \(week) of \(total)" }
            static let followingLabel = "Following"
            static let followingNone = "The six-week program only"
            static let readingsLabel = "Readings"
            static let readingsHealth = "Apple Health"
            static let readingsManual = "Entered by hand"
            static let readingsNone = "No monitor yet"
            static func readingCount(_ n: Int) -> String { n == 1 ? "1 reading" : "\(n) readings" }
            static let beganLabel = "Record began"
            static let beganNone = "With your first reading"
            static let rhythmLabel = "Rhythm"
            static let rhythmUnset = "Not chosen yet"
            static let consentLabel = "Consent"
            static func consentGiven(_ date: String, _ version: String) -> String { "Given \(date) (v\(version))" }
            static let consentNone = "Not recorded"
        }
        /// The menu: each row is a page of its own.
        static let menuAria = "Settings"
        enum menu {
            static let appleHealth = "Apple Health"
            static let about = "About this app"
            static let data = "Your data"
            static let monitors = "Arm monitors"
            static let reminders = "Reminders"
            static let account = "Account"
        }
        static let aboutTitle = "About this app"
        static let cuffsTitle = "Validated monitors"
        enum appleHealth {
            static let title = "Apple Health"
            static let readsOnly = "Corveo reads blood pressure only. It never writes."
            static let manageHint = "Manage access in Settings › Health › Data Access & Devices."
            static let statusLabel = "Status"
            static let connected = "Connected"
            static let paused = "Paused"
            static let lastLookedLabel = "Last checked"
            static let pauseCta = "Pause syncing"
            static let resumeCta = "Resume syncing"
            static let pauseNote = "Paused means Corveo stops looking for new readings. Nothing already in your record changes, and you can resume at any time."
            static let notConnected = "Not connected. You can connect Apple Health at any time."
            static let connectCta = "Connect Apple Health"
            static let disconnectCta = "Disconnect Apple Health"
            static let disconnectNote = "This stops BP Reset importing readings. It does not change Apple Health permissions."
        }
        enum yourData {
            static let title = "Your data"
            static let body = "Your readings are yours. Export or request deletion at any time."
            static let exportCta = "Export my record"
            static let exportNote = "Your full record as a file you can keep or share yourself."
            static let deleteCta = "Request deletion"
            static let deleteConfirmTitle = "Request deletion of your record?"
            static let deleteConfirmBody = "Your account and readings will be deleted. Health-records law sets a minimum retention period, and deletion is carried out and logged against it. This cannot be undone from the app."
            static let deleteConfirmCta = "Request deletion"
            static let deleteCancelCta = "Keep my record"
            static let deleteFailed = "Deletion could not be requested. Check your connection and try again. Nothing on this phone has been removed."
            static let consentMissing = "Your consent is not on record. Readings cannot be saved until it is."
            static let giveConsentCta = "Give consent"
            static func consentReceipt(_ version: String, _ date: String) -> String {
                "You gave express consent (v\(version)) on \(date)."
            }
        }
        enum account {
            static let title = "Account"
            static func signedInAs(_ email: String) -> String { "Signed in as \(email)." }
            static let signOutCta = "Sign out"
            static let signOutNote = "Readings waiting on this phone stay here, encrypted, until you sign in again."
        }
        enum demo {
            static let title = "Development"
            static let resetCta = "Reset synthetic data"
            static let note = "Development build only. Restores the synthetic dataset."
        }
    }
}

enum HealthSyncCopy {
    enum card {
        static let title = "Apple Health"
        static let connected = "Connected"
        static let backgroundUnavailable = "Connected. Background updates unavailable on this build."
        static let readsOnly = "Corveo reads blood pressure only. It never writes to Apple Health."
        static let waiting = "Waiting for your next reading."
        static func updated(_ when: String) -> String { "Updated \(when)" }
        static func arrived(_ n: Int) -> String { n == 1 ? "1 new reading from Apple Health" : "\(n) new readings from Apple Health" }
        static func pending(_ n: Int) -> String { n == 1 ? "1 reading waiting to upload" : "\(n) readings waiting to upload" }
        static func rejected(_ n: Int) -> String { n == 1 ? "1 reading could not be imported" : "\(n) readings could not be imported" }
        static func held(_ n: Int) -> String { n == 1 ? "1 reading is held from a previous sign-in" : "\(n) readings are held from a previous sign-in" }
        static let heldNote = "Held readings stay on this phone until that account signs in again. Discarding removes them from this phone only; Apple Health is unaffected."
        static let discardHeldCta = "Discard held readings"
        enum sync {
            static let idle = "Sync"
            static let busy = "Syncing"
            static let done = "Synced"
            static let aria = "Check Apple Health for new readings"
        }
    }
    static let openSettings = "Open BP Reset Settings"
}

enum JourneyCopy {
    /// Landing screen: the brand, a greeting, one action. Nothing to read yet.
    enum welcome {
        static let title = "Welcome."
        static let cta = "Get started"
    }

    enum intro {
        static let eyebrow = "Six-week program"
        static let title = "Understand your blood pressure."
        static let intro = "A calm, structured way to track your readings and learn about blood pressure, alongside the care of your own doctor."
        static let cards: [(title: String, body: String)] = [
            ("Why home readings matter",
             "Readings taken quietly at home, over weeks, build a fuller picture than any single measurement can. That picture is what you and your doctor can talk about."),
            ("How to measure well",
             "Seated, rested, arm supported at heart level. Same times each day. The program walks you through this in week one."),
            ("What this program is",
             "Six weeks of short, practical education about blood pressure, with your own readings organised alongside it. Corveo displays your readings and their history. It does not diagnose or replace your doctor."),
        ]
        static let cta = "Begin"
    }

    enum signup {
        static let eyebrow = "Your account"
        static let title = "A place for your record."
        static let intro = "Your readings are stored securely in your own record, in Australia, and stay yours. You can export or delete them at any time."
        static let emailLabel = "Email address"
        static let passwordLabel = "Password"
        static let adultAttestation = "I am 18 years or older."
        static let cta = "Create account"
        static let signInTitle = "Welcome back."
        static let signInIntro = "Sign in to your record."
        static let signInCta = "Sign in"
        static let haveAccount = "I already have an account"
        static let needAccount = "I need to create an account"
        static let attestIntro = "One thing before your record begins."
        static func confirmIntro(_ email: String) -> String {
            "We've sent a confirmation link to \(email). Open it, then come back and sign in."
        }
    }

    enum connect {
        static let eyebrow = "Your monitor"
        /// Link to the validated-cuff list from the no-monitor option.
        static let cuffsLink = "Choosing a monitor"
        static let title = "How will readings arrive?"
        static let intro = "Corveo organises readings from a validated upper-arm cuff. Choose how yours will come in. You can change this later in Settings."
        static let healthkitTitle = "My monitor's app connects to Apple Health"
        static let healthkitBody = "Your monitor's own app writes readings to Apple Health. Corveo reads them from there. It reads blood pressure only, and it never writes."
        static let manualTitle = "I'll enter readings myself"
        static let manualBody = "Manual entry takes about ten seconds per reading."
        static let noneTitle = "I don't have a monitor yet"
        static let noneBody = "That's fine. The education program starts either way. We'll show you a list of validated upper-arm cuffs worth considering."
        static let cta = "Continue"
    }

    enum healthAuth {
        static let eyebrow = "Apple Health"
        static let title = "Connect Apple Health."
        static let intro = "Corveo asks Apple Health for permission to read blood pressure readings. Apple will show you exactly what is shared. Corveo reads only. It never writes to Apple Health."
        static let cta = "Continue"
        static let skip = "Not now. I'll enter readings myself"
        /// Neutral nudge. Never imply denial.
        static let noSamplesNudge = "We haven't seen any readings yet. You can check Corveo's access in Settings › Health › Data Access & Devices."
        static let unavailable = "Apple Health isn't available on this device. You can still enter readings yourself."
    }

    enum firstCapture {
        static let skip = "Skip for now"
        /// Health users: the record begins when the sync does.
        static let skipHealth = "My readings come from Apple Health"
        static let eyebrow = "First reading"
        static let title = "A starting point."
        static let intro = "Enter your most recent reading. One reading is just a starting point. The picture builds over the coming weeks."
        static let systolicLabel = "Systolic (top)"
        static let diastolicLabel = "Diastolic (bottom)"
        static let timeLabel = "When was it taken?"
        static let armLabel = "Which arm?"
        static let armLeft = "Left"
        static let armRight = "Right"
        static let cta = "Save reading"
        static let healthkitWaiting = "Once your monitor's app syncs with Apple Health, readings will appear here on their own. You can also add one yourself now."
    }

    enum result {
        static let eyebrow = "Your record"
        static let title = "Your record has begun."
        static let body = "One reading is a starting point. The picture that matters is how your readings sit over the coming weeks. That pattern is what you and your doctor can talk about, alongside your care."
        static let cta = "Choose your rhythm"
    }

    enum cadence {
        static let eyebrow = "Your rhythm"
        static let title = "A light rhythm."
        static let intro = "A steady rhythm of readings builds the clearest record. Choose what fits your days. You can change this anytime."
        static let twiceDailyTitle = "Morning and evening"
        static let twiceDailyBody = "Suggested for the first two weeks of the program."
        static let dailyTitle = "Once a day"
        static let dailyBody = "A steady, sustainable record."
        static let fewWeeklyTitle = "A few times a week"
        static let fewWeeklyBody = "A lighter rhythm that still builds your picture."
        static let reminderNote = "Corveo can remind you at your chosen times. Reminders follow your rhythm only. They are never triggered by a reading."
        static let cta = "Go to My Heart Record"
    }
}

/// Express-consent step copy (Deliverable 5 + 13). STATUS: DRAFT. The final wording is
/// Corveo's. The version string and hash mechanics are real: consent_event stores a SHA-256
/// of the exact text shown, so this text must be frozen per release.
enum ConsentCopy {
    static let version = "0.1-draft"
    static let eyebrow = "Your consent"
    static let title = "Before your record begins."
    static let intro = "Corveo asks for your express consent to collect and store the blood pressure readings you choose to record. Please read this before continuing."
    static let points: [(title: String, body: String)] = [
        ("What is collected",
         "Blood pressure readings you enter or share through Apple Health, with the time and source of each reading, and your program progress."),
        ("Where it lives",
         "Your record is stored securely in Australia, in Corveo's systems. It is not sold, shared for advertising, or used to train AI models."),
        ("What Corveo does with it",
         "Corveo displays your readings back to you and organises them alongside the education program. Corveo does not analyse or interpret your readings and does not send them to any clinician."),
        ("Your control",
         "You can export your record or ask for it to be deleted at any time from Settings. Health-records law sets a minimum retention period; deletion is carried out against that, and every access to your record is logged."),
    ]
    static let checkboxLabel = "I have read and understood the above, and I expressly consent to Corveo collecting and storing my blood pressure readings as described."
    static let cta = "I consent"
    static let failed = "Your consent could not be recorded. Check your connection and try again."

    /// The exact text shown, joined the same way the web build joins it, so the hash matches
    /// across platforms for the same consent version.
    static var documentText: String {
        ([eyebrow, title, intro] + points.map { "\($0.title): \($0.body)" } + [checkboxLabel, cta])
            .joined(separator: "\n")
    }
}

/// Safety surface (Deliverable 12). STATUS: DRAFT. Final wording comes from Corveo.
enum SafetyCopy {
    static let eyebrow = "About this app"
    static let title = "What Corveo does, and doesn't do."
    static let doesTitle = "Corveo BP Reset:"
    static let does = [
        "Displays and organises the blood pressure readings you record with your own monitor",
        "Shows your readings and their history exactly as recorded",
        "Provides general education about blood pressure over a six-week program",
        "Keeps your record in your control, with export or deletion at any time",
    ]
    static let doesNotTitle = "It does not:"
    static let doesNot = [
        "Measure blood pressure. Your validated cuff does that",
        "Analyse, interpret, score or classify your readings",
        "Diagnose, treat, or monitor any condition",
        "Alert you or anyone else based on a reading's value",
        "Send your readings to a doctor or clinic",
        "Replace advice from your own doctor",
    ]
    static let seekAdvice = "If you are worried about a reading or how you feel, speak with your GP or cardiologist. If you feel seriously unwell, call 000."
    static let disclaimer = "Corveo BP Reset displays and plots your blood pressure readings and provides general education. It does not diagnose, treat, or replace advice from your doctor."
    /// Shown at the foot of every education chapter.
    static let educationNote = "This is general education and is not a substitute for personalised advice from your own clinician."
}

/// Validated upper-arm cuff list (Deliverable 8). Source: STRIDE BP (stridebp.org).
enum ValidatedCuffsCopy {
    static let eyebrow = "Choosing a monitor"
    static let title = "Validated upper-arm cuffs."
    static let intro = "Corveo recommends clinically validated upper-arm monitors. These models appear on the STRIDE BP validated device register. Corveo doesn't sell monitors and has no affiliation with any manufacturer."
    static let devices: [(brand: String, model: String, connectivity: String)] = [
        ("Omron", "HEM-7361T (Gold / Platinum)", "Bluetooth via OMRON connect → Apple Health"),
        ("Withings", "BPM Connect", "Wi-Fi / Bluetooth via Withings app → Apple Health"),
        ("Omron", "HEM-7156 (Standard)", "Manual entry"),
    ]
    static let sourceNote = "Validation status per STRIDE BP (stridebp.org), accessed August 2026."
}

// MARK: - Reminders (local notifications; rhythm only, never a reading)

enum ReminderCopy {
    /// The one notification. Identical every time; it carries no value and no verdict.
    static let title = "Time for a reading"
    static let body = "A quiet moment for your blood pressure reading. Open BP Reset when you're ready."

    enum journey {
        static let toggle = "Remind me at these times"
    }

    enum settings {
        static let title = "Reminders"
        static let body = "Reminders follow your rhythm only. They are never triggered by a reading."
        static let toggle = "Remind me"
        static let rhythmAria = "Reading rhythm"
        static let twiceDailyTimes = "Mornings at 8 am and evenings at 8 pm."
        static let dailyTimes = "Mornings at 8 am."
        static let fewWeeklyTimes = "Monday, Wednesday and Friday mornings at 8 am."
        static let noRhythm = "Choose a rhythm to set reminder times."
        static let deniedNote = "Notifications for BP Reset are off in iOS Settings. Turn them on there to receive reminders."
        static let openSettings = "Open iOS Settings"
        static let testCta = "Send a test reminder (10 seconds)"
        static func short(_ c: CadenceChoice) -> String {
            switch c {
            case .twiceDaily: return "Twice daily"
            case .daily: return "Once a day"
            case .fewWeekly: return "A few a week"
            }
        }
    }
}

// MARK: - Problems the capture pipeline can report (mechanism only, never a value)

enum HealthProblemCopy {
    static let consentRequired = "Your consent is needed before readings can be saved. Review consent in Settings."
    static let signInRequired = "Sign in again to keep saving readings."
    static let storeFault = "The reading store on this phone could not be opened. Readings in Apple Health are unaffected; reinstalling BP Reset may be needed."
    static let bindingHold = "Readings from a previous sign-in are waiting on this phone. They stay here until that account signs in again."
    static let rejectedAll = "The server could not accept the readings. They stay on this phone and will be retried."
    static let ackFailed = "Readings were sent but could not be marked as sent on this phone. They will be checked again."
    static let uploadFailed = "Readings could not be sent. They stay on this phone until the next check."
    static let notEnrolled = "Finish setting up your account before connecting Apple Health."
}

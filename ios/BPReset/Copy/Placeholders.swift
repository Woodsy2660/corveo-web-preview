import Foundation

/*
 PLACEHOLDER content — development only.

 The real six-week curriculum is authored, clinically reviewed and supplied by Corveo
 (Deliverable 7, client dependency 5) and replaces `programPlaceholderWeeks` verbatim. The
 programs catalogue and the publication library are change-request scope (CR-1): built so
 the information architecture can be reviewed, flagged off in release builds.

 Placeholder discipline: bodies exist only for purely descriptive topics. Anything
 answer-shaped (diet, caffeine, medication, cardiac recovery) is card metadata only and
 renders as pending. Placeholder text must never put words in Corveo's mouth on a clinical
 subject. Program content is static: it never varies with the reader's readings.
 */

enum ChapterMedium: String { case read, watch, listen }

struct ProgramSection: Hashable {
    let heading: String
    let body: [String]
}

struct ProgramChapter: Hashable, Identifiable {
    var id: Int { week }
    let week: Int
    let title: String
    let excerpt: String
    var deck: String? = nil
    let readMinutes: Int
    var medium: ChapterMedium = .read
    let reviewStatus: String
    /// Absent means the body content has not been supplied yet.
    var sections: [ProgramSection]? = nil
}

struct ProgramSummary: Hashable, Identifiable {
    var id: String { slug }
    let slug: String
    let title: String
    let description: String
    /// BP Reset runs to a weekly cadence; the library programs are chaptered.
    let unitLabel: String
    let chapters: [ProgramChapter]
    var core = false
}

private let pending = "Pending"

let programPlaceholderWeeks: [ProgramChapter] = [
    ProgramChapter(
        week: 1, title: "Understanding blood pressure",
        excerpt: "What the two numbers describe, and why readings vary through the day.",
        deck: "Every reading is two numbers taken at one moment. Knowing what each one describes makes the rest of the program easier to follow.",
        readMinutes: 3, reviewStatus: pending,
        sections: [
            ProgramSection(heading: "What the two numbers describe", body: [
                "A blood pressure reading is written as one number over another, in millimetres of mercury, mmHg. The first is systolic pressure, measured as the heart contracts. The second is diastolic pressure, measured as the heart relaxes between beats.",
                "Both are recorded together because they describe different parts of the same cycle. Your record keeps them as a pair, exactly as your monitor reported them.",
            ]),
            ProgramSection(heading: "Why one reading is only one moment", body: [
                "Blood pressure is not a fixed property like height. It shifts through the day and responds to posture, activity, conversation, caffeine, sleep and the time since you last moved.",
                "This is why the program asks you to record over weeks rather than to read anything into a single measurement. What a clinician looks at is the shape of a record over time, and that is what your doctor can discuss with you.",
            ]),
        ]),
    ProgramChapter(
        week: 2, title: "Measuring well",
        excerpt: "Position, timing and rhythm. How a good home reading is taken.",
        deck: "Home monitors are accurate when they are used consistently. Most of that is technique, and it takes a minute to learn.",
        readMinutes: 4, reviewStatus: pending,
        sections: [
            ProgramSection(heading: "Setting up", body: [
                "Use a validated upper-arm cuff sized to your arm. Sit with your back supported and both feet flat on the floor, and rest for a few minutes before starting. Place the cuff on bare skin, level with your heart, and keep your arm supported on a table.",
                "Stay quiet during the measurement. Talking, holding your arm up, or crossing your legs all change what the monitor records.",
            ]),
            ProgramSection(heading: "Building a rhythm", body: [
                "Recording at roughly the same times makes a record easier to read later. Many people take one reading in the morning and one in the evening, though the rhythm you chose during setup is the one to follow.",
                "If a reading looks unlike the others, take it again after a short rest and record both. Your record is meant to hold what happened, not a tidied version of it.",
            ]),
        ]),
    ProgramChapter(
        week: 3, title: "Reading your record",
        excerpt: "Why patterns over weeks matter more than any single reading.",
        deck: "Your record is a history, not a score. This chapter is about reading it as one.",
        readMinutes: 3, reviewStatus: pending,
        sections: [
            ProgramSection(heading: "What the trend view shows", body: [
                "The trend view plots a daily summary of the readings you have recorded, drawn exactly as they were entered. There are no bands, zones or colour coding on it, because Corveo does not assess your readings. It organises and displays them.",
                "Gaps in the line are days without a reading. They are not failures; they are simply days with nothing recorded.",
            ]),
            ProgramSection(heading: "What to bring to an appointment", body: [
                "A record covering several weeks gives your doctor more to work with than a handful of recent numbers. Export your record before an appointment if it helps, and note anything unusual about particular days.",
                "Any judgement about what your record means belongs with your own clinician, who knows your history and the rest of your care.",
            ]),
        ]),
    ProgramChapter(
        week: 4, title: "Everyday influences",
        excerpt: "Salt, sleep, movement and medication timing. What research has looked at.",
        deck: "A short tour of the everyday factors research has examined, and why none of them applies to everyone equally.",
        readMinutes: 5, reviewStatus: pending,
        sections: [
            ProgramSection(heading: "What has been studied", body: [
                "Blood pressure research has examined dietary sodium, sleep quality and duration, physical activity, alcohol, body weight and stress. Each has been studied across large populations, and the findings describe averages across groups rather than what will happen for one person.",
                "Medication timing has also been studied. If you take medication, the timing question is one for your prescriber, not something to change on your own.",
            ]),
            ProgramSection(heading: "Why individual answers come from your clinician", body: [
                "How much any of these matter for you depends on your history, your other conditions and your medication. That is knowledge your doctor holds and this app does not.",
                "The purpose of this chapter is to help you understand what is being discussed when these topics come up, so the conversation alongside your care is a more useful one.",
            ]),
        ]),
    ProgramChapter(
        week: 5, title: "Talking with your doctor",
        excerpt: "Bringing your record to appointments, and the questions worth asking.",
        deck: "Appointments are short. Arriving organised makes the time go further.",
        readMinutes: 4, reviewStatus: pending,
        sections: [
            ProgramSection(heading: "Before the appointment", body: [
                "Export your record, or have it open, so the history is available rather than remembered. Note the dates of anything that might be relevant: an illness, a change in medication, a period of poor sleep, a holiday.",
                "Write your questions down beforehand. It is easy to leave without asking the one that mattered.",
            ]),
            ProgramSection(heading: "Questions people commonly ask", body: [
                "What does my record suggest to you? How often should I be recording? Is my monitor a suitable one? Should anything about my medication change, and if so when would we review it? Is there anything in my record you would like me to watch for and report?",
                "These are prompts, not a script. Your clinician will have their own questions too.",
            ]),
        ]),
    ProgramChapter(
        week: 6, title: "Keeping the rhythm",
        excerpt: "Carrying the habit forward after the program ends.",
        deck: "The program finishes; the record does not have to.",
        readMinutes: 3, reviewStatus: pending,
        sections: [
            ProgramSection(heading: "After six weeks", body: [
                "The app stays available and your record stays yours. Many people keep recording at a lower frequency than during the program. Your clinician can tell you what suits your situation.",
                "Everything you have recorded remains exportable and deletable at any time, from Settings.",
            ]),
            ProgramSection(heading: "What Corveo will and won't do", body: [
                "Corveo will keep displaying and organising what you record, and will keep this education available to re-read.",
                "It will not tell you whether a reading is good or bad, will not alert anyone, and will not send your record to a clinic. Those boundaries are deliberate, and they are described in full under Settings.",
            ]),
        ]),
]

private func card(_ n: Int, _ title: String, _ excerpt: String, _ minutes: Int, _ medium: ChapterMedium = .read) -> ProgramChapter {
    ProgramChapter(week: n, title: title, excerpt: excerpt, readMinutes: minutes, medium: medium, reviewStatus: pending)
}

let coreProgramSlug = "bp-reset"

let programCatalogue: [ProgramSummary] = [
    ProgramSummary(
        slug: coreProgramSlug, title: "The six-week program",
        description: "Short, practical education about blood pressure, alongside the record you build yourself.",
        unitLabel: "Week", chapters: programPlaceholderWeeks, core: true),
    ProgramSummary(
        slug: "primary-prevention", title: "Primary prevention program",
        description: "A guided sequence covering the fundamentals of protecting your heart before problems start.",
        unitLabel: "Chapter", chapters: [
            card(1, "Understanding cholesterol", "What LDL and HDL describe, and what the numbers refer to.", 3),
            card(2, "Risk factors and screening", "What clinicians look at, and which checks happen when.", 5),
            card(3, "The evidence base", "A cardiologist-written look at what the research supports.", 6),
            card(4, "Movement and the heart", "What has been studied about activity and cardiovascular health.", 4),
            card(5, "Sleep and stress", "How the research treats rest, and where the evidence is thinner.", 4),
            card(6, "Bringing it together", "Where prevention sits alongside the rest of your care.", 3),
        ]),
    ProgramSummary(
        slug: "understanding-medication", title: "Understanding your medication",
        description: "What common heart medications do, why they are prescribed, and how to take them with confidence.",
        unitLabel: "Chapter", chapters: [
            card(1, "Why medication is prescribed", "The reasoning a prescriber works from.", 4),
            card(2, "Common classes explained", "What the main groups of heart medication do.", 6),
            card(3, "Taking them consistently", "Timing, routine, and what to raise at a review.", 4),
            card(4, "Questions for your prescriber", "What is worth asking, and when.", 3),
            card(5, "Reviews and changes", "How and why a prescription gets revisited.", 4),
        ]),
    ProgramSummary(
        slug: "life-after-a-cardiac-event", title: "Life after a cardiac event",
        description: "Practical, reassuring guidance for recovery and building sustainable heart-healthy habits.",
        unitLabel: "Chapter", chapters: [
            card(1, "The first weeks", "What recovery commonly involves, and who is involved in it.", 5),
            card(2, "Cardiac rehabilitation", "What a rehabilitation program is and how referral works.", 9, .watch),
            card(3, "Returning to activity", "How activity is usually reintroduced, and by whom it is guided.", 4),
            card(4, "Keeping the habit", "Carrying a routine forward once the program ends.", 4),
        ]),
    ProgramSummary(
        slug: "nutrition", title: "Nutrition for a healthy heart",
        description: "Evidence-based eating: what the research actually supports, minus the fad-diet noise.",
        unitLabel: "Chapter", chapters: [
            card(1, "What the research examines", "The dietary factors most studied in cardiovascular research.", 7),
            card(2, "Reading a food label", "What the numbers on a package describe.", 5),
            card(3, "Sodium in everyday food", "Where it turns up, and how it is measured.", 4),
            card(4, "Eating patterns, not rules", "Why research describes patterns rather than prescriptions.", 21, .listen),
            card(5, "Talking it through", "Bringing questions about diet to your own clinician.", 3),
        ]),
]

// MARK: - Publication library (The Pulse, In Focus)

struct PulseItem: Hashable, Identifiable {
    var id: String { slug }
    let slug: String
    let title: String
    var body: [String]? = nil
    let reviewStatus: String
}

struct InFocusArticle: Hashable, Identifiable {
    var id: String { slug }
    let slug: String
    let title: String
    let excerpt: String
    var deck: String? = nil
    let readMinutes: Int
    let reviewStatus: String
    var sections: [ProgramSection]? = nil
}

let pulseItems: [PulseItem] = [
    PulseItem(slug: "why-readings-vary", title: "Why readings vary through the day", body: [
        "Blood pressure is not a fixed property like height. It shifts with posture, activity, conversation, caffeine, sleep and the time since you last moved.",
        "That is why a record built over weeks says more than any single reading, and why your record keeps every reading exactly as your monitor reported it.",
    ], reviewStatus: pending),
    PulseItem(slug: "what-mmhg-measures", title: "What mmHg actually measures", body: [
        "Millimetres of mercury, mmHg, is a unit of pressure. Early monitors measured how far a column of mercury rose against a scale, and the unit outlived the mercury.",
        "A reading's two numbers use the same unit: pressure as the heart contracts, and pressure as it relaxes between beats.",
    ], reviewStatus: pending),
    PulseItem(slug: "the-white-coat-effect", title: "The white-coat effect", body: [
        "Readings taken in a clinic are often different from readings taken at home. The setting itself can change the measurement. Researchers call this the white-coat effect.",
        "It is one reason clinicians ask for home readings taken over time: a record built where you live shows a picture the clinic visit can't.",
    ], reviewStatus: pending),
    PulseItem(slug: "cuff-size-and-fit", title: "Cuff size and fit", reviewStatus: pending),
    PulseItem(slug: "morning-and-evening", title: "Morning and evening readings", reviewStatus: pending),
    PulseItem(slug: "home-records-in-clinic", title: "How clinicians use home records", reviewStatus: pending),
]

let inFocusArticles: [InFocusArticle] = [
    InFocusArticle(
        slug: "the-home-record-explained", title: "The home record, explained",
        excerpt: "What a record built at home contains, and why it is kept exactly as measured.",
        deck: "A home blood pressure record is a simple thing: readings, kept in order, exactly as your monitor reported them. This article walks through what that record contains and how it is kept.",
        readMinutes: 6, reviewStatus: pending,
        sections: [
            ProgramSection(heading: "What a record contains", body: [
                "Each entry in your record is one measurement: two pressures in mmHg, taken at one moment, by your own validated monitor. The app adds the time and the source, Apple Health or manual entry, and nothing else.",
                "Readings are never adjusted, smoothed or scored. What your monitor reported is what your record keeps.",
            ]),
            ProgramSection(heading: "Why order and time matter", body: [
                "A record is more than a pile of numbers. The sequence carries information. When each reading was taken, and what the record looks like across weeks, is what your own clinician can read and discuss with you.",
            ]),
            ProgramSection(heading: "Whose record it is", body: [
                "Yours. The record can be exported as a file at any time, and deletion can be requested from Settings. Nothing is sent to a doctor or clinic by the app.",
            ]),
        ]),
    InFocusArticle(slug: "how-a-monitor-works", title: "How a blood pressure monitor works",
                   excerpt: "What happens between the cuff inflating and the numbers appearing.", readMinutes: 7, reviewStatus: pending),
    InFocusArticle(slug: "what-a-clinician-looks-at", title: "What a clinician looks at in a record",
                   excerpt: "How home readings are read in clinic, and what makes a record useful.", readMinutes: 8, reviewStatus: pending),
    InFocusArticle(slug: "a-short-history-of-measurement", title: "A short history of measuring blood pressure",
                   excerpt: "From a column of mercury to the cuff on your kitchen table.", readMinutes: 5, reviewStatus: pending),
]

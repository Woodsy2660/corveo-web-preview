import Foundation

/// PLACEHOLDER photography for the preview, mirrored from the web reference's
/// src/assets/photos (Unsplash licence, chosen for mood, not meaning). Corveo's own artwork
/// replaces each image set verbatim.
enum Art {
    static func chapter(_ week: Int) -> String { "photo-week-\(min(max(week, 1), 6))" }

    static func program(_ slug: String) -> String {
        [
            "bp-reset": "photo-bp-reset",
            "primary-prevention": "photo-primary-prevention",
            "understanding-medication": "photo-understanding-medication",
            "life-after-a-cardiac-event": "photo-life-after-a-cardiac-event",
            "nutrition": "photo-nutrition",
        ][slug] ?? "photo-bp-reset"
    }

    static func article(_ slug: String) -> String {
        [
            "the-home-record-explained": "photo-home-record",
            "how-a-monitor-works": "photo-monitor-works",
            "what-a-clinician-looks-at": "photo-clinician",
            "a-short-history-of-measurement": "photo-history",
        ][slug] ?? "photo-history"
    }

    static func pulse(_ slug: String) -> String {
        [
            "why-readings-vary": "photo-alarm-clock",
            "what-mmhg-measures": "photo-history",
            "the-white-coat-effect": "photo-white-coat",
            "cuff-size-and-fit": "photo-week-2",
            "morning-and-evening": "photo-week-6",
            "home-records-in-clinic": "photo-clinician",
        ][slug] ?? "photo-history"
    }
}

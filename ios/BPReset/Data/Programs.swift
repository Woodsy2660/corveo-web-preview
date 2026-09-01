import Foundation
import Observation

/*
 Program catalogue and follow state.

 CONTRACT GAP (B-2/B-3, Ben's lane): `v_program_progress` is `{ current_week, completed_steps }`,
 one program, no identifier. Until the spec settles:
  - which programs you follow lives in UserDefaults (app state, not health data);
  - `completed_steps` keys are namespaced "<slug>:<n>" and the legacy "week-N" key is still
    read for the core program;
  - `current_week` gates the core program only. Library programs open in full.
 */

enum Programs {
    static let all = programCatalogue

    static func find(_ slug: String?) -> ProgramSummary? {
        all.first { $0.slug == slug }
    }

    static var core: ProgramSummary { find(coreProgramSlug)! }

    static func chapter(_ slug: String?, _ n: Int) -> ProgramChapter? {
        find(slug)?.chapters.first { $0.week == n }
    }

    /// Key used in `completed_steps`. Namespaced so several programs can coexist.
    static func stepKey(_ slug: String, _ n: Int) -> String { "\(slug):\(n)" }

    static func isRead(_ progress: ProgramProgressRow?, _ slug: String, _ n: Int) -> Bool {
        guard let steps = progress?.completedSteps else { return false }
        if steps[stepKey(slug, n)] == true { return true }
        return slug == coreProgramSlug && steps["week-\(n)"] == true
    }

    /// The core program releases a chapter a week; library programs open in full.
    static func isAvailable(_ progress: ProgramProgressRow?, _ program: ProgramSummary, _ n: Int) -> Bool {
        if !program.core { return true }
        return n <= (progress?.currentWeek ?? 1)
    }

    static func readCount(_ progress: ProgramProgressRow?, _ program: ProgramSummary) -> Int {
        program.chapters.filter { isRead(progress, program.slug, $0.week) }.count
    }
}

/// Which programs the reader follows, and which one the tab opens on. App state only.
@MainActor
@Observable
final class FollowState {
    private static let key = "corveo.programs.v1"

    private(set) var following: [String]
    private(set) var active: String

    init() {
        let d = UserDefaults.standard
        var following = d.stringArray(forKey: Self.key + ".following") ?? [coreProgramSlug]
        following = following.filter { Programs.find($0) != nil }
        if following.isEmpty { following = [coreProgramSlug] }
        let active = d.string(forKey: Self.key + ".active")
        self.following = following
        self.active = (active.flatMap { following.contains($0) ? $0 : nil }) ?? following[0]
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(following, forKey: Self.key + ".following")
        d.set(active, forKey: Self.key + ".active")
    }

    func isFollowing(_ slug: String) -> Bool { following.contains(slug) }

    func follow(_ slug: String) {
        guard !following.contains(slug) else { return }
        following.append(slug)
        save()
    }

    func unfollow(_ slug: String) {
        // The core program is what the app is for; it cannot be dropped.
        guard slug != coreProgramSlug else { return }
        following.removeAll { $0 == slug }
        if active == slug { active = following.first ?? coreProgramSlug }
        save()
    }

    func setActive(_ slug: String) {
        guard following.contains(slug) else { return }
        active = slug
        save()
    }

    func reset() {
        following = [coreProgramSlug]
        active = coreProgramSlug
        save()
    }
}

import Foundation

/*
 Synthetic reading fixtures.

 We never see real patient data (SOW A.12.3); synthetic fixtures are the only debugging
 surface this project will ever have. The generator is deterministic (seeded PRNG, the same
 mulberry32 the web build uses) and anchored to "now", so the demo never goes stale, and it
 deliberately covers the awkward cases: duplicate readings from two sources, skipped days,
 and mixed provenance.

 Deliberately NO systematic downward drift: a demo dataset that "improves" over the program
 would visually imply the program lowers blood pressure, an outcome claim the intended-purpose
 statement prohibits. The demo shows tracking, not results.
 */

struct Mulberry32 {
    private var a: UInt32
    init(seed: UInt32) { a = seed }
    mutating func next() -> Double {
        a = a &+ 0x6d2b_79f5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
}

enum Fixtures {
    static let tz = "Australia/Sydney"

    /// 42 days of readings for persona "synthetic Alex": stable baseline around 138/87 with
    /// natural variation, 4 to 6 readings a week with skipped days, roughly 70% HealthKit
    /// (Omron via Apple Health) and 30% manual.
    static func seedReadings(seed: UInt32 = 1337, days: Int = 42, now: Date = Date()) -> [BpReadingRow] {
        var rand = Mulberry32(seed: seed)
        var rows: [BpReadingRow] = []
        let cal = Calendar.current

        for daysAgo in stride(from: days, through: 0, by: -1) {
            if rand.next() < 0.3 { continue }               // real people miss days
            let baseSys = 138.0, baseDia = 87.0
            let readingsToday = rand.next() < 0.35 ? 2 : 1
            for i in 0..<readingsToday {
                let morning = i == 0 ? rand.next() < 0.7 : false
                let hour = morning ? 7 + Int(rand.next() * 2) : 19 + Int(rand.next() * 2)
                let minute = Int(rand.next() * 60)
                guard let dayDate = cal.date(byAdding: .day, value: -daysAgo, to: now),
                      let t = cal.date(bySettingHour: hour, minute: minute, second: 0, of: dayDate),
                      t <= now else { continue }
                let fromHealth = rand.next() < 0.7
                let sys = (baseSys + (rand.next() - 0.5) * 12).rounded()
                let dia = (baseDia + (rand.next() - 0.5) * 8).rounded()
                let arm = rand.next() < 0.9 ? "Left arm" : "Right arm"
                rows.append(BpReadingRow(
                    id: "fx-\(daysAgo)-\(i)",
                    effectiveTime: t,
                    effectiveTz: tz,
                    systolic: sys, diastolic: dia,
                    sourceType: fromHealth ? .healthkit : .manual,
                    sourceName: fromHealth ? "OMRON connect" : nil,
                    bodySiteDisplay: arm))
            }
        }

        // One deliberate near-duplicate mid-series: the same reading arriving from both the
        // cuff app (via Apple Health) and a manual entry in the same minute.
        if !rows.isEmpty {
            let mid = rows[rows.count / 2]
            rows.append(BpReadingRow(
                id: "\(mid.id)-manual-dup", effectiveTime: mid.effectiveTime, effectiveTz: mid.effectiveTz,
                systolic: mid.systolic, diastolic: mid.diastolic,
                sourceType: .manual, sourceName: nil, bodySiteDisplay: mid.bodySiteDisplay))
        }
        rows.sort { $0.effectiveTime < $1.effectiveTime }
        return rows
    }

    /// Daily aggregate matching the `v_bp_trend` shape. In production this is computed
    /// server-side; the mock derives it from the reading set so the two stay consistent.
    /// Buckets by the user's LOCAL calendar day.
    static func aggregateTrend(_ readings: [BpReadingRow]) -> [BpTrendRow] {
        var byDay: [String: [BpReadingRow]] = [:]
        for r in readings { byDay[Format.localDay(r.effectiveTime), default: []].append(r) }
        func round1(_ n: Double) -> Double { (n * 10).rounded() / 10 }
        return byDay.keys.sorted().map { day in
            let rs = byDay[day]!
            let sys = rs.map(\.systolic), dia = rs.map(\.diastolic)
            let mean: ([Double]) -> Double = { $0.reduce(0, +) / Double($0.count) }
            return BpTrendRow(
                day: day,
                minSystolic: sys.min()!, maxSystolic: sys.max()!, meanSystolic: round1(mean(sys)),
                minDiastolic: dia.min()!, maxDiastolic: dia.max()!, meanDiastolic: round1(mean(dia)),
                readingCount: rs.count)
        }
    }
}

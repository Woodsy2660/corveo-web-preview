import Foundation

#if DEBUG
/// Development builds only: six weeks of synthetic readings for a demo record, sent through
/// the ordinary ingest path as manual readings. The set is deterministic for a given end
/// date, so running it twice inserts nothing new (the server's dedup key absorbs the replay),
/// and every row carries a `demo-` source id so the whole set can be removed with one
/// statement later. Values are made up: they follow a gentle drift with day-to-day noise and
/// nothing about them is read back into the app.
enum DemoSeed {
    static let days = 42
    static let sourceUuidPrefix = "demo-"
    static let batchSize = 20

    /// Readings from `days - 1` days before `end` up to `end`, oldest first.
    static func observations(endingOn end: Date = Date(), calendar: Calendar = .current) -> [IngestObservation] {
        var out: [IngestObservation] = []
        let today = calendar.startOfDay(for: end)
        let keyFormat = DateFormatter()
        keyFormat.calendar = calendar
        keyFormat.timeZone = calendar.timeZone
        keyFormat.locale = Locale(identifier: "en_US_POSIX")
        keyFormat.dateFormat = "yyyyMMdd"

        for i in 0..<days {
            let daysAgo = days - 1 - i
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            var rand = Rand(seed: UInt64(i) &+ 11)
            if daysAgo != 0, rand.next() % 11 == 0 { continue }          // an empty day now and then

            let progress = Double(i) / Double(days - 1)                    // 0 oldest, 1 today
            let sysBase = 136.0 - 12.0 * progress
            let diaBase = 87.0 - 8.0 * progress
            let key = keyFormat.string(from: day)

            let morning = time(calendar, day, hour: 7, minute: 40, jitterMinutes: Int(rand.next() % 21))
            let morningSys = (sysBase + rand.noise(6)).rounded()
            let morningDia = (diaBase + rand.noise(4)).rounded()
            if morning <= end {
                out.append(make(key: key + "-am", at: morning, systolic: morningSys, diastolic: morningDia))
            }

            let hasEvening = daysAgo == 0 || rand.next() % 5 != 0
            guard hasEvening else { continue }
            let evening = time(calendar, day, hour: 20, minute: 10, jitterMinutes: Int(rand.next() % 31))
            let eveningSys = (sysBase + 3 + rand.noise(6)).rounded()
            let eveningDia = (diaBase + 2 + rand.noise(4)).rounded()
            if evening <= end {
                out.append(make(key: key + "-pm", at: evening, systolic: eveningSys, diastolic: eveningDia))
            }
        }
        return out
    }

    /// The ingest calls: manual source, `batchSize` readings each.
    static func payloads(_ observations: [IngestObservation]) -> [IngestPayload] {
        stride(from: 0, to: observations.count, by: batchSize).map { start in
            IngestPayload(sourceType: .manual,
                          observations: Array(observations[start..<min(start + batchSize, observations.count)]))
        }
    }

    private static func time(_ calendar: Calendar, _ day: Date, hour: Int, minute: Int, jitterMinutes: Int) -> Date {
        let base = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        return base.addingTimeInterval(TimeInterval(jitterMinutes * 60))
    }

    private static func make(key: String, at: Date, systolic: Double, diastolic: Double) -> IngestObservation {
        let tz = Format.localTzInfo(at)
        let uuid = sourceUuidPrefix + key
        return IngestObservation(
            sourceUuid: uuid,
            code: LOINC.bpPanel,
            effectiveTime: at,
            effectiveTz: tz.tz,
            effectiveOffsetMinutes: tz.offsetMinutes,
            sourceSystem: Bundle.main.bundleIdentifier ?? "dev.aiplease.bpreset",
            sourceName: nil,
            sourceDeviceModel: nil,
            sourceUserEntered: true,
            bodySiteCode: nil,
            context: [:],
            components: [
                IngestComponent(sourceUuid: uuid + "-sys", code: LOINC.systolic, valueQuantity: systolic, valueUnit: LOINC.unit),
                IngestComponent(sourceUuid: uuid + "-dia", code: LOINC.diastolic, valueQuantity: diastolic, valueUnit: LOINC.unit),
            ])
    }

    /// A tiny deterministic generator (SplitMix64), so the seed never depends on the run.
    private struct Rand {
        private var state: UInt64
        init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        /// Uniform in `-amplitude ... amplitude`.
        mutating func noise(_ amplitude: Double) -> Double {
            (Double(next() % 2001) / 1000.0 - 1.0) * amplitude
        }
    }
}
#endif

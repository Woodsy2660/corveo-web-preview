import SwiftUI
import Charts

// MARK: - Record tab (My Heart Record, Deliverables 4 and 6)

enum TrendRange: Hashable, CaseIterable {
    case twoWeeks, sixWeeks, all
    var days: Int? {
        switch self {
        case .twoWeeks: return 14
        case .sixWeeks: return 42
        case .all: return nil
        }
    }
    var label: String {
        switch self {
        case .twoWeeks: return AppCopy.trend.twoWeeks
        case .sixWeeks: return AppCopy.trend.sixWeeks
        case .all: return AppCopy.trend.all
        }
    }
}

/// The trend and the history on one screen. They are the same data at two grains; the chart
/// summarises the list and the list is the chart's detail. Both are display-only: no
/// thresholds, zones, bands or annotations. The two colours are fixed series identities.
struct RecordView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var range: TrendRange = .sixWeeks

    private var sinceDay: String? { range.days.map { Format.dayNDaysAgo($0) } }

    var body: some View {
        Screen(title: AppCopy.record.title, withTabBar: true,
               action: AnyView(ProfileLink { router.push(.settings) })) {
            AppleHealthCard()

            Text(AppCopy.trend.intro)
                .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.sm)

            HStack {
                Segmented(
                    options: TrendRange.allCases.map { ($0, $0.label) },
                    selection: $range,
                    ariaLabel: AppCopy.trend.rangeAria)
                Spacer()
                Button { router.push(.addReading) } label: {
                    Image(systemName: CIcon.plus)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(CColor.actionInk)
                        .frame(width: 40, height: 40)
                        .background(CColor.action, in: Circle())
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppCopy.readings.addCta)
            }
            .padding(.bottom, Spacing.sm)

            Card {
                if model.trendLoading && model.trend.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                } else if model.trend.isEmpty {
                    Text(AppCopy.trend.empty).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                } else {
                    BpChart(rows: model.trend)
                    HStack(spacing: Spacing.sm) {
                        legend(CColor.chartSeries1, AppCopy.trend.legendSystolic, square: false, dashed: false)
                        legend(CColor.chartSeries2, AppCopy.trend.legendDiastolic, square: true, dashed: true)
                    }
                    .padding(.top, Spacing.xxs)
                }
            }

            SectionHeading(text: AppCopy.record.historyHeading)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxs)

            if model.readingsLoading && model.readings.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else if model.readings.isEmpty {
                Card { Text(AppCopy.readings.empty).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary) }
            } else {
                if model.readings.count < 8 {
                    Text(AppCopy.readings.sparse)
                        .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                        .padding(.bottom, Spacing.xs)
                }
                VStack(spacing: Spacing.xxs) {
                    ForEach(model.readings) { reading in
                        ReadingRow(reading: reading)
                    }
                }
                if model.canLoadMoreReadings {
                    CButton(title: model.loadingMore ? AppCopy.common.busy : AppCopy.readings.loadMore,
                            variant: .ghost, disabled: model.loadingMore) {
                        Task { await model.loadMoreReadings() }
                    }
                    .padding(.top, Spacing.xs)
                }
            }
        }
        .task { await model.loadReadings() }
        .task(id: range) { await model.loadTrend(sinceDay: sinceDay) }
    }

    /// Series identity is carried three ways (colour, marker shape, line dash) so the chart
    /// reads without colour (rulebook §8.3). Colour is a fixed identity, never a value.
    private func legend(_ color: Color, _ label: String, square: Bool, dashed: Bool) -> some View {
        HStack(spacing: Spacing.xxxs) {
            ZStack {
                Path { p in p.move(to: CGPoint(x: 0, y: 5)); p.addLine(to: CGPoint(x: 20, y: 5)) }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [3, 2.5] : []))
                    .frame(width: 20, height: 10)
                if square {
                    Rectangle().fill(color).frame(width: 7, height: 7)
                } else {
                    Circle().fill(color).frame(width: 8, height: 8)
                }
            }
            Text(label).cText(TypeScale.label).foregroundStyle(CColor.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ReadingRow: View {
    let reading: BpReadingRow
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // Accessibility sizes stack, so the value never wraps mid-number (rulebook §8.3).
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    valueBlock
                    chips(alignment: .leading)
                }
            } else {
                HStack(alignment: .center) {
                    valueBlock
                    Spacer()
                    chips(alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(CColor.card, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text("\(Format.mmHg(reading.systolic))/\(Format.mmHg(reading.diastolic))")
                    .cText(TypeScale.bodyLg, weight: .medium).foregroundStyle(CColor.heading)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(AppCopy.common.unitMmHg).cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
            }
            Text(Format.dateTime(reading.effectiveTime)).cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
        }
    }

    private func chips(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Spacing.xxxs) {
            Chip(text: reading.sourceType == .healthkit ? AppCopy.readings.sourceHealth : AppCopy.readings.sourceManual)
            // Provenance exactly as HealthKit reported it: the writing app's name, never an
            // inference that it was a cuff (rulebook §4.6).
            if reading.sourceType == .healthkit, let name = reading.sourceName, !name.isEmpty { Chip(text: name) }
            // Most readings are left-arm; only flag the exception.
            if let site = reading.bodySiteDisplay, site != "Left arm" { Chip(text: site) }
        }
    }

    /// Spoken form per the rulebook §8.2: date, systolic, diastolic, provenance.
    private var accessibilityText: String {
        "\(Format.fullDate(reading.effectiveTime)). Systolic \(Format.mmHg(reading.systolic)) millimetres of mercury. Diastolic \(Format.mmHg(reading.diastolic)) millimetres of mercury. \(reading.sourceType == .healthkit ? "From Apple Health\(reading.sourceName.map { ", via \($0)" } ?? "")" : "Entered manually")."
    }
}

// MARK: - Chart (SOW Deliverable 6)

/// Gradient area treatment, two series overlaid (never stacked). Series colours are fixed
/// identities: systolic is always series 1, diastolic always series 2. No thresholds,
/// colour zones, bands, target ranges, or annotations that evaluate a value may be added
/// here; that is a contractual line (SOW A.3.3). The axis derives from the data, not from
/// a clinical scale.
struct BpChart: View {
    let rows: [BpTrendRow]
    var height: CGFloat = 220
    @State private var selected: Date? = nil

    private var domain: ClosedRange<Double> {
        let values = rows.flatMap { [$0.meanSystolic, $0.meanDiastolic] }
        let rawMin = values.min() ?? 0, rawMax = values.max() ?? 0
        let span = max(rawMax - rawMin, 10)
        let yMin = (floor((rawMin - span * 0.15) / 10) * 10)
        let yMax = (ceil((rawMax + span * 0.15) / 10) * 10)
        return yMin...yMax
    }

    private var yTicks: [Double] {
        let d = domain
        return [d.lowerBound, ((d.lowerBound + d.upperBound) / 2).rounded(), d.upperBound]
    }

    private var xTicks: [Date] {
        guard !rows.isEmpty else { return [] }
        if rows.count >= 3 { return [rows[0].date, rows[(rows.count - 1) / 2].date, rows[rows.count - 1].date] }
        return rows.map(\.date)
    }

    private var sparse: Bool { rows.count <= 2 }

    private var selectedRow: BpTrendRow? {
        guard let selected, !rows.isEmpty else { return nil }
        return rows.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }

    var body: some View {
        Chart {
            series(CColor.chartSeries1, "Systolic", square: false, dashed: false) { $0.meanSystolic }
            series(CColor.chartSeries2, "Diastolic", square: true, dashed: true) { $0.meanDiastolic }

            if let row = selectedRow {
                RuleMark(x: .value("Selected", row.date))
                    .foregroundStyle(CColor.hairline)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .center, spacing: 6) {
                        VStack(spacing: 0) {
                            Text(Format.date(row.date)).cText(TypeScale.label).foregroundStyle(CColor.textSecondaryInverse)
                            Text("\(Format.mmHg(row.meanSystolic))/\(Format.mmHg(row.meanDiastolic)) \(AppCopy.common.unitMmHg)")
                                .cMono(TypeScale.label).foregroundStyle(CColor.actionInk)
                        }
                        .padding(.horizontal, Spacing.xxs)
                        .padding(.vertical, Spacing.xxxs)
                        .background(CColor.action, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }
                PointMark(x: .value("Day", row.date), y: .value("mmHg", row.meanSystolic))
                    .symbol(.circle).foregroundStyle(CColor.chartSeries1).symbolSize(48)
                PointMark(x: .value("Day", row.date), y: .value("mmHg", row.meanDiastolic))
                    .symbol(.square).foregroundStyle(CColor.chartSeries2).symbolSize(48)
            }
        }
        .chartYScale(domain: domain, range: .plotDimension(startPadding: 4, endPadding: 12))
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { _ in
                AxisGridLine().foregroundStyle(CColor.hairline)
                AxisValueLabel().font(.system(size: 10, design: .monospaced)).foregroundStyle(CColor.inkTertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: xTicks) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), collisionResolution: .disabled)
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(CColor.inkTertiary)
            }
        }
        .chartXScale(range: .plotDimension(startPadding: 8, endPadding: 28))
        .chartPlotStyle { plot in plot.clipped() }
        .chartLegend(.hidden)
        .chartXSelection(value: $selected)
        .frame(height: height)
        .clipped()
        .accessibilityLabel(AppCopy.trend.chartAria)
    }

    @ChartContentBuilder
    private func series(_ color: Color, _ name: String, square: Bool, dashed: Bool,
                        _ pick: @escaping (BpTrendRow) -> Double) -> some ChartContent {
        let symbol: BasicChartSymbolShape = square ? .square : .circle
        let dash: [CGFloat] = dashed ? [5, 4] : []
        if sparse {
            ForEach(rows) { row in
                PointMark(x: .value("Day", row.date), y: .value("mmHg", pick(row)))
                    .symbol(symbol).foregroundStyle(color).symbolSize(40)
            }
        } else {
            ForEach(rows) { row in
                // Explicit baseline so the fill is bounded to the plot; monotone interpolation
                // never overshoots a recorded value.
                AreaMark(x: .value("Day", row.date),
                         yStart: .value("mmHg", domain.lowerBound),
                         yEnd: .value("mmHg", pick(row)),
                         series: .value("Series", name))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.linearGradient(colors: [color.opacity(0.28), color.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Day", row.date), y: .value("mmHg", pick(row)), series: .value("Series", name))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: dash))
            }
            if let last = rows.last {
                PointMark(x: .value("Day", last.date), y: .value("mmHg", pick(last)))
                    .symbol(symbol).foregroundStyle(color).symbolSize(40)
            }
        }
    }
}

// MARK: - Apple Health card

/// The Apple Health surface the patient actually sees: connected, reading only, when it
/// last looked, and a way to look now. It reports mechanism, never anything about a value,
/// and never a "denied" state the app is not entitled to claim.
struct AppleHealthCard: View {
    @Environment(HealthModel.self) private var health
    @State private var done = false

    var body: some View {
        if health.connected {
            Card {
                HStack(alignment: .firstTextBaseline) {
                    Text(HealthSyncCopy.card.title).cText(TypeScale.bodyBase, weight: .medium).foregroundStyle(CColor.heading)
                    Spacer()
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: CIcon.check).font(.system(size: 11, weight: .semibold)).foregroundStyle(CColor.surfaceColor1)
                        Text(HealthSyncCopy.card.connected).cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                    }
                }
                Text(health.backgroundUnavailable ? HealthSyncCopy.card.backgroundUnavailable : HealthSyncCopy.card.readsOnly)
                    .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                    .padding(.top, Spacing.xxxs)

                Hairline().padding(.top, Spacing.xs)

                HStack(spacing: Spacing.sm) {
                    Text(statusLine)
                        .cText(TypeScale.bodySm)
                        .foregroundStyle(health.lastArrived > 0 ? CColor.surfaceColor1 : CColor.inkTertiary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        Task {
                            await health.drain(trigger: .manual)
                            withAnimation(Motion.brand) { done = true }
                            try? await Task.sleep(nanoseconds: 2_200_000_000)
                            withAnimation(Motion.brand) { done = false }
                        }
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: done ? CIcon.check : CIcon.sync)
                                .font(.system(size: 13, weight: .medium))
                                .rotationEffect(.degrees(health.draining ? 360 : 0))
                                .animation(health.draining ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: health.draining)
                            Text(health.draining ? HealthSyncCopy.card.sync.busy : done ? HealthSyncCopy.card.sync.done : HealthSyncCopy.card.sync.idle)
                                .cText(TypeScale.bodySm, weight: .medium)
                        }
                        .foregroundStyle(done ? CColor.surfaceColor1 : CColor.heading)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .overlay(Capsule().stroke(done ? CColor.surfaceColor1 : CColor.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(health.draining)
                    .accessibilityLabel(HealthSyncCopy.card.sync.aria)
                }
                .padding(.top, Spacing.xs)

                if let problem = health.problemText {
                    Text(problem)
                        .cText(TypeScale.bodySm).foregroundStyle(CColor.ink)
                        .padding(.top, Spacing.xxs)
                }
                if health.status.rejectedCount > 0 {
                    Text(HealthSyncCopy.card.rejected(health.status.rejectedCount))
                        .cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                        .padding(.top, Spacing.xxs)
                }
            }
            .padding(.bottom, Spacing.sm)
            .onAppear { health.refresh() }
        }
    }

    private var statusLine: String {
        if health.lastArrived > 0 { return HealthSyncCopy.card.arrived(health.lastArrived) }
        if health.status.pendingCount > 0 { return HealthSyncCopy.card.pending(health.status.pendingCount) }
        if let at = health.lastDrainAt { return HealthSyncCopy.card.updated(Format.time(at)) }
        return HealthSyncCopy.card.waiting
    }
}

// MARK: - Manual entry (Deliverable 4)

/// Bounds are data quality only: the form catches typos and says nothing about what a
/// plausible value means. Writes through the same ingest path as the HealthKit drain.
struct ManualEntryForm: View {
    let ctaLabel: String
    let onSaved: (IngestResponse, SubmittedReading) -> Void

    @Environment(AppModel.self) private var model
    @State private var draft = ManualEntryDraft()
    @State private var takenAt = Date()
    @State private var arm = "left"
    @State private var showErrors = false
    @State private var formError: String? = nil
    @State private var saving = false

    private var errors: ManualEntryErrors { validateManualEntry(draft) }

    private func fieldError(_ field: FieldError?, cross: Bool = false) -> String? {
        guard showErrors else { return nil }
        if field != nil { return ValidationCopy.pleaseCheck }
        if cross, errors.cross != nil { return ValidationCopy.systolicGreater }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.xs) {
                CField(label: JourneyCopy.firstCapture.systolicLabel, text: $draft.systolic,
                       error: fieldError(errors.systolic), keyboard: .numberPad)
                CField(label: JourneyCopy.firstCapture.diastolicLabel, text: $draft.diastolic,
                       error: fieldError(errors.diastolic, cross: true), keyboard: .numberPad)
            }

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(JourneyCopy.firstCapture.timeLabel).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                DatePicker("", selection: $takenAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .environment(\.locale, Format.locale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .background(CColor.card, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(CColor.hairline, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(JourneyCopy.firstCapture.armLabel).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                HStack(spacing: Spacing.xxs) {
                    armButton("left", JourneyCopy.firstCapture.armLeft)
                    armButton("right", JourneyCopy.firstCapture.armRight)
                }
            }

            if let formError {
                Text(formError).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
            }

            CButton(title: saving ? AppCopy.common.busy : ctaLabel, disabled: saving) { Task { await save() } }
        }
    }

    private func armButton(_ value: String, _ label: String) -> some View {
        let on = arm == value
        return Button { arm = value } label: {
            Text(label)
                .cText(TypeScale.bodySm)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxs)
                .foregroundStyle(on ? CColor.actionInk : CColor.ink)
                .background(on ? CColor.action : CColor.card, in: Capsule())
                .overlay(Capsule().stroke(on ? CColor.heading : CColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private func save() async {
        showErrors = true
        formError = nil
        guard errors.isEmpty, let sys = Double(draft.systolic), let dia = Double(draft.diastolic) else { return }
        saving = true
        defer { saving = false }
        let payload = PayloadBuilder.manual(systolic: sys, diastolic: dia, takenAt: takenAt, arm: arm)
        let result: IngestResponse
        do {
            result = try await model.ingest(payload)
        } catch let e as APIError {
            if case .consentRequired = e { formError = AppCopy.manualEntry.consentRequired }
            else { formError = AppCopy.manualEntry.saveFailed }
            return
        } catch {
            formError = AppCopy.manualEntry.saveFailed
            return
        }
        // A duplicate means the reading is already in the record: treat as saved. Rejection
        // with nothing inserted means the values did not pass server-side bounds: stay on the
        // form with mechanical copy only.
        if result.inserted == 0 && result.duplicates == 0 {
            formError = ValidationCopy.pleaseCheck
            return
        }
        onSaved(result, SubmittedReading(systolic: sys, diastolic: dia, effectiveTime: takenAt, sourceType: .manual))
    }
}

struct ManualEntryView: View {
    @Environment(Router.self) private var router

    var body: some View {
        Screen(
            eyebrow: AppCopy.manualEntry.eyebrow,
            title: AppCopy.manualEntry.title,
            footer: AnyView(CButton(title: AppCopy.common.cancel, variant: .ghost) { router.pop() })
        ) {
            Text(AppCopy.manualEntry.timeNote)
                .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)
            ManualEntryForm(ctaLabel: AppCopy.manualEntry.cta) { _, _ in router.pop() }
        }
    }
}

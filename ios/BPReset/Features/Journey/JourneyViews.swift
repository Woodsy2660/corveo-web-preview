import SwiftUI

// MARK: - Flow

enum JourneyStep: Hashable {
    case signup, consent, connect, healthAuth, capture
    case result(SubmittedReading)
    case cadence
}

/// The five-step onboarding (SOW Deliverable 5): educate, account, consent, connect, first
/// capture, result-as-context, cadence. `/journey/*` bounces to the app once complete.
struct JourneyFlow: View {
    @State private var path: [JourneyStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(path: $path)
                .navigationDestination(for: JourneyStep.self) { step in
                    switch step {
                    case .signup: SignupView(path: $path)
                    case .consent: ConsentView(path: $path)
                    case .connect: ConnectView(path: $path)
                    case .healthAuth: HealthAuthView(path: $path)
                    case .capture: FirstCaptureView(path: $path)
                    case .result(let reading): ResultView(path: $path, submitted: reading)
                    case .cadence: CadenceView(path: $path)
                    }
                }
        }
    }
}

// MARK: - Step 1: educate

struct WelcomeView: View {
    @Binding var path: [JourneyStep]

    var body: some View {
        Screen(
            eyebrow: JourneyCopy.welcome.eyebrow,
            title: JourneyCopy.welcome.title,
            footer: AnyView(CButton(title: JourneyCopy.welcome.cta) { path.append(.signup) })
        ) {
            StepDots(total: 5, current: 1)
            Text(JourneyCopy.welcome.intro)
                .cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)

            VStack(spacing: Spacing.xs) {
                ForEach(JourneyCopy.welcome.cards, id: \.title) { card in
                    Card {
                        SectionHeading(text: card.title)
                            .padding(.bottom, Spacing.xxxs)
                        Text(card.body).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                    }
                }
            }

            Text(SafetyCopy.disclaimer)
                .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.md)
        }
    }
}

// MARK: - Step 2b: express consent

struct ConsentView: View {
    @Binding var path: [JourneyStep]
    @Environment(AppModel.self) private var model
    @State private var agreed = false
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        Screen(
            eyebrow: ConsentCopy.eyebrow,
            title: ConsentCopy.title,
            footer: AnyView(CButton(title: busy ? AppCopy.common.busy : ConsentCopy.cta, disabled: !agreed || busy) {
                Task {
                    busy = true
                    defer { busy = false }
                    // Consent is a server record, and every later write depends on it: the
                    // journey does not move on until it is recorded.
                    do {
                        try await model.recordConsent()
                        failed = false
                        path.append(.connect)
                    } catch {
                        failed = true
                    }
                }
            })
        ) {
            StepDots(total: 5, current: 2)
            Text(ConsentCopy.intro)
                .cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)

            VStack(spacing: Spacing.xs) {
                ForEach(ConsentCopy.points, id: \.title) { p in
                    Card {
                        SectionHeading(text: p.title).padding(.bottom, Spacing.xxxs)
                        Text(p.body).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                    }
                }
            }

            CheckRow(checked: $agreed, label: ConsentCopy.checkboxLabel)
                .padding(.top, Spacing.md)
            if failed {
                Text(ConsentCopy.failed).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                    .padding(.top, Spacing.xs)
            }
        }
    }
}

// MARK: - Step 3: connect

struct ConnectView: View {
    @Binding var path: [JourneyStep]
    @Environment(AppState.self) private var appState
    @Environment(HealthModel.self) private var health

    private var options: [(ConnectChoice, String, String)] {
        [
            (.healthkit, JourneyCopy.connect.healthkitTitle, JourneyCopy.connect.healthkitBody),
            (.manual, JourneyCopy.connect.manualTitle, JourneyCopy.connect.manualBody),
            (.none, JourneyCopy.connect.noneTitle, JourneyCopy.connect.noneBody),
        ]
    }

    var body: some View {
        Screen(
            eyebrow: JourneyCopy.connect.eyebrow,
            title: JourneyCopy.connect.title,
            footer: AnyView(CButton(title: JourneyCopy.connect.cta, disabled: appState.connectChoice == nil) {
                path.append(appState.connectChoice == .healthkit ? .healthAuth : .capture)
            })
        ) {
            StepDots(total: 5, current: 3)
            Text(JourneyCopy.connect.intro)
                .cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)

            VStack(spacing: Spacing.xs) {
                ForEach(options, id: \.0) { opt in
                    if opt.0 != .healthkit || health.isAvailable {
                        OptionCard(title: opt.1, body_: opt.2, selected: appState.connectChoice == opt.0) {
                            appState.connectChoice = opt.0
                        }
                    }
                }
            }

            if appState.connectChoice == .none {
                Card(label: ValidatedCuffsCopy.eyebrow) {
                    Text(ValidatedCuffsCopy.intro)
                        .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                        .padding(.bottom, Spacing.xs)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        ForEach(ValidatedCuffsCopy.devices, id: \.model) { d in
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(d.brand) \(d.model)").cText(TypeScale.bodySm, weight: .medium)
                                Text(d.connectivity).cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                            }
                        }
                    }
                    Text(ValidatedCuffsCopy.sourceNote)
                        .cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                        .padding(.top, Spacing.xs)
                }
                .padding(.top, Spacing.sm)
            }
        }
    }
}

// MARK: - Step 3b: Apple Health authorisation

/// Explainer in Corveo's own visual language, then the real iOS sheet (rulebook §4.4).
/// Both outcomes land in the same place: the app is never told the verdict.
struct HealthAuthView: View {
    @Binding var path: [JourneyStep]
    @Environment(HealthModel.self) private var health
    @State private var requesting = false

    var body: some View {
        Screen(
            eyebrow: JourneyCopy.healthAuth.eyebrow,
            title: JourneyCopy.healthAuth.title,
            footer: AnyView(VStack(spacing: Spacing.xs) {
                CButton(title: requesting ? AppCopy.common.busy : JourneyCopy.healthAuth.cta, disabled: requesting) {
                    Task {
                        requesting = true
                        defer { requesting = false }
                        await health.connect()
                        path.append(.capture)
                    }
                }
                CButton(title: JourneyCopy.healthAuth.skip, variant: .ghost) { path.append(.capture) }
            })
        ) {
            StepDots(total: 5, current: 3)
            Text(health.isAvailable ? JourneyCopy.healthAuth.intro : JourneyCopy.healthAuth.unavailable)
                .cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
        }
    }
}

// MARK: - Step 4: first capture

struct FirstCaptureView: View {
    @Binding var path: [JourneyStep]
    @Environment(AppState.self) private var appState

    var body: some View {
        // A visible way past this step: a reading is never required to finish onboarding, so
        // nobody without a monitor has to invent one (rulebook 5.1.1; the record holds only
        // what was measured).
        Screen(eyebrow: JourneyCopy.firstCapture.eyebrow, title: JourneyCopy.firstCapture.title,
               footer: AnyView(CButton(title: JourneyCopy.firstCapture.skip, variant: .ghost) { path.append(.cadence) })) {
            StepDots(total: 5, current: 4)
            Text(JourneyCopy.firstCapture.intro)
                .cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)

            if appState.connectChoice == .healthkit {
                Card {
                    Text(JourneyCopy.firstCapture.healthkitWaiting)
                        .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                }
                .padding(.bottom, Spacing.sm)
            }

            ManualEntryForm(ctaLabel: JourneyCopy.firstCapture.cta) { _, submitted in
                path.append(.result(submitted))
            }
        }
    }
}

// MARK: - Step 4b: result as context

/// Shows the just-saved reading in the context of the program: exactly as recorded, no
/// evaluation of any kind.
struct ResultView: View {
    @Binding var path: [JourneyStep]
    let submitted: SubmittedReading

    var body: some View {
        Screen(
            eyebrow: JourneyCopy.result.eyebrow,
            title: JourneyCopy.result.title,
            footer: AnyView(CButton(title: JourneyCopy.result.cta) { path.append(.cadence) })
        ) {
            StepDots(total: 5, current: 4)

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(Format.mmHg(submitted.systolic))
                    Text(" / ").foregroundStyle(CColor.inkTertiary)
                    Text(Format.mmHg(submitted.diastolic))
                }
                .cDisplay(TypeScale.specialLg)
                .foregroundStyle(CColor.heading)
                Text(AppCopy.common.unitMmHg).eyebrow().padding(.top, Spacing.xxs)
                HStack(spacing: Spacing.xxs) {
                    Chip(text: submitted.sourceType == .healthkit ? AppCopy.readings.sourceHealth : AppCopy.readings.sourceManual)
                    Chip(text: Format.dateTime(submitted.effectiveTime))
                }
                .padding(.top, Spacing.sm)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.md)
            .background(CColor.card, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))

            Text(JourneyCopy.result.body)
                .cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                .padding(.top, Spacing.md)
        }
    }
}

// MARK: - Step 5: cadence

/// Reminders (local notifications, P6) follow this chosen rhythm only; they are never
/// triggered by a reading's value (SOW A.3.3).
struct CadenceView: View {
    @Binding var path: [JourneyStep]
    @Environment(AppState.self) private var appState
    @Environment(AppModel.self) private var model
    @Environment(ReminderModel.self) private var reminders
    @State private var busy = false
    @State private var remind = true

    private var options: [(CadenceChoice, String, String)] {
        [
            (.twiceDaily, JourneyCopy.cadence.twiceDailyTitle, JourneyCopy.cadence.twiceDailyBody),
            (.daily, JourneyCopy.cadence.dailyTitle, JourneyCopy.cadence.dailyBody),
            (.fewWeekly, JourneyCopy.cadence.fewWeeklyTitle, JourneyCopy.cadence.fewWeeklyBody),
        ]
    }

    var body: some View {
        Screen(
            eyebrow: JourneyCopy.cadence.eyebrow,
            title: JourneyCopy.cadence.title,
            footer: AnyView(CButton(title: JourneyCopy.cadence.cta, disabled: appState.cadence == nil || busy) {
                Task {
                    busy = true
                    defer { busy = false }
                    // The system prompt appears once, here, after the explanation on screen.
                    if remind { await reminders.enable(cadence: appState.cadence) }
                    // Marks the journey done without touching the week: a returning patient
                    // who re-runs onboarding keeps their place in the program.
                    await model.updateProgress(completedSteps: ["journey": true])
                    appState.completeJourney()
                }
            })
        ) {
            StepDots(total: 5, current: 5)
            Text(JourneyCopy.cadence.intro)
                .cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)

            VStack(spacing: Spacing.xs) {
                ForEach(options, id: \.0) { opt in
                    OptionCard(title: opt.1, body_: opt.2, selected: appState.cadence == opt.0) {
                        appState.cadence = opt.0
                    }
                }
            }

            CheckRow(checked: $remind, label: ReminderCopy.journey.toggle)
                .padding(.top, Spacing.md)
            Text(JourneyCopy.cadence.reminderNote)
                .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.xs)
        }
    }
}

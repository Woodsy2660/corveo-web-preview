import SwiftUI

// MARK: - Journey step 2: account

private enum AuthMode { case create, signIn, attest, confirmEmail }

/// Account creation with email and password, the 18+ attestation, and the enrolment call.
/// Returning patients switch to sign in. With no backend configured the step is simulated,
/// exactly as the web preview does.
struct SignupView: View {
    @Binding var path: [JourneyStep]
    @Environment(SessionModel.self) private var session

    @State private var mode: AuthMode = .create
    @State private var email = ""
    @State private var password = ""
    @State private var adult = false
    @State private var busy = false

    private var canContinue: Bool {
        switch mode {
        case .create: return email.contains("@") && (session.hasBackend ? password.count >= 6 : true) && adult
        case .signIn: return email.contains("@") && password.count >= 6
        case .attest: return adult
        case .confirmEmail: return true
        }
    }

    private var cta: String {
        switch mode {
        case .create: return JourneyCopy.signup.cta
        case .signIn: return JourneyCopy.signup.signInCta
        case .attest: return JourneyCopy.connect.cta
        case .confirmEmail: return JourneyCopy.signup.signInCta
        }
    }

    var body: some View {
        Screen(
            overline: JourneyCopy.signup.eyebrow,
            title: mode == .signIn ? JourneyCopy.signup.signInTitle : JourneyCopy.signup.title,
            footer: AnyView(VStack(spacing: Spacing.xs) {
                CButton(title: busy ? AppCopy.common.busy : cta, disabled: !canContinue || busy) { Task { await proceed() } }
                if session.hasBackend, mode == .create || mode == .signIn {
                    CButton(title: mode == .create ? JourneyCopy.signup.haveAccount : JourneyCopy.signup.needAccount, variant: .ghost) {
                        withAnimation(Motion.brand) { mode = mode == .create ? .signIn : .create }
                    }
                }
            })
        ) {
            StepDots(total: 5, current: 1)
            Text(intro)
                .cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                if mode == .create || mode == .signIn {
                    CField(label: JourneyCopy.signup.emailLabel, text: $email, keyboard: .emailAddress, contentType: .emailAddress)
                    if session.hasBackend {
                        CField(label: JourneyCopy.signup.passwordLabel, text: $password,
                               contentType: mode == .create ? .newPassword : .password, secure: true)
                    }
                }
                if mode == .create || mode == .attest {
                    CheckRow(checked: $adult, label: JourneyCopy.signup.adultAttestation)
                }
                if let err = session.lastError {
                    Text(err).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                }
            }

        }
        .task {
            // A returning, already signed-in patient who has not finished the journey.
            if session.hasBackend, session.isSignedIn {
                mode = session.enrolled ? .create : .attest
                if session.enrolled { path.append(.consent) }
            }
        }
    }

    private var intro: String {
        switch mode {
        case .create: return JourneyCopy.signup.intro
        case .signIn: return JourneyCopy.signup.signInIntro
        case .attest: return JourneyCopy.signup.attestIntro
        case .confirmEmail: return JourneyCopy.signup.confirmIntro(email)
        }
    }

    private func proceed() async {
        busy = true
        defer { busy = false }
        switch mode {
        case .create:
            if await session.signUp(email: email, password: password) {
                if await session.enrol(adultAttested: adult) { path.append(.consent) }
            } else if session.pendingConfirmation {
                withAnimation(Motion.brand) { mode = .confirmEmail }
            }
        case .signIn, .confirmEmail:
            if mode == .confirmEmail { mode = .signIn; return }
            if await session.signIn(email: email, password: password) {
                if session.enrolled {
                    path.append(.consent)
                } else {
                    withAnimation(Motion.brand) { mode = .attest }
                }
            }
        case .attest:
            if await session.enrol(adultAttested: adult) { path.append(.consent) }
        }
    }
}

// MARK: - Returning patient, journey already complete

struct SignInView: View {
    @Environment(SessionModel.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false

    var body: some View {
        Screen(
            overline: JourneyCopy.signup.eyebrow,
            title: JourneyCopy.signup.signInTitle,
            footer: AnyView(CButton(title: busy ? AppCopy.common.busy : JourneyCopy.signup.signInCta,
                                    disabled: busy || !email.contains("@") || password.count < 6) {
                Task {
                    busy = true
                    defer { busy = false }
                    _ = await session.signIn(email: email, password: password)
                }
            })
        ) {
            Text(JourneyCopy.signup.signInIntro)
                .cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                CField(label: JourneyCopy.signup.emailLabel, text: $email, keyboard: .emailAddress, contentType: .emailAddress)
                CField(label: JourneyCopy.signup.passwordLabel, text: $password, contentType: .password, secure: true)
                if let err = session.lastError {
                    Text(err).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                }
            }
        }
    }
}

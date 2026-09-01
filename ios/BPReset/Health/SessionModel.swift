import Foundation
import Observation
import Supabase

/// Who is signed in, and the enrolment the plugin binds to.
///
/// With a backend configured this wraps Supabase Auth (email + password; the session lives in
/// the Keychain, this device only). Without one it is a stand-in so the journey still runs on
/// the synthetic mock. Screens read `isSignedIn`, `enrolled` and `pendingConfirmation`; they
/// never touch the client.
@MainActor
@Observable
final class SessionModel {
    private let client: SupabaseClient?
    private let api: SupabaseAPI?
    private let appState: AppState

    private(set) var restored = false
    private(set) var isSignedIn = false
    private(set) var email: String? = nil
    /// The auth user exists but the address is not yet confirmed (dev project setting).
    private(set) var pendingConfirmation = false
    /// An `app_user` row exists for this auth user (`enrol_patient` has run).
    private(set) var enrolled = false
    private(set) var lastError: String? = nil

    var hasBackend: Bool { client != nil }

    init(client: SupabaseClient?, appState: AppState) {
        self.client = client
        self.api = client.map(SupabaseAPI.init(client:))
        self.appState = appState
        if client == nil {
            // Mock mode: the journey's signup step marks the enrolment locally.
            restored = true
            isSignedIn = true
            enrolled = appState.programStartedAt != nil
        }
    }

    // MARK: Launch

    func restore() async {
        guard let client else { restored = true; return }
        defer { restored = true }
        if let session = try? await client.auth.session {
            isSignedIn = true
            email = session.user.email
            await loadEnrolment()
        } else {
            isSignedIn = false
        }
    }

    // MARK: Sign up / sign in / sign out

    /// Returns true when a session exists immediately; false when email confirmation is
    /// pending and the person has to come back and sign in.
    @discardableResult
    func signUp(email: String, password: String) async -> Bool {
        guard let client else { return true }
        lastError = nil
        do {
            switch try await client.auth.signUp(email: email, password: password) {
            case .session(let session):
                isSignedIn = true
                self.email = session.user.email
                pendingConfirmation = false
                return true
            case .user:
                pendingConfirmation = true
                self.email = email
                return false
            }
        } catch {
            lastError = Self.describe(error)
            return false
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        guard let client else { return true }
        lastError = nil
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            isSignedIn = true
            pendingConfirmation = false
            self.email = session.user.email
            await loadEnrolment()
            return true
        } catch {
            lastError = Self.describe(error)
            return false
        }
    }

    func signOut() async {
        if let client { try? await client.auth.signOut() }
        isSignedIn = hasBackend ? false : true
        enrolled = hasBackend ? false : enrolled
        email = nil
    }

    // MARK: Enrolment

    /// `enrol_patient` creates the `app_user` row (the only moment the adult attestation is
    /// recorded) and returns its id. The tuple the engine binds to is that id plus the row's
    /// server-side `created_at`.
    func enrol(adultAttested: Bool) async -> Bool {
        guard let api else {
            appState.markEnrolled()
            enrolled = true
            return true
        }
        lastError = nil
        do {
            _ = try await api.enrol(displayName: nil, adultAttested: adultAttested)
            await loadEnrolment()
            return enrolled
        } catch {
            lastError = Self.describe(error)
            return false
        }
    }

    func loadEnrolment() async {
        guard let api else { return }
        if let me = try? await api.currentAppUser() {
            appState.setEnrolment(ref: me.id, start: me.createdAt)
            enrolled = true
        } else {
            enrolled = false
        }
    }

    private static func describe(_ error: Error) -> String {
        if let e = error as? AuthError { return e.localizedDescription }
        return error.localizedDescription
    }
}

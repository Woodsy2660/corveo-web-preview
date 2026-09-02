import Foundation

/// Build-time configuration, read once from Info.plist. The values are injected by
/// `Secrets.xcconfig` (gitignored, generated from `.env.local` by `ios/gen-secrets.sh`).
/// Only the non-production URL and the anon/publishable key ever reach the bundle; the
/// service_role key never does. When no backend is configured the app runs on the
/// synthetic mock, exactly like the web preview.
enum AppConfig {
    enum Environment: String { case local, dev, staging, prod }

    private static func plist(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static let supabaseURL: URL? = {
        let raw = plist("SupabaseURL")
        guard raw.hasPrefix("https://"), let url = URL(string: raw) else { return nil }
        return url
    }()

    static let supabasePublishableKey: String = plist("SupabasePublishableKey")

    static let environment: Environment = Environment(rawValue: plist("AppEnvironment")) ?? .local

    /// True when a backend is configured. Screens never branch on this; the API factory does.
    static var hasSupabase: Bool { supabaseURL != nil && !supabasePublishableKey.isEmpty }

    /// Change-request surfaces (the Learn tab, the programs library and rail) ship only once
    /// the CR is signed (plan N-12). `CR_SCOPE_ENABLED` in Signing.xcconfig is YES for Debug,
    /// NO for Release; an absent key falls back the same way.
    static let crScopeEnabled: Bool = {
        let raw = plist("CRScopeEnabled").uppercased()
        if raw.isEmpty {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
        return raw == "YES" || raw == "TRUE" || raw == "1"
    }()

    /// Release builds must never point at the dev project or ship the synthetic mock.
    /// Asserted at launch in DEBUG; a production build gate belongs in the archive checklist.
    static var isProductionShaped: Bool { environment == .prod && hasSupabase }
}

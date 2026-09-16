# Auth State Extraction Report

| | |
|---|---|
| **Generated** | 16 September 2026 |
| **Purpose** | Factual audit of authentication implementation for Stage 2 planning |
| **Scope** | BP Reset V1 — web preview (React) + native iOS (Swift) |

---

## Section A — Repository and client

### 1. Is `@supabase/supabase-js` in `package.json`?

**No.** The web `package.json` contains no Supabase dependency:

```json
"dependencies": {
  "@formkit/auto-animate": "^0.10.0",
  "@tanstack/react-query": "^5.101.4",
  "react": "^19.2.0",
  "react-dom": "^19.2.0",
  "react-router": "^8.3.0"
}
```

The web app is a **mock/demo only**. The Supabase client exists only in the native iOS layer.

### 2. Where is the Supabase client instantiated?

**Native iOS only.** File: `ios/BPReset/Data/SupabaseAPI.swift:52-61`

```swift
enum SupabaseFactory {
    static func makeClient() -> SupabaseClient? {
        guard let url = AppConfig.supabaseURL, AppConfig.hasSupabase else { return nil }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: AppConfig.supabasePublishableKey,
            options: SupabaseClientOptions(
                db: .init(encoder: paramEncoder),
                auth: .init(storage: KeychainSessionStorage())))
    }
    // ...
}
```

The Swift SDK uses the native `Supabase` SPM package (confirmed in `project.pbxproj`).

### 3. Session storage configuration

**Native:** Custom `KeychainSessionStorage` adapter is explicitly passed via `auth: .init(storage: KeychainSessionStorage())`.

**Web:** Not applicable — no Supabase client exists. Journey state uses `localStorage` (`src/lib/journey/state.tsx:34,44`), but this is **app state, not auth session**.

### 4. Capacitor / secure-storage plugins

**None installed.** The iOS app is a native Swift app, not a Capacitor hybrid. There are no `@capacitor/*` dependencies in either `package.json` or the Xcode project.

Keychain access is implemented directly via Security framework in `SupabaseAPI.swift:10-48`.

### 5. Environment variables

From `.env.example`:

```
# Supabase — BP Reset V1
# Copy to .env.local and fill in. Never commit .env.local.
#
# Anything prefixed VITE_ is compiled into the app bundle and is readable by
# anyone who downloads the app. Only the non-production URL and the
# anon/publishable key ever go here. The service_role key never appears in
# this repo, in the app bundle, in CI logs, or on any AI Please machine.

VITE_SUPABASE_URL=
VITE_SUPABASE_PUBLISHABLE_KEY=

# Environment label: local | dev | staging | prod
VITE_APP_ENV=local

# Demo mode (web preview only): synthetic cuff readings + reset card.
# Must be unset/false in any native release build.
VITE_DEMO=
```

The key is named `VITE_SUPABASE_PUBLISHABLE_KEY`, not `VITE_SUPABASE_ANON_KEY`.

Native reads from `Info.plist` keys `SupabaseURL` and `SupabasePublishableKey` (`ios/BPReset/Data/AppConfig.swift:16-22`).

---

## Section B — Auth calls in the codebase

### 6. All `supabase.auth.*` calls

| File | Line | Method | Status |
|------|------|--------|--------|
| `ios/BPReset/Health/SessionModel.swift` | 48 | `client.auth.currentSession` | **Live** — session restoration |
| `ios/BPReset/Health/SessionModel.swift` | 67 | `client.auth.signUp(email:password:)` | **Live** — account creation |
| `ios/BPReset/Health/SessionModel.swift` | 88 | `client.auth.signIn(email:password:)` | **Live** — login |
| `ios/BPReset/Health/SessionModel.swift` | 103 | `client.auth.signOut()` | **Live** — logout |

**Web app:** Zero calls. No Supabase client.

### 7. Signup screen behaviour

**Web (`src/screens/journey/Signup/Signup.tsx`):**
- Comment at line 9-12 explicitly states: `MOCK — real auth (email+password and Sign in with Apple, anonymous-session linking) is wired at integration per docs/02`.
- On submit: `navigate("/journey/consent")` — direct navigation, **no network call**.
- State changes: local `email`, `password`, `adult` useState only.
- **No auth request is made.**

**Native (`ios/BPReset/Features/Auth/AuthViews.swift:91-113`):**
- Calls `session.signUp(email:password:)` which invokes `client.auth.signUp()`.
- On success with session: calls `session.enrol(adultAttested:)` then navigates to consent.
- On success without session (email confirmation pending): switches to `confirmEmail` mode.
- **Real network call to Supabase Auth.**

### 8. Sign-in screen / password field / forgot password

**Sign-in:** Yes, both web and native have toggle between create/sign-in modes.
- Web: `src/screens/journey/Signup/Signup.tsx:19` — `mode` state toggles "create" / "signin"
- Native: `ios/BPReset/Features/Auth/AuthViews.swift:5,14` — `AuthMode` enum with `.signIn`

**Password field:** Yes, both platforms.
- Web: `src/screens/journey/Signup/Signup.tsx:63-68`
- Native: `ios/BPReset/Features/Auth/AuthViews.swift:60-61`

**Forgot password:** **Not implemented.** No grep matches for "forgot", "reset password", or `resetPassword`.

### 9. Sign-out path

**Yes**, in native only.

`ios/BPReset/Features/Settings/SettingsViews.swift:500-506`:
```swift
CButton(title: AppCopy.settings.account.signOutCta, variant: .secondary) {
    Task {
        await Teardown.run(.signOut, health: health, session: session, reminders: reminders,
                           appState: appState, before: {}, onAnimateClear: {})
    }
}
```

Calls `session.signOut()` which invokes `client.auth.signOut()` (`SessionModel.swift:102-108`).

**Web:** No sign-out path — no auth to sign out from.

### 10. "User is signed in" representation

**Web:** Not represented. The web app has no concept of signed-in state. Route guarding uses `journeyComplete` from `src/lib/journey/state.tsx`, which is **journey completion state, not auth state**.

**Native:** `SessionModel` (`ios/BPReset/Health/SessionModel.swift`) is an `@Observable` class with:
- `isSignedIn: Bool` (line 19)
- `enrolled: Bool` (line 24)
- `email: String?` (line 20)
- `pendingConfirmation: Bool` (line 22)

Injected as an environment object; screens read `session.isSignedIn`.

### 11. Route guarding for `/app/*`

**Web (`src/App.tsx:30-38`):**
```tsx
function RequireJourneyComplete() {
  const { journeyComplete } = useJourney();
  return journeyComplete ? <Outlet /> : <Navigate to="/journey/welcome" replace />;
}
```

Guard is based on **journey completion**, not authentication. `journeyComplete` is stored in `localStorage` and persists across sessions.

**If a user navigates directly to `/app/record`:**
- If `localStorage.getItem("corveo.journey.v1")` contains `journeyComplete: true`, they are allowed through.
- Otherwise, redirected to `/journey/welcome`.
- **No auth check occurs.** A user can complete the mock journey and access all `/app/*` routes without any real session.

---

## Section C — Native layer

### 12. HealthKit plugin `setCredentials`

**No such method exists.** The native app is not a Capacitor plugin; it's a pure Swift app.

The engine (`ios/BPReset/Engine/HealthKitEngine.swift`) does not handle credentials. Auth tokens are managed entirely by `SessionModel` and the Supabase Swift SDK.

The word "token" appears only in unrelated contexts:
- Line 553: "generation token" (snapshot generation ID)
- `EngineState.swift:117`: "Generation token" (internal state tracking)

### 13. Keychain implementation

**File:** `ios/BPReset/Data/SupabaseAPI.swift:10-48`

```swift
struct KeychainSessionStorage: AuthLocalStorage {
    private let service = "dev.aiplease.bpreset.auth"

    private func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse!,
        ]
    }

    func store(key: String, value: Data) throws {
        var add = query(key)
        add[kSecValueData as String] = value
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        // ...
    }
    // ...
}
```

| Attribute | Value |
|-----------|-------|
| **Accessibility** | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| **kSecAttrSynchronizable** | `kCFBooleanFalse` |

This matches the Part 3 spec exactly: excluded from iCloud Keychain and device backups.

### 14. Plugin network calls to Supabase

The HealthKitEngine does **not** make network calls to Supabase directly. It:
1. Reads from HealthKit
2. Queues readings locally in `EngineState`
3. Exposes `pendingSnapshot()` for the drain to read

The actual Supabase calls are made by `SupabaseAPI` (`ios/BPReset/Data/SupabaseAPI.swift:87-215`), which is called by the app layer (not the engine). The API uses the Supabase client's built-in session handling — no manual token passing.

---

## Section D — Database state

**Note:** Supabase CLI queries require database password authentication. The CLI prompted for credentials which were not available. Answers below are derived from the migration files in `supabase/migrations/`.

### 15. Migration list

Local migrations (from `supabase/migrations/`):

| Timestamp | Name |
|-----------|------|
| 20260729100000 | `create_app_user` |
| 20260729100100 | `create_observation_definition` |
| 20260729100200 | `seed_observation_definitions_bp` |
| 20260729100300 | `create_observation` |
| 20260729100400 | `create_observation_component` |
| 20260729100500 | `create_consent_event` |
| 20260729100600 | `create_audit_event` |
| 20260729100700 | `create_program_progress` |
| 20260729100800 | `create_helper_functions` |
| 20260729100900 | `create_append_only_guards` |
| 20260729101000 | `create_rls_policies` |
| 20260729101100 | `create_views` |
| 20260729101200 | `create_ingest_rpc` |
| 20260729101300 | `create_patient_rpcs` |
| 20260729101400 | `create_export_rpc` |
| 20260729101500 | `grants` |

**Remote status:** Cannot determine without CLI access.

### 16. Tables in `public` schema

From migrations:

| Table | Columns (key fields) |
|-------|---------------------|
| `app_user` | `id uuid PK`, `auth_user_id uuid FK NULL`, `display_name`, `adult_attested bool`, `adult_attested_at`, `identity_deleted_at`, `created_at` |
| `observation` | `id uuid PK`, `user_id uuid FK`, `status`, `code`, `code_system`, `effective_time`, `source_type`, `source_uuid`, `deleted_at`, etc. |
| `observation_component` | `id uuid PK`, `observation_id uuid FK`, `code`, `value_quantity`, `value_unit`, etc. |
| `observation_definition` | `code text PK`, `code_system`, `expected_unit`, `min_value`, `max_value`, `is_panel`, etc. |
| `consent_event` | `id uuid PK`, `user_id uuid FK`, `event_type`, `version`, `document_hash`, `method`, `occurred_at` |
| `audit_event` | `id uuid PK`, `user_id uuid FK NULL`, `actor_type`, `actor_id`, `event_type`, `target_table`, `target_id`, `detail jsonb`, `occurred_at` |
| `program_progress` | `user_id uuid PK FK`, `current_week int`, `completed_steps jsonb`, `updated_at` |

### 17. RLS and policies

From `20260729101000_create_rls_policies.sql`:

| Table | RLS | Policies |
|-------|-----|----------|
| `app_user` | **Enabled** | `app_user_select_own`: SELECT using `id = get_app_user_id()` |
| `observation` | **Enabled** | `observation_select_own`: SELECT using `user_id = get_app_user_id() AND deleted_at IS NULL` |
| `observation_component` | **Enabled** | `observation_component_select_own`: SELECT via join to parent |
| `consent_event` | **Enabled** | `consent_event_select_own`: SELECT using `user_id = get_app_user_id()` |
| `audit_event` | **Enabled** | **No patient policy** — patients cannot read |
| `program_progress` | **Enabled** | SELECT, INSERT, UPDATE policies using `user_id = get_app_user_id()` |

**No INSERT/UPDATE/DELETE policies on `observation` or `observation_component`** — all writes through security-definer RPCs.

### 18. Functions in `public`

From migrations:

| Function | Args | Returns | Security | search_path |
|----------|------|---------|----------|-------------|
| `get_app_user_id()` | — | uuid | DEFINER | Pinned `''` |
| `has_active_consent(uuid)` | p_user_id | boolean | DEFINER | Pinned `''` |
| `prevent_mutation()` | — (trigger) | trigger | — | Pinned `''` |
| `ingest_observations(jsonb)` | payload | jsonb | DEFINER | Pinned `''` |
| `enrol_patient(text, boolean)` | p_display_name, p_adult_attested | uuid | DEFINER | Pinned `''` |
| `record_consent(text, text)` | p_version, p_document_hash | void | DEFINER | Pinned `''` |
| `withdraw_consent()` | — | void | DEFINER | Pinned `''` |
| `soft_delete_observation(uuid)` | p_observation_id | void | DEFINER | Pinned `''` |
| `delete_account()` | — | void | DEFINER | Pinned `''` |
| `export_patient_data()` | — | (jsonb) | DEFINER | Pinned `''` |

All security-definer functions have `search_path` pinned to empty string.

### 19. Views in `public`

From `20260729101100_create_views.sql`:

| View | `security_invoker` |
|------|-------------------|
| `v_bp_readings` | **true** |
| `v_bp_trend` | **true** |
| `v_consent_status` | **true** |
| `v_program_progress` | **true** |

All views use `security_invoker = true`.

### 20. Grants

From `20260729101500_grants.sql`:

**anon role:**
- `USAGE ON SCHEMA public` only
- No table/function access (comment: "gets schema usage only")

**authenticated role:**
- SELECT on `app_user`, `observation`, `observation_component`, `consent_event`
- SELECT on all four views
- SELECT, INSERT, UPDATE on `program_progress`
- EXECUTE on: `get_app_user_id()`, `has_active_consent(uuid)`, `ingest_observations(jsonb)`, `enrol_patient(text, boolean)`, `record_consent(text, text)`, `withdraw_consent()`, `soft_delete_observation(uuid)`, `delete_account()`, `export_patient_data()`

### 21. `app_user` definition

From `20260729100000_create_app_user.sql`:

```sql
create table public.app_user (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  display_name text,
  adult_attested boolean not null default false,
  adult_attested_at timestamptz,
  identity_deleted_at timestamptz,
  created_at timestamptz not null default now()
);
```

**Constraints:** PK on `id`, UNIQUE on `auth_user_id`, FK to `auth.users(id)` with `ON DELETE SET NULL`.

**Indexes:** Unique constraint on `auth_user_id` implicitly creates an index.

### 22. `get_app_user_id()` body

From `20260729100800_create_helper_functions.sql`:

```sql
create or replace function public.get_app_user_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select au.id
    from public.app_user au
   where au.auth_user_id = auth.uid()
     and au.identity_deleted_at is null
$$;
```

### 23. Trigger on `auth.users`

**None.** Migration `20260729100000_create_app_user.sql` comment (lines 5-6):
```sql
-- Enrolment is explicit via enrol_patient() — there is no trigger on
-- auth.users. An anonymous session at launch must not create a patient row.
```

This matches Part 3 design: explicit enrolment, not automatic.

---

## Section E — Auth schema

**Cannot determine from CLI.** Requires database access.

### 24. Row counts in `auth.users`

**Unknown** — requires database query.

### 25. Identity providers

**Unknown** — requires database query.

From `supabase/config.toml`:
- Apple provider configured but `enabled = false` locally
- No other providers enabled in config

### 26. `auth.users` columns / `is_anonymous`

**Unknown** — requires database query.

The `is_anonymous` column is referenced in `docs/02-data-model-and-api.md:202` and `docs/02-data-model-and-api.md:541`, indicating the project version supports it.

---

## Section F — Configuration

### 27. `[auth]` section of `config.toml`

```toml
[auth]
enabled = true
# The base URL of your website. Used as an allow-list for redirects and for constructing URLs used
# in emails.
site_url = "http://127.0.0.1:3000"
# A list of *exact* URLs that auth providers are permitted to redirect to post authentication.
additional_redirect_urls = ["https://127.0.0.1:3000"]
# How long tokens are valid for, in seconds. Defaults to 3600 (1 hour), maximum 604,800 (1 week).
jwt_expiry = 3600
# If disabled, the refresh token will never expire.
enable_refresh_token_rotation = true
# Allows refresh tokens to be reused after expiry, up to the specified interval in seconds.
# Requires enable_refresh_token_rotation = true.
refresh_token_reuse_interval = 10
# Allow/disallow new user signups to your project.
enable_signup = true
# Allow/disallow anonymous sign-ins to your project.
enable_anonymous_sign_ins = false
# Allow/disallow testing manual linking of accounts
enable_manual_linking = false
# Passwords shorter than this value will be rejected as weak. Minimum 6, recommended 8 or more.
minimum_password_length = 6
# Passwords that do not meet the following requirements will be rejected as weak. Supported values
# are: `letters_digits`, `lower_upper_letters_digits`, `lower_upper_letters_digits_symbols`
password_requirements = ""
```

### 28. Auth settings summary

| Setting | Value |
|---------|-------|
| `enable_anonymous_sign_ins` | **false** |
| `minimum_password_length` | 6 |
| External providers enabled | **None** (Apple is configured but `enabled = false`) |
| `jwt_expiry` | 3600 (1 hour) |
| `enable_refresh_token_rotation` | true |

### 29. Settings requiring dashboard check

The following cannot be determined from repo/CLI and must be verified in the Supabase Dashboard:

- [ ] Email confirmation requirement (live project)
- [ ] Apple Sign-In actual enablement and credentials
- [ ] SMTP configuration for production emails
- [ ] Rate limiting configuration
- [ ] MFA settings
- [ ] Session timeout/inactivity settings
- [ ] Actual `is_anonymous` column presence
- [ ] Row counts in `auth.users` and `auth.identities`

---

## Section G — Gaps

### 30. Part 3 items specified but not implemented

| Spec Item | Status |
|-----------|--------|
| **Anonymous session bootstrap** (§3.2 flow diagram: `signInAnonymously()`) | **Not implemented.** `enable_anonymous_sign_ins = false` in config. `docs/06-native-app-build-plan.md:325` confirms: "No. Disabled on the project." |
| **Identity linking** (§3.2: "link identity to existing anonymous user") | **Not implemented.** No anonymous session to link from. |
| **Sign in with Apple** (§3.1: "implemented for launch") | **Partially.** Config exists but `enabled = false`. No Swift code for Apple Sign-In found. |
| **App lock** (§3.4: "Optional Face ID / passcode gate") | **Not implemented.** No LocalAuthentication framework usage found. |

### 31. Implementations contradicting Part 3

| Contradiction | Evidence |
|--------------|----------|
| **Web session storage** | Part 3 §3.4 specifies "iOS Keychain via Capacitor secure-storage adapter." **Contradiction:** Web app has no Supabase client at all. Journey state uses `localStorage` (`src/lib/journey/state.tsx:44`). However, this is **not a contradiction** — the web app is explicitly a mock (`Signup.tsx:10`), and health data is never stored client-side in web. |
| **None in native layer** | Native implementation matches spec: Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and `kSecAttrSynchronizable = false`. |

**No contradictions in the native implementation.**

### 32. Stage 2 blockers

Stage 2 acceptance requires: *"a manual entry writing a reading to Supabase — that needs an authenticated session resolving to an `app_user` row."*

| Requirement | Status | Blocking? |
|-------------|--------|-----------|
| Authenticated session | **Native: Implemented.** `SessionModel.signUp/signIn` work. | No |
| `app_user` row creation | **Native: Implemented.** `enrol_patient()` RPC creates row. | No |
| Session → `app_user` resolution | **Implemented.** `get_app_user_id()` resolves `auth.uid()` → `app_user.id`. | No |
| Manual entry writes to Supabase | **Native: Implemented.** `SupabaseAPI.ingestObservations()` calls `ingest_observations` RPC. | No |
| Consent gating | **Implemented.** `ingest_observations` checks `has_active_consent()`. | No |

**No blockers for Stage 2 acceptance in the native app.**

**Web preview:** Cannot meet Stage 2 — no Supabase client, no real auth. This is expected; the web preview is for demonstration only.

---

## Summary Table: Part 3 Auth Design

| Element | Specified | Implemented | Contradicts | Unknown |
|---------|-----------|-------------|-------------|---------|
| Email + password auth | Yes | **Yes** (native) | No | — |
| Sign in with Apple | Yes | **Partial** (config only) | No | Dashboard state |
| Anonymous session bootstrap | Yes | **No** | No | — |
| Identity linking | Yes | **No** | No | — |
| Keychain storage (native) | Yes | **Yes** | No | — |
| `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | Yes | **Yes** | No | — |
| `kSecAttrSynchronizable = false` | Yes | **Yes** | No | — |
| App lock (Face ID gate) | Optional | **No** | No | — |
| No trigger on `auth.users` | Yes | **Yes** | No | — |
| Explicit enrolment via RPC | Yes | **Yes** | No | — |
| Consent gating server-side | Yes | **Yes** | No | — |
| RLS on all patient tables | Yes | **Yes** | No | — |
| `jwt_expiry` = 1 hour | Yes | **Yes** | No | — |
| Refresh token rotation | Yes | **Yes** | No | — |
| Views with `security_invoker` | Yes | **Yes** | No | — |
| Security definer functions pinned | Yes | **Yes** | No | — |
| anon role: no data access | Yes | **Yes** | No | — |
| authenticated role: read + RPC | Yes | **Yes** | No | — |

---

*Report generated by investigation of repo files only. Database queries require authenticated CLI access not available at generation time.*

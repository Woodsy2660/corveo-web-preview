# Read Path Findings

| | |
|---|---|
| **Generated** | 16 September 2026 |
| **Purpose** | Factual investigation of AB-01 and AB-04 |
| **Scope** | Native iOS (Swift) + Web preview (React) |

---

## Preliminary Note

**`docs/04-auth-bridge-spec.md` does not exist.** The prompt references §7 describing "three options and a recommendation" for AB-01. No such file exists in the repository. The closest documentation is:

- `docs/07-native-swift-rebuild.md` — describes the pure SwiftUI native app
- `docs/03-plugin-bridge-spec.md` — describes the HealthKit plugin bridge (not auth)
- `docs/auth-state-report.md` — auth implementation audit

The native app is **not a Capacitor hybrid with a WebView**. It is a pure SwiftUI application. There is no WebView, no JavaScript bridge, and no React running inside the native app. The React layer is a standalone web demo that does not connect to Supabase.

---

## Part 1 — How does the native app read data today?

### 1. Does the native Swift code make any read calls to Supabase?

**Yes.** The following read calls exist:

| File | Line | Target | Method |
|------|------|--------|--------|
| `ios/BPReset/Data/SupabaseAPI.swift` | 111-117 | `v_bp_readings` | `.from("v_bp_readings").select(...)` |
| `ios/BPReset/Data/SupabaseAPI.swift` | 120-127 | `v_bp_trend` | `.from("v_bp_trend").select(...)` |
| `ios/BPReset/Data/SupabaseAPI.swift` | 131-136 | `v_consent_status` | `.from("v_consent_status").select(...)` |
| `ios/BPReset/Data/SupabaseAPI.swift` | 161-166 | `v_program_progress` | `.from("v_program_progress").select(...)` |
| `ios/BPReset/Data/SupabaseAPI.swift` | 171 | `app_user` | `.from("app_user").select("id, created_at")` |
| `ios/BPReset/Data/SupabaseAPI.swift` | 209-212 | `app_user` | `.from("app_user").select("id, created_at")` |

### 2. How does it attach the token?

The Supabase Swift SDK handles token attachment automatically. The client is instantiated with `KeychainSessionStorage`:

**File:** `ios/BPReset/Data/SupabaseAPI.swift:55-60`
```swift
return SupabaseClient(
    supabaseURL: url,
    supabaseKey: AppConfig.supabasePublishableKey,
    options: SupabaseClientOptions(
        db: .init(encoder: paramEncoder),
        auth: .init(storage: KeychainSessionStorage())))
```

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
    // retrieve(), remove() follow same pattern
}
```

The SDK reads from Keychain, attaches the bearer token to each request automatically. No manual token passing.

### 3. Which Supabase Swift SDK version is in use?

**Version:** `>= 2.5.1` (up to next major)

**File:** `ios/BPReset.xcodeproj/project.pbxproj:381-388`
```
/* XCRemoteSwiftPackageReference "supabase-swift" */
repositoryURL = "https://github.com/supabase/supabase-swift.git";
requirement = {
    kind = upToNextMajorVersion;
    minimumVersion = 2.5.1;
};
```

### 4. Is there any existing custom URL scheme?

**No.**

- `ios/Config/Info.plist` contains no `CFBundleURLTypes` entry
- Grep for `CFBundleURLTypes` in `project.pbxproj`: no matches
- Grep for `WKURLSchemeHandler` in `ios/`: no matches

### 5. How is the WKWebView configured?

**There is no WKWebView.** The native app is pure SwiftUI with no WebView component.

- Grep for `WKWebView` in `ios/`: no matches
- Grep for `WKWebViewConfiguration` in `ios/`: no matches
- `docs/07-native-swift-rebuild.md` §1: "Rebuild the React front end as a native SwiftUI app. No Capacitor, no WebView, no JavaScript bridge."

---

## Part 2 — What does React currently do for data?

### 6. How does the React layer currently fetch reading data?

**Mock API only. No real network calls.**

**File:** `src/screens/tabs/Record/Record.tsx:14,56`
```tsx
import { useReadings, useTrend } from "@/lib/api/hooks";
// ...
const { data: readings, isLoading: readingsLoading } = useReadings(200);
```

**File:** `src/lib/api/hooks.ts:18-23`
```typescript
export function useReadings(limit = 50) {
  return useQuery({
    queryKey: [...queryKeys.readings, limit],
    queryFn: () => getApi().listReadings({ limit }),
  });
}
```

**File:** `src/lib/api/index.ts:12-17`
```typescript
export function getApi(): CorveoApi {
  if (!instance) {
    instance = createMockApi();  // <-- MOCK, not Supabase
  }
  return instance;
}
```

**File:** `src/lib/api/mock.ts:73-83`
```typescript
async listReadings(opts) {
  await delay(LATENCY_MS);
  const limit = opts?.limit ?? 50;
  let rows = [...store.readings].sort((a, b) =>
    b.effective_time.localeCompare(a.effective_time),
  );
  // ... reads from localStorage mock store
  return rows.slice(0, limit);
},
```

The mock reads from `localStorage` with key `corveo.mock.v1`.

### 7. Is React Query, SWR, or any data-fetching library in package.json?

**Yes: @tanstack/react-query version 5.101.4**

**File:** `package.json:14`
```json
"@tanstack/react-query": "^5.101.4",
```

### 8. Outbound HTTP calls in the web source

**None.**

```bash
grep -rn "supabase\.co\|/rest/v1\|fetch(\|XMLHttpRequest" src/
# No matches
```

No `@supabase/supabase-js` in `package.json`. The web app makes zero network calls to Supabase.

### 9. Does any Capacitor plugin bridge data between native and web?

**No Capacitor plugins exist.** There is no Capacitor in this project.

- `package.json` contains no `@capacitor/*` dependencies
- The iOS app is a pure Swift app, not a Capacitor shell
- Comments in `src/lib/health/index.ts:6` and `src/lib/haptics.ts:8-19` reference future Capacitor integration that was never implemented

---

## Part 3 — What the read path has to serve

### 10. Views and RPCs React would need

Based on `docs/02-data-model-and-api.md` §4.3 and the screens in `src/`:

| Name | Type | Consuming Screen | Parameters |
|------|------|------------------|------------|
| `v_bp_readings` | View read | Record, History | `limit`, `before` (keyset pagination) |
| `v_bp_trend` | View read | Record (chart) | `sinceDay` (date filter) |
| `v_consent_status` | View read | Consent, Settings | None |
| `v_program_progress` | View read | Program, Chapters | None |
| `ingest_observations` | RPC | ManualEntryForm, AppleHealthSync | `payload` (jsonb) |
| `record_consent` | RPC | Consent step | `p_version`, `p_document_hash` |
| `enrol_patient` | RPC | Signup | `p_display_name`, `p_adult_attested` |
| `export_patient_data` | RPC | Settings > Your Data | None |

### 11. Record screen query requirements

**Two distinct queries:**

1. `v_bp_readings` — list of readings
   - Parameters: `limit` (number), `before` (ISO timestamp for keyset pagination)
   - Used for: history list, chart data points

2. `v_bp_trend` — daily aggregates
   - Parameters: `sinceDay` (date string)
   - Used for: chart rendering (though current React derives from raw readings)

**Pagination:** Keyset on `effective_time`, not offset-based.

### 12. Write RPCs other than ingest_observations

**Yes:**

| RPC | Screen |
|-----|--------|
| `record_consent(text, text)` | Consent step |
| `withdraw_consent()` | Settings |
| `soft_delete_observation(uuid)` | (not currently wired, Deliverable 12) |
| `delete_account()` | Settings > Account |
| `export_patient_data()` | Settings > Your Data |

---

## Part 4 — AB-04, idempotency of enrol_patient()

### 13. Full function body

**File:** `supabase/migrations/20260729101300_create_patient_rpcs.sql:13-66`

```sql
create or replace function public.enrol_patient(
  p_display_name text,
  p_adult_attested boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_id uuid := auth.uid();
  v_user_id uuid;
begin
  if v_auth_id is null then
    raise exception 'UNAUTHORIZED' using errcode = '28000';
  end if;

  if p_adult_attested is not true then
    raise exception 'ADULT_ATTESTATION_REQUIRED' using errcode = '22023';
  end if;

  select au.id
    into v_user_id
    from public.app_user au
   where au.auth_user_id = v_auth_id
     and au.identity_deleted_at is null;

  if v_user_id is null then
    insert into public.app_user (
      auth_user_id, display_name, adult_attested, adult_attested_at
    ) values (
      v_auth_id, p_display_name, true, now()
    )
    returning id into v_user_id;

    insert into public.audit_event (
      user_id, actor_type, actor_id, event_type, target_table, target_id
    ) values (
      v_user_id, 'patient', v_user_id, 'patient_enrolled', 'app_user', v_user_id
    );

    insert into public.program_progress (user_id)
    values (v_user_id);
  else
    update public.app_user
       set display_name = coalesce(p_display_name, display_name),
           adult_attested = true,
           adult_attested_at = coalesce(adult_attested_at, now())
     where id = v_user_id;
  end if;

  return v_user_id;
end;
$$;
```

### 14. What does a second call do?

**It updates the existing row.**

Relevant lines:

```sql
-- Lines 34-38: First, look up existing row
select au.id
  into v_user_id
  from public.app_user au
 where au.auth_user_id = v_auth_id
   and au.identity_deleted_at is null;

-- Line 40: Only INSERT if not found
if v_user_id is null then
  -- INSERT block (lines 41-55)
else
  -- Line 56-61: UPDATE existing row
  update public.app_user
     set display_name = coalesce(p_display_name, display_name),
         adult_attested = true,
         adult_attested_at = coalesce(adult_attested_at, now())
   where id = v_user_id;
end if;
```

The function uses SELECT-then-INSERT-or-UPDATE pattern. It does **not** use `INSERT ... ON CONFLICT`.

### 15. Does it write an audit_event on every call?

**No.** The `patient_enrolled` audit event is written only in the `if v_user_id is null` branch (lines 48-52). A second call with the same `auth.uid()` takes the `else` branch and writes no audit event.

### 16. Database test of enrol_patient()

**Cannot execute.** Supabase CLI is not available in this environment (`which supabase` returns exit code 1). The answer in §14 is derived from the function body alone and is **unverified** against a running database.

### 17. Does app_user have a unique constraint on auth_user_id?

**Yes.**

**File:** `supabase/migrations/20260729100000_create_app_user.sql:8-10`
```sql
create table public.app_user (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  -- ...
);
```

The `unique` keyword creates both a constraint and an index.

---

## Part 5 — Other function verification

All functions are verified from migration files. Database CLI not available.

### 18. get_app_user_id()

**File:** `supabase/migrations/20260729100800_create_helper_functions.sql:8-19`

| Property | Value |
|----------|-------|
| Exists | Yes |
| Security | DEFINER |
| search_path pinned | Yes (`''`) |
| Arguments | None |
| Returns | `uuid` |
| Granted to authenticated | Yes (`grants.sql:42`) |

### 19. has_active_consent(uuid)

**File:** `supabase/migrations/20260729100800_create_helper_functions.sql:24-39`

| Property | Value |
|----------|-------|
| Exists | Yes |
| Security | DEFINER |
| search_path pinned | Yes (`''`) |
| Arguments | `p_user_id uuid` |
| Returns | `boolean` |
| Granted to authenticated | Yes (`grants.sql:43`) |

### 20. ingest_observations(jsonb)

**File:** `supabase/migrations/20260729101200_create_ingest_rpc.sql:10-373`

| Property | Value |
|----------|-------|
| Exists | Yes |
| Security | DEFINER |
| search_path pinned | Yes (`''`) |
| Arguments | `payload jsonb` |
| Returns | `jsonb` |
| Granted to authenticated | Yes (`grants.sql:44`) |

### 21. delete_account()

**File:** `supabase/migrations/20260729101300_create_patient_rpcs.sql:209-241`

| Property | Value |
|----------|-------|
| Exists | Yes |
| Security | DEFINER |
| search_path pinned | Yes (`''`) |
| Arguments | None |
| Returns | `void` |
| Granted to authenticated | Yes (`grants.sql:49`) |

### 22. record_consent(text, text)

**File:** `supabase/migrations/20260729101300_create_patient_rpcs.sql:76-110`

| Property | Value |
|----------|-------|
| Exists | Yes |
| Security | DEFINER |
| search_path pinned | Yes (`''`) |
| Arguments | `p_version text`, `p_document_hash text` |
| Returns | `void` |
| Granted to authenticated | Yes (`grants.sql:46`) |

### 23. soft_delete_observation(uuid)

**File:** `supabase/migrations/20260729101300_create_patient_rpcs.sql:165-199`

| Property | Value |
|----------|-------|
| Exists | Yes |
| Security | DEFINER |
| search_path pinned | Yes (`''`) |
| Arguments | `p_observation_id uuid` |
| Returns | `void` |
| Granted to authenticated | Yes (`grants.sql:48`) |

### 24. export_patient_data()

**File:** `supabase/migrations/20260729101400_create_export_rpc.sql:9-198`

| Property | Value |
|----------|-------|
| Exists | Yes |
| Security | DEFINER |
| search_path pinned | Yes (`''`) |
| Arguments | None |
| Returns | `jsonb` |
| Granted to authenticated | Yes (`grants.sql:50`) |

### 25. Views in public schema

**File:** `supabase/migrations/20260729101100_create_views.sql`

| View | security_invoker |
|------|-----------------|
| `v_bp_readings` | true (line 13) |
| `v_bp_trend` | true (line 45) |
| `v_consent_status` | true (line 73) |
| `v_program_progress` | true (line 95) |

### 26. Grants to anon and authenticated

**File:** `supabase/migrations/20260729101500_grants.sql`

**anon:**
- `USAGE ON SCHEMA public` only (line 15)
- No table, view, or function access (line 52: "gets schema usage only")

**authenticated:**

| Grant | Objects |
|-------|---------|
| SELECT | `app_user`, `observation`, `observation_component`, `consent_event` (lines 25-30) |
| SELECT | `v_bp_readings`, `v_bp_trend`, `v_consent_status`, `v_program_progress` (lines 32-37) |
| SELECT, INSERT, UPDATE | `program_progress` (line 39) |
| EXECUTE | `get_app_user_id()`, `has_active_consent(uuid)`, `ingest_observations(jsonb)`, `enrol_patient(text, boolean)`, `record_consent(text, text)`, `withdraw_consent()`, `soft_delete_observation(uuid)`, `delete_account()`, `export_patient_data()` (lines 42-50) |

### 27. RLS on all tables in public?

**File:** `supabase/migrations/20260729101000_create_rls_policies.sql:9-14`

| Table | RLS Enabled |
|-------|-------------|
| `app_user` | Yes |
| `observation` | Yes |
| `observation_component` | Yes |
| `consent_event` | Yes |
| `audit_event` | Yes |
| `program_progress` | Yes |
| `observation_definition` | **No** (reference data, not patient data; ungranted to clients) |

---

## Part 6 — Feasibility of the recommended option

**Note:** The prompt references a "recommended option" in `docs/04-auth-bridge-spec.md` §7 describing a custom-scheme proxy. That document does not exist. The following answers are based on the actual architecture.

### 28. Is a WKURLSchemeHandler already registered?

**No.** There is no WebView in the native app, therefore no scheme handlers.

### 29. Would an additional scheme handler conflict with Capacitor?

**Not applicable.** There is no Capacitor. The app is pure SwiftUI.

### 30. Would existing web code break with a custom scheme?

**Not applicable.** The web layer makes zero HTTP calls. All data comes from a localStorage mock. There is no `fetch()` to redirect.

---

## Summary Tables

### Table A — Functions

| Function | Exists | Security | search_path pinned | Granted to authenticated |
|----------|--------|----------|-------------------|-------------------------|
| `get_app_user_id()` | Yes | DEFINER | Yes | Yes |
| `has_active_consent(uuid)` | Yes | DEFINER | Yes | Yes |
| `ingest_observations(jsonb)` | Yes | DEFINER | Yes | Yes |
| `enrol_patient(text, boolean)` | Yes | DEFINER | Yes | Yes |
| `record_consent(text, text)` | Yes | DEFINER | Yes | Yes |
| `withdraw_consent()` | Yes | DEFINER | Yes | Yes |
| `soft_delete_observation(uuid)` | Yes | DEFINER | Yes | Yes |
| `delete_account()` | Yes | DEFINER | Yes | Yes |
| `export_patient_data()` | Yes | DEFINER | Yes | Yes |

### Table B — Read Surface

| Name | Type | Consuming Screen | Parameters |
|------|------|------------------|------------|
| `v_bp_readings` | View | Record | `limit`, `before` |
| `v_bp_trend` | View | Record (chart) | `sinceDay` |
| `v_consent_status` | View | Consent, Settings | None |
| `v_program_progress` | View | Program | None |
| `ingest_observations` | RPC | ManualEntry, HealthSync | `payload` |
| `record_consent` | RPC | Consent | `version`, `document_hash` |
| `enrol_patient` | RPC | Signup | `display_name`, `adult_attested` |
| `export_patient_data` | RPC | Settings | None |
| `soft_delete_observation` | RPC | (Deliverable 12) | `observation_id` |
| `delete_account` | RPC | Settings | None |
| `withdraw_consent` | RPC | Settings | None |

### Table C — AB-01 Readiness

**Note:** The premise of AB-01 ("how does React read data, given that tokens never enter the WebView") is based on an architecture that does not exist. There is no WebView. The native app is pure SwiftUI; the React app is a standalone web demo.

| Option | What exists | What would need building | Blockers |
|--------|-------------|-------------------------|----------|
| Bridge method per query | N/A — no WebView | N/A | Architecture mismatch |
| Custom scheme proxy | N/A — no WebView | N/A | Architecture mismatch |
| Short-lived token | N/A — no WebView | N/A | Architecture mismatch |

**If the intent is to add a WebView to serve the React app inside the native shell:**

| Option | What exists | What would need building | Blockers |
|--------|-------------|-------------------------|----------|
| Bridge method per query | Native `SupabaseAPI` class with all 4 views + RPCs | WKWebView, JS bridge interface, Swift message handlers | None |
| Custom scheme proxy | Nothing | WKURLSchemeHandler, token injection, request forwarding | None |
| Short-lived token | Nothing | Token minting endpoint, React Supabase client | Service-role key required server-side |

---

## Conclusions

### AB-04 — Is enrol_patient() idempotent?

**Yes.**

Evidence:
- Lines 34-38: SELECT existing row by `auth_user_id`
- Line 40: `if v_user_id is null then` — INSERT only if not found
- Lines 56-61: UPDATE existing row in `else` branch
- Lines 48-52: `patient_enrolled` audit event written only on first call
- Line 10 of `create_app_user.sql`: `auth_user_id uuid unique` prevents duplicates at the constraint level

A second call with the same `auth.uid()` updates the existing `app_user` row without raising an error and without writing a duplicate audit event.

**Unverified:** Database CLI not available. Analysis is from function body only.

### Part 5 issues

**Nothing missing, unpinned, or ungranted.** All nine functions:
- Exist in migrations
- Are `SECURITY DEFINER`
- Have `search_path` pinned to `''`
- Are granted to `authenticated`

All four views have `security_invoker = true`.

### What could not be determined

| Item | What would resolve it |
|------|----------------------|
| Database state matches migrations | Supabase CLI access or dashboard query |
| `enrol_patient()` tested in transaction | Database CLI with authenticated session |
| Remote project configuration | Supabase Dashboard access |

### Architecture clarification

**AB-01 as stated does not apply.** The question assumes tokens need to cross from native to a WebView. The native app has no WebView — it is pure SwiftUI calling Supabase directly via the Swift SDK with Keychain session storage. The React app is a standalone demo that never touches Supabase.

If the plan is to add a WebView serving React inside the native shell, all three options from the (non-existent) spec are technically feasible. The native `SupabaseAPI` class already implements every view and RPC the React layer would need.

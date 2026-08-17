# 04 — Front End

**Owner:** Michael · **Status:** v0.1, 14 Aug 2026 · **Lane:** Front end

What exists, how to run it, and how the other lanes hook in. Written as built,
per SOW A.14.2. Read `01-system-architecture.md` §2 first — the build
constraints are contractual.

---

## 1. What exists

The complete V1 screen flow, running on synthetic data behind a mocked API and
a mocked HealthKit plugin. Every screen renders from the Corveo/Userkind design
tokens. TypeScript strict, tests on the validation and fixture logic, clean
production build.

**Journey (5 steps, SOW Deliverable 5):**

| Route | Screen | Notes |
|---|---|---|
| `/journey/welcome` | Educate | 3 education cards + disclaimer |
| `/journey/signup` | Account | MOCK auth; 18+ attestation → `app_user.adult_attested` |
| `/journey/consent` | **Express consent** | Writes a consent event: version + SHA-256 of exact text + timestamp |
| `/journey/connect` | Connect branch | healthkit / manual / none; cuff list shown on "none" |
| `/journey/health-auth` | HealthKit authorisation | healthkit branch only; never renders "denied" |
| `/journey/capture` | First capture | Manual entry with data-quality bounds |
| `/journey/result` | Result-as-context | Reading shown exactly as recorded, program framing |
| `/journey/cadence` | Cadence | Rhythm choice; reminders are never reading-triggered |

**App (3 tabs + stack screens):**

| Route | Screen | Notes |
|---|---|---|
| `/app/readings` | Readings tab | History list, provenance chips, add CTA |
| `/app/trend` | Trend tab (Deliverable 6) | Daily aggregates, monochrome, display-only |
| `/app/program` | Program tab (Deliverable 7) | 6-week container, placeholder content pending Corveo |
| `/app/add` | Manual entry (Deliverable 4) | Same ingest path as the plugin |
| `/app/settings` | Settings (Deliverable 12) | Health status, export, deletion, consent receipt, safety copy |
| `/app/cuffs` | Validated cuffs (Deliverable 8) | STRIDE BP cited as the authoritative source |

## 2. Running it

```bash
nvm use            # Node 20
npm install
npm run dev        # http://localhost:5184 — port is pinned, strictPort
npm test           # vitest — validation bounds + fixture logic
npm run build      # tsc --noEmit && vite build
```

No `.env` needed yet — everything runs on the mock layer. A shared web preview
deploys to Vercel from this branch (see §7).

## 3. Stack (and why it differs slightly from the July docs)

React 19 · TypeScript 5.9 (strict) · Vite 8 · react-router 8 ·
TanStack Query 5 · Tailwind 4 · Vitest 4.

The July architecture docs said "React 18 + Capacitor 6"; both had moved a
major version by kickoff, so the foundation uses current stable. TS 7 exists
but is weeks old — 5.9 is the boring choice. **No Capacitor dependency is
installed yet**: the web app is shell-agnostic and nothing in `src/` imports
Capacitor, so Luca picks the Capacitor major (8.x is current) when the shell
lands. See decisions F-01/F-02 in `decisions.md`.

## 4. Design tokens (Userkind design language)

`src/components/tokens/tokens.css` holds the Userkind vocabulary — surface /
text / border palette, reckless (display serif) + haffer (body sans), type
scale, spacing, radii — extracted from the shipped corveo.vercel.app CSS so
web and iOS share one language. `src/app.css` maps them to Tailwind utilities
(`bg-page`, `text-heading`, `rounded-round`, …).

Rules:
- Components consume semantic tokens only. **No raw hex or px in
  `src/components/` or `src/screens/`** — the token file is the single place
  values live.
- Chart marks use `--app-chart-ink` / `--app-chart-ink-soft` only. There are
  deliberately no threshold/zone/band colours in the vocabulary, and none may
  be added (SOW A.3.3).
- The reckless/haffer font files are licensed (Displaay); the app currently
  renders fallbacks (Georgia/system). **Open item: obtain the font files or a
  hosted license from Corveo/Userkind** and drop them into `src/assets/fonts/`
  with `@font-face` in tokens.css.
- When Figma variables are exported from the Userkind file, they replace the
  values in tokens.css — one file, no component changes.

## 5. Data layer — how Ben hooks in

Screens never touch an implementation. They import from `src/lib/api`
(`getApi()` + React Query hooks in `hooks.ts`), typed by the `CorveoApi`
interface in `src/lib/api/types.ts`, whose shapes mirror
`02-data-model-and-api.md` Part 4 exactly: the four views (`v_bp_readings`,
`v_bp_trend`, `v_consent_status`, `v_program_progress`), the
`ingest_observations` RPC (request, response, stable rejection reasons), and
export.

To integrate: implement `CorveoApi` over supabase-js (or straight PostgREST
fetch), swap it into `src/lib/api/index.ts`, delete `src/lib/api/mock.ts` and
`src/lib/mock/`. Nothing else changes.

Notes for the spec (feedback from building against it):
- **Consent write path is undefined in Part 4.** The mock invented
  `recordConsentEvent({action, version, document_hash, method})` — the real
  API needs an equivalent (RPC or insert policy). Flagged as an open item.
- Manual entry submits through the same `ingest_observations` shape as the
  plugin (`source_type: "manual"`, `source_user_entered: true`, arm carried as
  SNOMED `body_site_code` + `context.arm`). Bounds mirrored from
  `observation_definition` seeds (sys 60–260, dia 30–160, sys > dia) in
  `src/lib/api/bounds.ts` — one place to keep in sync with the DB.
- Trend consumes the daily grain as documented (D-02: daily confirmed fine
  from the front-end side).

## 6. HealthKit bridge — how Luca hooks in

Screens import `getHealthPlugin()` from `src/lib/health`. The interface in
`src/lib/health/types.ts` is copied **verbatim** from
`03-plugin-bridge-spec.md` §3 (treat as frozen; changes go through both
lanes). The web mock honours the permission-state rule — three states, never
`denied` — and the UI does the same everywhere.

To integrate: in `src/lib/health/index.ts`, replace the mock branch with
`registerPlugin<CorveoHealthPlugin>("CorveoHealth")` under
`Capacitor.isNativePlatform()`, keeping the mock for web. The shell itself
(Xcode project under `ios/`, `capacitor.config.ts`, `npx cap sync`) is the
native lane's to create — nothing in the web build assumes it yet.

**Bundle ID warning (risk register):** dev/TestFlight builds must use a
throwaway identifier under the AI Please Apple account. The production bundle
ID is only ever registered and first-uploaded from Corveo's account — a first
upload binds it permanently.

## 7. Environments & preview

Web preview: **https://corveo-bp-reset.vercel.app** (AI Please account for
now — decision recorded 5 Aug; transfer with the rest at handover). SPA
fallback: `vercel.json` rewrites all routes to `index.html`. The preview
exists so the team and Corveo can click the flow without a device; the
product remains the iOS app.

Deploys are manual. The Vercel project is **not** connected to the repo, so
merging a PR changes nothing until someone deploys. From this directory:

```bash
vercel --prod --yes
```

That is the Vercel CLI, authenticated and linked as of 16 Aug 2026 —
`.vercel/project.json` holds the project and org ids and is gitignored.
Project `corveo-bp-reset`, team `obeyd`, aliased to the URL above. Two things
to know before running it:

- **It deploys the working tree, not the branch.** Uncommitted files go live
  and committed-but-unpushed work is included. Check `git status` first, or
  the preview ends up ahead of the repo.
- `VITE_DEMO=true` is set on the project, so the "Reset demo data" card
  survives a production build. It needs to stay set: the mock persists to
  `localStorage`, so without that card anyone who used an earlier build is
  stuck with stale state and no in-app way to clear it.

## 8. Contractual guardrails as implemented (quick audit map)

| Rule | Where enforced |
|---|---|
| No interpretation/thresholds/zones/alerts | No evaluative code paths exist; chart is ink-only (`BpChart.tsx`); copy files carry the discipline |
| Locked verb set, "alongside your care" | All strings in `src/copy/*` — journey.ts, app.ts, safety.ts, consent.ts |
| Validation is mechanical | `bounds.ts` + fixed copy in `validation.ts` ("Please check this value.") |
| Never render "denied" | `health/types.ts` PermissionState + neutral nudge copy in journey.ts |
| Consent evidence | `consent.ts` versions + hashes the exact text; receipt shown in Settings |
| Deletion-with-logging framing | Settings delete confirm copy; mechanism is server-side (Ben) |
| No health values leave the device | No analytics/crash SDKs; no console logging of readings |
| Synthetic data only | `src/lib/mock/fixtures.ts` deterministic generator (also the Stage-1 fixtures task) |

## 9. Open items (front-end lane)

| # | Item | Blocked on |
|---|---|---|
| F-A | Real auth (email+password, Sign in with Apple, anonymous bootstrap) | Ben's auth config |
| F-B | Consent write path in the API contract | Ben (spec addition) |
| F-C | Final consent + collection-notice text (Deliverable 13) | Corveo adoption |
| F-D | Final safety copy wording | Corveo |
| F-E | Education content (6 weeks, signed off) | Corveo (client dependency 5) |
| F-F | reckless/haffer font files or license | Corveo/Userkind |
| F-G | ~~Figma visual QA pass against Userkind components~~ Done 15 Aug. Findings: the file is the **website** design system — it contains no iOS app screens, so this build is the first iOS design expression, derived from its components. Confirmed alignments: black pill CTAs, pill segmented toggle (Sign in/Sign up pattern), label-above bordered inputs, card language. Adopted: real corveo logotype (from the shipped site's `/brand/logo.svg`). To raise at the Userkind session: primary CTAs in Figma carry a `→` suffix; functional/auth headings are sans-bold (serif is editorial) — our screens use serif titles; web form errors use red, ours stay ink-toned (deliberately conservative near readings); the "corveo prevent" sub-brand (violet) may or may not apply to BP Reset. Design System page canvas is empty — tokens live as Figma variables, so a variables export (or Dev-Mode access) is still wanted to replace the live-site extraction. | — |
| F-H | Cuff list confirmed against current STRIDE BP register | before Stage 3 |
| F-I | Local notifications for cadence reminders | native shell (Luca) |
| F-J | Offline buffer decision for manual entry (open item D-04) | Ben/Luka decision |
| F-K | No-consent path: can a user decline consent and still use the education program? Currently consent is required to proceed — the flow makes no promise otherwise. Product/regulatory call. | Corveo decision |

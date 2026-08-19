# 04 — Front End

**Owner:** Michael · **Status:** v0.2, 17 Aug 2026 · **Lane:** Front end

What exists, how to run it, and how the other lanes hook in. Written as built,
per SOW A.14.2. Read `01-system-architecture.md` §2 first — the build
constraints are contractual.

**This revision is the handoff.** The screen layer is complete and verified
against mocks; §10 lists the holes each lane needs to close. Read §9 (scope
boundary) and §10 before wiring anything to a database — and **§10.0 first**,
which collects the failures that produce no error message.

---

## 1. What exists

The complete V1 screen flow, running on synthetic data behind a mocked API and
a mocked HealthKit plugin. Every screen renders from the Corveo/Userkind design
tokens. TypeScript strict, tests on the validation and fixture logic, clean
production build (`tsc --noEmit && vite build`, 10/10 tests, verified 17 Aug).

**Journey (5 steps, SOW Deliverable 5)** — unchanged since v0.1:

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

**App — 3 tabs plus stack screens.** The tab bar is icon-only (`TabBar.tsx`):
program left, record centre as the home of the app, Learn right. Labels are on
the accessible name rather than on screen.

| Route | Screen | Deliverable | Scope |
|---|---|---|---|
| `/app/record` | **My Heart Record** — trend chart and history on one screen | D4 + D6 | In scope |
| `/app/program` | Program tab — active program, chapter list | D7 | In scope |
| `/app/education` | Learn tab — The Pulse rail + In Focus list | — | **Change request** |
| `/app/add` | Manual entry, same ingest path as the plugin | D4 | In scope |
| `/app/settings` | Settings — health status, export, deletion, consent receipt, **safety surface**, cuffs link | D12 (+ D8 entry) | In scope |
| `/app/cuffs` | Validated cuffs, STRIDE BP cited as the authoritative source | D8 | In scope |
| `/app/program/:slug/:week` | Chapter reading view | D7 | In scope for the core program |
| `/app/program/browse` | Program catalogue — follow / unfollow | — | **Change request** |
| `/app/program/:slug` | Program detail (non-core programs) | — | **Change request** |
| `/app/education/pulse/:slug` | Full-screen swipe viewer (scroll-snap) | — | **Change request** |
| `/app/education/in-focus/:slug` | Long-read article template | — | **Change request** |

`/app/readings` and `/app/trend` still resolve — both redirect to `/app/record`,
so anything written against the v0.1 route names keeps working.

**Three IA changes since v0.1, all deliberate:**

1. **Readings and Trend merged into one tab** (`Record.tsx`). They are the same
   data at two grains — the chart summarises the list, the list is the chart's
   detail. D4 and D6 remain separate deliverables, demonstrated independently;
   only the presentation merged. Display-only discipline is unchanged: the
   chart is monochrome, with no thresholds, zones, bands or annotations.
2. **The safety surface (D12) and validated-monitor list (D8) live in
   Settings.** They moved to Education and back again. This is final. → *Nick:
   the Stage 2 and Stage 3 test scripts still reference the old location.*
3. **The Learn tab is the publication**, not a settings drawer — The Pulse
   (short reads) and In Focus (long reads), mirroring the website's two
   collections. Change-request scope; see §9.

## 2. Running it

```bash
nvm use            # Node 20
npm install
npm run dev        # http://localhost:5184 — port is pinned, strictPort
npm test           # vitest — validation bounds + fixture logic (10 tests)
npm run build      # tsc --noEmit && vite build
```

No `.env` needed yet — everything runs on the mock layer. A shared web preview
deploys to Vercel from this branch (see §8).

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

Figma pass (15 Aug): the Corveo UI Design file is the **website** design
system — it contains no iOS app screens, so this build is the first iOS
expression of the language, derived from its components. Confirmed alignments:
black pill CTAs, pill segmented toggle, label-above bordered inputs, card
language. Adopted the real corveo logotype from the site's `/brand/logo.svg`.
Questions still open for the Userkind session are listed at C-9 in §10.4.

## 5. Data layer — how Ben hooks in

Screens never touch an implementation. They import from `src/lib/api`
(`getApi()` + React Query hooks in `hooks.ts`), typed by the `CorveoApi`
interface in `src/lib/api/types.ts`, whose shapes mirror
`02-data-model-and-api.md` Part 4: the four views (`v_bp_readings`,
`v_bp_trend`, `v_consent_status`, `v_program_progress`), the
`ingest_observations` RPC (request, response, stable rejection reasons), and
export.

To integrate: implement `CorveoApi` over supabase-js (or straight PostgREST
fetch), swap it into `src/lib/api/index.ts`, delete `src/lib/api/mock.ts` and
`src/lib/mock/`. Nothing else changes.

Notes from building against the spec:
- Manual entry submits through the same `ingest_observations` shape as the
  plugin (`source_type: "manual"`, `source_user_entered: true`, arm carried as
  SNOMED `body_site_code` + `context.arm`). Bounds mirrored from
  `observation_definition` seeds (sys 60–260, dia 30–160, sys > dia) in
  `src/lib/api/bounds.ts` — one place to keep in sync with the DB.
- Trend consumes the daily grain as documented (D-02: daily confirmed fine
  from the front-end side).
- Export calls `exportPatientData()` and downloads a CSV in the browser; on
  device the files go to the iOS share sheet (docs/02 §4.4).
- Deletion calls `requestAccountDeletion()` and then resets local state. The
  deletion-with-logging mechanism is server-side and untouched by the UI.

**Three contract gaps sit in §10.1 — read them before implementing.**

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

## 7. Placeholder content — what is real and what is not

Four copy files carry placeholder content, all following one rule: bodies
exist only for purely descriptive topics (measurement mechanics, how the
record works). Anything answer-shaped — diet, caffeine, medication, cardiac
recovery — is card metadata only and renders as pending. Placeholder text must
never put words in Corveo's mouth on a clinical subject.

| File | Holds | Replaced by |
|---|---|---|
| `copy/program-placeholder.ts` | The six-week curriculum shape | Corveo's signed-off content (D7, client dependency 5) |
| `copy/programs-placeholder.ts` | Catalogue of 5 programs | CR approval + a served catalogue |
| `copy/library-placeholder.ts` | 6 Pulse + 4 In Focus items | CR approval + content pipeline decision |
| `copy/safety.ts`, `copy/consent.ts` | Safety wording, consent text | Corveo's final wording (D12, D13) |

The containers do not change when real content lands — the shapes mirror
Userkind's CMS collections deliberately.

## 8. Environments & preview

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

## 9. Scope boundary — read before integrating

Two features in this build sit **outside the sixteen deliverables**:

- **Programs library** — the catalogue, follow/unfollow, and the four non-core
  programs (`/app/program/browse`, `/app/program/:slug`).
- **Learn tab** — The Pulse and In Focus (`/app/education/*`).

Both were built so the information architecture could be reviewed as a whole,
and both are gated behind placeholder content. CR-1 in the Notion tracker
covers the Learn tab; the programs library still needs raising, and the
`v_program_progress` change at B-2 belongs in that estimate.

Practical consequence for the platform lane: **do not build schema for the
programs library on the strength of it existing in the code.** The core
six-week program (D7) is in scope and needs persistence; the rest waits on
approval. Follow state deliberately lives in `localStorage`
(`corveo.programs.v1`, `lib/useFollowedPrograms.ts`) rather than on the API for
exactly this reason — it is a holding position, not a design.

## 10. Holes to close — by lane

### 10.0 Silent failures — read this one first

Most of the holes below announce themselves: something is missing, a build
fails, a screen is empty. These seven do not. They fail with no error, no
console warning and no empty state — the app keeps rendering something
plausible, which is what makes them expensive to find later.

| Where | What silently goes wrong | How you'd catch it |
|---|---|---|
| **`completed_steps` key format** (B-3) | If the server writes a different key shape, every chapter reads as unread. No error, no empty state — just a list nobody has ticked. The mock seeds the legacy `"week-1"` key, so the back-compat path is the one exercised today. | Settle the format (B-3), then check a read chapter stays read across a reload against the real view. |
| **Consent receipt** (B-1) | Settings renders the receipt only when `has_active_consent`, `version` and `last_event_at` are all present (`Settings.tsx:130`). A consent write that lands a different shape makes the receipt quietly disappear — and the receipt is the evidence surface for a contractual requirement. | After implementing the consent write path, confirm the receipt renders. Its absence looks like a design choice, not a bug. |
| **Data-quality bounds drift** | `bounds.ts` mirrors the `observation_definition` seeds **by hand** (sys 60–260, dia 30–160). If the DB values change, the app validates against the old numbers and accepts or rejects differently from the server. Nothing compares the two. | Treat `bounds.ts` as owned by whoever changes the seeds; re-check at integration. |
| **Follow state** (§9) | Which programs a reader follows lives in `localStorage` (`corveo.programs.v1`). Reinstall the app or clear storage and it is gone, with no server copy and nothing to restore from. Acceptable while the library is unapproved; not acceptable if it ships. | B-2 — a program identifier on the contract is the fix. |
| **Mock persistence** | The mock store (`corveo.mock.v1`) survives reloads *and* code changes. After a shape change, an old store can render stale or half-broken state that looks like a UI bug. | "Reset demo data" in Settings clears it — which is why `VITE_DEMO=true` has to stay set on the preview (§8). |
| **Heights measured at mount** | `PulseViewer` computes slide offsets from `clientHeight`. When that is 0 at mount, a deep link lands on slide 1 while the counter says otherwise — wrong content, no error. Guarded with `useLayoutEffect` + `ResizeObserver` + a zero-height guard in `onScroll` (`PulseViewer.tsx:89–113`), but the class recurs anywhere a height is read at mount. | Device pass (L-5). Browser DOM checks cannot see it. |
| **Working-tree deploys** | `vercel --prod --yes` ships whatever is on disk, including uncommitted files. The preview can run ahead of the repo, so a bug you cannot find in the branch may be live. | `git status` before deploying (§8). |

### 10.1 Ben — platform

| # | Hole | What's needed |
|---|---|---|
| B-1 | **Consent write path is undefined in docs/02 Part 4.** The mock invented `recordConsentEvent({action, version, document_hash, method})`. | An RPC or insert policy with an equivalent shape. Consent evidence is contractual, so this one is not optional. |
| B-2 | **`v_program_progress` carries no program identifier**, so nothing multi-program can persist — one `current_week` integer cannot gate several programs independently. | Spec decision. Only bites if the programs library is approved, but the CR estimate needs the answer either way. |
| B-3 | **`completed_steps` key format is undefined.** The front end writes `"<slug>:<n>"` and still reads legacy `"week-N"` for the core program (`lib/programs.ts:94`). | Settle the format in the spec. Cheap while it is only mock data; a silent progress mismatch at integration otherwise. The back-compat read comes out once it is fixed. |
| B-4 | Real auth — email + password, Sign in with Apple, anonymous bootstrap. Signup is MOCK and writes `adult_attested` locally. | Supabase auth config, then swap the mock. |
| B-5 | Offline buffer for manual entry (open item D-04). | Decision with Luca: buffer locally, or fail the write. |
| B-6 | Export file set — the UI downloads a single CSV; docs/02 §4.4 describes handing files to the share sheet. | Confirm what the server generates and how many files. |

### 10.2 Luca — native shell

| # | Hole | What's needed |
|---|---|---|
| L-1 | Capacitor shell, Xcode project, `capacitor.config.ts`. No Capacitor dependency is installed — the major version is yours to pick. | The shell, then `npx cap sync`. |
| L-2 | Swap the plugin mock in `src/lib/health/index.ts` under `Capacitor.isNativePlatform()`, keeping the mock for web. | Interface is frozen — see §6. |
| L-3 | **Throwaway bundle ID for anything uploaded.** | See §6 and the risk register: a first upload binds the identifier permanently. |
| L-4 | Local notifications for cadence reminders. Reminders are rhythm-based and **never reading-triggered**. | Native scheduling. |
| L-5 | **Checks the web preview cannot make**: scroll-snap momentum in the Pulse viewer, safe-area insets (`--safe-bottom` on the tab bar), and `position: fixed` behaviour — on the desktop preview the viewer anchors to `#root` because the phone frame sets a transform. | A pass on a physical iPhone. |

### 10.3 Nick — docs and validation

| # | Hole | What's needed |
|---|---|---|
| N-1 | **Stage 2 and Stage 3 test scripts reference the old locations** of the safety surface (D12) and the cuffs list (D8). Both are in Settings now, and final. | Update the scripts. |
| N-2 | D4 and D6 now render on one screen (`/app/record`), but remain separate deliverables. | Keep them as separate demonstrated steps in the script. |
| N-3 | Privacy policy, terms and support URL — filed as risks; the first blocks App Store submission outright. | Corveo-side content. Chase, and verify the pages actually render rather than link-check them. |

### 10.4 Corveo / Userkind — client dependencies

| # | Item |
|---|---|
| C-1 | Six weeks of education content, clinically signed off (D7, client dependency 5) |
| C-2 | Final consent + collection-notice text (D13) |
| C-3 | Final safety copy wording (D12) |
| C-4 | Licensed reckless/haffer font files, or a hosted license |
| C-5 | Figma variables export — the Design System page canvas is empty, tokens live as variables |
| C-6 | CR-1 decision, plus the content pipeline: bundled vs CMS feed |
| C-7 | **No-consent path**: can a user decline consent and still use the education program? Consent is currently required to proceed and the flow makes no promise otherwise. Product and regulatory call. |
| C-8 | Cuff list confirmed against the current STRIDE BP register (before Stage 3) |
| C-9 | Userkind session questions: `→` suffix on primary CTAs; functional/auth headings are sans-bold in Figma while our screens use serif; web form errors are red, ours stay ink-toned; whether the "corveo prevent" sub-brand applies to BP Reset |

## 11. Contractual guardrails as implemented (quick audit map)

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
| Placeholder content never interprets | Answer-shaped topics render as pending — see §7 |

## 12. Copy voice — how we write user-facing language

Set 19 Aug 2026 (see decision F-06). These rules cover every user-visible
string in the app, all of which live in `src/copy/`. They sit on top of the
regulatory copy discipline (locked verb set, display-never-interpret), which
always wins on any conflict.

- **No em dashes in user-facing strings.** Use a full stop, comma, colon or
  parentheses instead. Code comments may keep them; the rule is about what
  renders on screen.
- **Australian English.** Spelling (organise, colour, millimetres,
  personalised) and en-AU date/number formats (`lib/format.ts`).
- **Borrow the shipped site's language.** corveo.vercel.app is the voice
  reference: "A clearer way to understand your…", "evidence-based education",
  "minus the wellness hype", sentence-case headings. When writing new copy,
  check how the site says it before inventing a phrasing.
- **Warm, plain, human.** Short sentences over stacked clauses; "No worries"
  register is fine at friendly moments. Avoid AI-flavoured constructions:
  three-adjective stacks, "not just X, but Y", "-ing" trailers tacked onto
  sentences for fake depth.

Out of bounds for style edits: `copy/validation.ts` (frozen verbatim, docs/02
§1.3), the `noSamplesNudge` string (verbatim from docs/03 §4), and
`copy/consent.ts` (Deliverable 13 draft — Corveo approves that wording; note
its rendered text is hashed, so any change produces a new consent version).

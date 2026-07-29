# Corveo — BP Reset V1

Native iOS app for the six-week Blood Pressure Reset program. Capacitor shell around a React front end, custom Swift HealthKit plugin, Supabase backend in Corveo's Sydney project.

Built by AI Please Pty Ltd for Intelecor Pty Ltd trading as Corveo, under SOW-2026-001.


## Read this before you write any code

**[`docs/01-system-architecture.md` §2](docs/01-system-architecture.md)** lists the build constraints. They are contractual, not stylistic — several of them prohibit things a reasonable engineer would otherwise add without thinking (a colour band on a chart, a crash reporter, a "your reading is high" toast).

Breaking one is not a bug we fix later. It is a variation to a signed agreement.

Then read the design doc for your lane.

## Documentation

Design docs live in `docs/`. Each answers a different question — go to the one that matches what you're stuck on.

| Doc | Answers | Read it if you're |
|---|---|---|
| `01-system-architecture.md` | What are the pieces, where are the boundaries, what must we never build? | Everyone, once |
| `02-data-model-and-api.md` | What does the schema look like, what does the API return, how does auth work? | Ben, Michael |
| `03-plugin-bridge-spec.md` | What does the native plugin expose, and what does it guarantee? | Luca, Ben |

`01-system-architecture.html` is the same content with rendered diagrams — open it in a browser if the Mermaid source is hard to follow.

Decisions made during the build are appended to `docs/decisions.md`, one paragraph each: context, choice, consequence. Add to it rather than re-litigating in Slack.

## Lanes

| Lane | Owner | Scope |
|---|---|---|
| Native / mobile | Luca | HealthKit plugin, Capacitor shell, build and TestFlight pipeline |
| Front end | Michael | React app, screens, design system integration |
| Platform | Ben | Supabase schema, RLS, ingest, privacy features, API |
| Docs, validation, delivery | Nick | Contract docs, test scripts, submission package, App Store submission |

Luca's plugin is built and proven in isolation first. The interface it will expose is frozen in `03-plugin-bridge-spec.md` — treat it as fixed, and raise changes rather than making them.

## Repo layout

```
├── ios/                    Native shell, Swift plugin, Xcode project
├── src/                    React front end
│   ├── components/         UI, semantic tokens only — no raw hex or px
│   ├── copy/               All user-facing strings, incl. validation copy
│   └── lib/                Supabase client, plugin bindings
├── supabase/
│   ├── migrations/         Versioned SQL, forward-only
│   └── seed/               Synthetic data generators
├── docs/                   Design docs, decisions log
└── .github/workflows/      Build, test, migration pipelines
```

## Getting started

**Prerequisites**

| Tool | Version | Note |
|---|---|---|
| Node | 20.x LTS | Pinned in `.nvmrc` |
| Xcode | 16.x | Pinned in `.xcode-version` |
| iOS deployment target | 16.0 | Minimum supported |
| Supabase CLI | latest | For local schema work |
| Physical iPhone | any, iOS 16+ | HealthKit background delivery does not work in the simulator |

```bash
nvm use
npm install
cp .env.example .env.local     # dev project credentials — ask Ben
npm run dev                    # web preview, mocked plugin
```

For device builds:

```bash
npm run build
npx cap sync ios
npx cap open ios               # then run from Xcode on a physical device
```

The API mock Michael codes against is generated from `docs/api/openapi.yaml`. Regenerate after any contract change:

```bash
npm run mock:generate
```

## Conventions

**Branches** — `lane/short-description`, e.g. `native/observer-query`, `platform/rls-policies`. Merge to `main` by PR.

**Pull requests** — the template includes a constraints checklist. It is not a formality; tick it honestly. PRs touching `supabase/migrations/` need Ben's review, PRs touching `ios/` need Luca's.

**Migrations** — forward-only, one concern per file, never edited after merge. Applied to production through CI using Corveo's credential, never from a local terminal.

**Secrets** — the Supabase `service_role` key never appears in this repo, in the app bundle, in CI logs, or on any AI Please machine. It bypasses RLS entirely. Local dev uses the `dev` project only.

**Synthetic data only** — no real patient data enters `dev` or `staging` at any point. This is a contractual commitment, not a habit.

**Dependencies** — adding any third-party SDK that transmits data off-device requires sign-off before the PR is opened. See `01-system-architecture.md` §2.


## Environments

Three: `dev` (ours, synthetic), `staging` (Corveo's, synthetic, feeds TestFlight), `prod` (Corveo's, Sydney). Details and key custody in `02-data-model-and-api.md` §5.

Corveo holds all credentials and account ownership for `staging` and `prod` at all times.

Commercial in confidence. Internal use only.

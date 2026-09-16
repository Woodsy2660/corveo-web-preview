# UX Audit and Implementation Task List

| | |
|---|---|
| **Version** | 0.2 — restructured as a task list |
| **Date** | 4 September 2026 |
| **Owner** | Ben |
| **Implementer** | Claude Code |
| **Supersedes** | v0.1 (audit findings only) |
| **Changes in 0.2** | Restructured into executable tasks; contrast table recomputed and corrected; three WCAG claims corrected; graph redesign section added (§9); Dynamic Type bridge added as an actionable fix |

---

## How to use this document

Part A is the work. Each task has an ID, acceptance criteria, and a reference to the audit section that justifies it. Parts B and C are the evidence — read the referenced section before implementing a task.

**Work in priority order.** P0 tasks are accessibility defects affecting an audience that cannot work around them. Do not start P2 while P0 remains open.

**Tasks marked ⛔ are blocked** and must not be implemented without the named sign-off. Implementing a blocked task is worse than leaving it undone, because two of them carry contractual exposure.

**Before any task:** read `docs/01-system-architecture.md` §2. Those constraints bind everything here.

---

# PART A — TASKS

## P0 — Accessibility defects

### UX-01 · Remove `user-scalable=no`
**File:** `index.html:7` · **Ref:** §6.1

Change the viewport meta to `width=device-width, initial-scale=1.0, viewport-fit=cover`. Keep `viewport-fit=cover` for safe-area insets. Drop `user-scalable=no` and add nothing in its place — no `maximum-scale`.

*Why:* pinch-to-zoom is currently disabled. Combined with UX-02, a user on the largest iOS text setting sees no change anywhere in the app and cannot zoom either. For a 60+ audience this is the single highest-impact defect in the file.

**Accept when:** pinch-to-zoom works on a physical device on every screen; safe areas still render correctly on a notched device.

---

### UX-02 · Bridge iOS Dynamic Type into the WebView
**Files:** native plugin + `app.css` · **Ref:** §6.7 · **Owner:** Luca + Michael

The app is a WebView, so CSS pixel sizes do not respond to iOS Dynamic Type. This is fixable, not inherent.

Native side: read `UIApplication.shared.preferredContentSizeCategory`, map it to a scale factor, expose it to the WebView, and re-emit on `UIContentSizeCategoryDidChangeNotification`.

Web side: apply the factor to the root font size and convert the type scale from `px` to `rem` so every token scales together. Clamp the factor (suggest 0.9–1.6) so layout does not break at the accessibility sizes.

*Why:* the audience most likely to have raised their system text size currently gets no benefit from having done so.

**Accept when:** changing iOS text size in Settings visibly changes app text without a relaunch; no screen breaks at the maximum clamped size.

---

### UX-03 · Fix checkbox touch targets
**Files:** `Signup.tsx:49`, `Consent.tsx:64` · **Ref:** §6.4

Both checkboxes render at 18×18px. Wrap each in a container providing a minimum 48×48px hit area, keeping the visual control at its current size. Verify the `<label>` association still works.

*Why:* these two controls gate account creation and consent. They are the least forgiving targets in the app and sit on the two screens a user cannot skip.

**Accept when:** the tappable region measures ≥48×48px on both; tapping near but not on the visual box still toggles.

---

### UX-04 · Fix remaining sub-48px targets
**Files:** `Segmented.tsx:30` (~22px tall), `Record.tsx:178` sync pill (~28px) · **Ref:** §6.4

Raise both to a 48px minimum hit area. Visual size may stay smaller; the hit area may not.

`BehindTheScenes.tsx:179` (36px) is a presentation surface, not product. Leave it.

**Accept when:** every interactive element in `/app` and `/journey` has a ≥48×48px hit area.

---

### UX-05 · Replace `text-ink-tertiary` for body-weight text
**Ref:** §6.5 (corrected table)

`#808080` measures **3.40:1** on the page background and **3.95:1** on card. Both fail WCAG AA (4.5:1) for normal-size text.

Used for eyebrow labels, source notes, reminder notes, chart legend text, and the education disclaimer. Replace with `text-ink-secondary` (`#4d4d4d`) wherever it carries readable content. `#4d4d4d` measures 7.27:1 on page and 8.45:1 on card — comfortably AAA.

Keep `#999` for genuinely disabled controls only.

**Accept when:** no text below 18.66px uses `#808080`; a repeat contrast pass shows no pair under 4.5:1 outside disabled states.

---

## P1 — Text density restructure

### UX-06 · Build an expandable disclosure component
**New:** `src/components/ui/Disclosure.tsx` · **Ref:** §7.4, §8.5

No accordion, expandable, bottom sheet, modal or "read more" pattern exists anywhere in the app, and none exists in the Userkind system either (§8.5) — so this is ours to build.

Requirements: expands **in place** without navigation; ≥48px header hit area; `aria-expanded` and `aria-controls`; visible focus state; chevron or equivalent affordance; honours `prefers-reduced-motion`; no status colour.

*Why in place:* for older users, navigating to a detail page and finding the way back is where confidence breaks down. Expanding in position preserves context.

**Accept when:** VoiceOver announces expanded and collapsed states; keyboard-operable; used by UX-07 and UX-08.

---

### UX-07 · Restructure Intro
**File:** `Intro.tsx` · ~142 words, 3 stacked cards, longest block 45 words · **Ref:** §5

Reduce to what fits without scrolling at 390×844 at default type size. Move the rest behind `Disclosure`.

Suggested: each card keeps its heading plus its first sentence; remaining sentences move into an expandable. The disclaimer stays visible.

⚠️ **Move sentences, do not cut or reword them.** If a restructure would require rewriting, stop and flag it as `REQUIRES CLIENT CONTENT SIGN-OFF` (see §11).

**Accept when:** the screen does not scroll at default type size; every original word is still reachable; word count above the fold under ~70.

---

### UX-08 · Restructure Connect
**File:** `Connect.tsx` · ~127 words, 4 containers, conditional cuff list · **Ref:** §5

The three options stay visible — they are the decision. The validated-cuff list (36 words, appears when "none" is selected) moves into a `Disclosure` rather than expanding the page inline.

**Accept when:** the three options are visible without scrolling; selecting "none" does not push the CTA below the fold.

---

### UX-09 · Consent — layout only
**File:** `Consent.tsx` · ~148 words, heaviest journey screen · **Ref:** §5, §11

⛔ **The text may not be shortened, split behind a disclosure, or reworded.**

It carries an express-consent obligation under APP 3.3, and `consent_event.document_hash` is a SHA-256 of the exact text displayed. Relocating any of it changes what the hash attests to.

Permitted: type size increase, line height, spacing between points, scroll affordance so it is obvious more content follows, and the UX-03 checkbox fix.

**Accept when:** the rendered consent string is byte-identical to before; readability improved by the permitted means only.

---

### UX-10 · Raise the body type floor
**Files:** `tokens.css` + call sites · **Ref:** §6.2

`--text-body-sm` at 14px carries the heaviest load in the app — consent copy, option bodies, field labels, reading rows, disclaimers.

Two options, decide before starting:
- **(a)** Raise `--text-body-sm` to 16px and `--text-body-base` to 18px. One change, propagates everywhere, will affect layouts.
- **(b)** Leave the token and migrate the heaviest call sites (`Intro`, `Consent`, `Connect`, `Cadence`, `Record`) to `--text-body-base`.

Recommend (a), combined with UX-02 so users can scale further from a better starting point.

Note honestly: **18px is not a WCAG requirement** — WCAG specifies no minimum font size (see corrections log). It is a readability convention for older adults and a deliberate project standard.

`--text-label` at 12px should rise to 14px minimum where it carries meaning rather than decoration.

**Accept when:** no user-facing body text below 16px; no layout overflow at the new sizes.

---

### UX-11 · Fix Pulse card contrast
**File:** `Education.tsx:48-58` · **Ref:** §6.8

White serif text over photographs with a 40% black scrim. Contrast depends entirely on the image and is untestable as built.

Fix by one of: raise the scrim to 60–70%, add a bottom-anchored gradient behind the text block, or move text below the image. Do not rely on per-image tuning.

**Accept when:** measured contrast ≥4.5:1 against the lightest pixel region behind text, on every Pulse card.

---

## P2 — Structural

### UX-12 · Card variants for short vs long content
**File:** `Card.tsx` · **Ref:** §7.3

One `Card` serves a 10-word line and a 45-word paragraph identically. Add `compact` and `default` variants differing in padding, so short content stops consuming the vertical space of long content.

Also: the radio-style options in `Connect` and `Cadence` reimplement Card styling inline (§7.3). Consolidate.

---

### UX-13 · Reading list parity with the chart
**File:** `Record.tsx` · **Ref:** §9.6

Deliverable 6 contracts "a trend chart over time plus a reading list." Evidence in §9.6 suggests the list may matter more than the chart to this audience. Ensure the list is not treated as secondary: reachable without scrolling past the chart, and legible at the UX-10 type sizes.

---

## P3 — Signup screen (design already agreed, see §10)

### UX-14 · Add password field
### UX-15 · Add sign-in mode toggle
### UX-16 · Add auth copy constants

Detail in §10. Auth error copy must be mechanical — `"Please check your email and password."` — never diagnostic about which field failed.

---

### UX-B1 · Reference lines at systolic 120 / diastolic 75
**Blocked pending:** Andrew + Corveo's regulatory contractor · **Ref:** §9.1

Agreed verbally on 3 September. **Do not build.** See §9.1 for why an unlabelled line at these values is a clinical threshold under SOW A.3.3, and §9.4 for the compliant alternative that achieves the same goal.

### UX-B2 · Greyed normal/abnormal bands
**Blocked pending:** same · **Ref:** §9.1

From the ABPM reference format. A.3.3 prohibits "colour zone or band" without qualification. Grey is a colour.

### UX-B3 · Any education content rewording
**Blocked pending:** Andrew's clinical sign-off · **Ref:** §11

Chunking and pacing are ours. Words are his.

---

# PART B — AUDIT FINDINGS

## 5. Screen inventory

Every route, sorted by word count. User-facing copy only.

| # | Route | Component | Purpose | Words | Longest block | Ideas | Scrolls? | CTA visible? |
|---|-------|-----------|---------|-------|---------------|-------|----------|--------------|
| 1 | `/journey/consent` | `Consent.tsx` | Express consent | ~148 | 42 | 6 | Yes | Yes |
| 2 | `/journey/intro` | `Intro.tsx` | Program expectations | ~142 | 45 | 5 | Yes | Yes |
| 3 | `/app/record` | `Record.tsx` | Chart, average, history | ~130 | 33 | 7+ | Yes | Below chart |
| 4 | `/journey/connect` | `Connect.tsx` | Choose data source | ~127 | 36 | 4–7 | Yes | Yes |
| 5 | `/app/program/:slug/:week` | `Chapter.tsx` | Week's education | ~120+ | 40–60 | 4–6 | Yes | Yes |
| 6 | `/app/settings` | `Settings.tsx` | Profile and menu | ~110 | 30 | 8 | Possibly | Yes |
| 7 | `/app/settings/about` | `About.tsx` | Safety surface | ~108 | 36 | 4 | Yes | Back |
| 8 | `/app/settings/data` | `YourData.tsx` | Export, deletion | ~82 | 38 | 5 | Yes | Yes |
| 9 | `/journey/cadence` | `Cadence.tsx` | Reading rhythm | ~82 | 27 | 5 | Borderline | Yes |
| 10 | `/journey/health-auth` | `HealthAuth.tsx` | Apple Health auth | ~65 | 44 | 2 | No | Yes |
| 11 | `/app/settings/apple-health` | `AppleHealth.tsx` | Connection status | ~64 | 30 | 5 | No | Yes |
| 12 | `/journey/capture` | `FirstCapture.tsx` | First reading | ~58 | 28 | 3 | Borderline | Yes |
| 13 | `/app/cuffs` | `ValidatedCuffs.tsx` | Cuff list | ~55 | 36 | 5 | Possibly | Back |
| 14 | `/journey/result` | `Result.tsx` | First reading in context | ~48 | 36 | 3 | No | Yes |
| 15 | `/journey/signup` | `Signup.tsx` | Create account | ~32 | 20 | 3 | No | Yes |
| 16 | `/app/education` | `Education.tsx` | Learn tab | ~22 | 14 | 3 | Possibly | Yes |
| 17 | `/app/program` | `Program.tsx` | Chapter list | ~20 | 16 | 3 | Yes | Yes |
| 18 | `/app/add` | `ManualEntry.tsx` | Add reading | ~16 | 8 | 2 | No | Yes |
| 19 | `/journey/welcome` | `Welcome.tsx` | Landing | ~4 | 1 | 1 | No | Yes |
| 20 | `/behind` | `BehindTheScenes.tsx` | Presentation | Varies | — | — | No | Yes |

**Five heaviest, in restructure priority:** Intro (UX-07), Connect (UX-08), Record (§9), Chapter (blocked, §11), Consent (layout only, UX-09).

Every journey screen pins its CTA in a footer, so the primary action is always visible. Keep this.

---

## 6. Accessibility audit

### 6.1 Viewport meta
`index.html:7` — `content="width=device-width, initial-scale=1.0, viewport-fit=cover, user-scalable=no"`. See UX-01.

### 6.2 Font sizes

| Token | Size | Used for |
|---|---|---|
| `--text-label` | 12px | Eyebrow labels, source notes, card labels |
| `--text-body-sm` | 14px | Card body, field labels, disclaimers, checkbox labels |
| `--text-body-base` | 16px | Body default, buttons, inputs |
| `--text-body-lg` | 18px | Chapter body, standfirst |

`--text-body-sm` at 14px is the workhorse: `Intro.tsx:29`, `Consent.tsx:53,67`, `Signup.tsx:53`, `Connect.tsx:51,61,66,74`, `Cadence.tsx:58,66`, `FirstCapture.tsx:29`, `Record.tsx:116,154,167,203,210`, `Field.tsx:18,30`, `ManualEntry.tsx:22`, `Education.tsx:97,122`, `Chapter.tsx:26,136,144,155`, `Settings.tsx:84,87`, and every settings sub-page.

Figma mobile equivalents are smaller still (`body-lg` 17, `body-base` 15, `body-sm` 13). The app rounds up. See UX-10.

### 6.3 Font weights
No user-facing text below 400. `figma-tokens.css:120` defines Light (300), unused. Acceptable, no action.

### 6.4 Touch targets

Project standard is **48×48px** — chosen for this audience, not a WCAG figure. For reference: WCAG 2.2 SC 2.5.8 requires 24×24 CSS px (AA), SC 2.5.5 requires 44×44 (AAA), Apple HIG recommends 44×44pt.

| File | Element | Size | Gap to 48px |
|---|---|---|---|
| `Signup.tsx:49` | Checkbox | 18×18 | −30px |
| `Consent.tsx:64` | Checkbox | 18×18 | −30px |
| `Segmented.tsx:30` | Segment button | ~22 tall | −26px |
| `Record.tsx:178` | Sync pill | ~28 tall | −20px |
| `BehindTheScenes.tsx:179` | Close | 36×36 | −12px (not product) |
| `StepDots.tsx:14` | Step dot | 6px | Not interactive — fine |

### 6.5 Contrast — recomputed

v0.1's on-white figures were correct; every figure against the page background was understated. Recomputed to WCAG 2.x relative luminance.

| Pair | Foreground | Background | Ratio | Verdict | v0.1 said |
|---|---|---|---|---|---|
| Heading on page | `#000` | `#f2ede9` | **18.07** | AAA | 15.5 |
| Primary on page | `#333` | `#f2ede9` | **10.87** | AAA | 9.1 |
| Secondary on page | `#4d4d4d` | `#f2ede9` | **7.27** | **AAA — passes** | 5.8, "fail AAA" |
| Tertiary on page | `#808080` | `#f2ede9` | **3.40** | **Fail AA** | 3.1 |
| Primary on card | `#333` | `#fff` | 12.63 | AAA | 12.6 ✓ |
| Secondary on card | `#4d4d4d` | `#fff` | **8.45** | **AAA — comfortable** | 7.0, "borderline" |
| Tertiary on card | `#808080` | `#fff` | 3.95 | Fail AA | 3.9 ✓ |
| Disabled on card | `#999` | `#fff` | 2.85 | Expected | 2.8 ✓ |
| Link on page | `#3e4fb5` | `#f2ede9` | **6.04** | AA, fails AAA | not measured |

Two conclusions change: `text-ink-secondary` is a **safe** replacement target for UX-05, not a marginal one. `text-ink-tertiary` still fails and is the only real defect here.

Link colour at 6.04:1 is adequate but will matter more once UX-06 introduces expandable links — keep it under review.

### 6.6 Line lengths
390px viewport, 24px side padding → 342px content. Roughly 40–48 characters at 16px, 48–58 at 14px. Both inside the 45–75 guideline. **No violations.** (v0.1's estimates ran slightly high; conclusion unchanged.)

### 6.7 Dynamic Type
None of the app's text responds to iOS Dynamic Type — all sizes are fixed CSS pixels in a WebView.

v0.1 described this as inherent to Capacitor. **It is not.** The native layer can read `preferredContentSizeCategory` and expose it to the WebView. See UX-02.

Until then, combined with `user-scalable=no`, a user on the largest system text setting sees no effect anywhere and cannot zoom either.

### 6.8 Text over images
`Education.tsx:48-58` — Pulse cards, white serif over photograph with `rgba(0,0,0,0.4)` scrim. Untestable as built. See UX-11.
`PulseViewer.tsx:42-68` — text on solid black. Fine.
`TabBar.tsx:34` — gradient fade, decorative. Fine.

---

## 7. Layout patterns

### 7.1 The Card
`src/components/ui/Card.tsx` — `rounded-md border border-hairline bg-card p-[var(--spacing-sm)]`. Padding 16px, radius 12px, background `#fff`, 1px `#ccc` border, no elevation.

### 7.2 Cards per screen
Intro 3 · Consent 4 · Connect 3+1 conditional · Cadence 3 · ValidatedCuffs 3 · ProgramIndex up to 5. Average 3–4.

### 7.3 One container, all content lengths
The same `Card` holds a 10-word line and a 45-word paragraph with identical padding. No compact variant. See UX-12.

`Connect` and `Cadence` options reimplement Card styling inline as `<button>` elements — visually identical, semantically separate. Consolidate.

### 7.4 Progressive disclosure

Present: readings show/hide (`Record.tsx:247`), conditional cuff list (`Connect.tsx:59`), inline delete confirm (`YourData.tsx:79`).

Absent entirely: accordion, expandable, collapsible, bottom sheet, drawer, modal, read-more, content tabs, interactive stepper.

Every screen presents everything at once. On Intro, Consent and Connect this produces a wall of white cards. This is the finding UX-06 through UX-08 address.

---

## 8. Userkind design system

### 8.1 Source and limitation
Extracted from `Corveo UI Design` (Figma key `xwz2b8vWOhSQhBeKIMmb9q`), Variables panel, 28 August 2026, recorded verbatim in `src/components/tokens/figma-tokens.css`.

**The Figma MCP returned no variables, styles or components** from this file or its two attached libraries ("central icon system", "Userkind's Team Colors"). All analysis below derives from the CSS export.

This is a real gap, not a null result — see §12.

### 8.2 Typography (mobile / tablet / desktop)

| Token | Mobile | Tablet | Desktop | Family |
|---|---|---|---|---|
| `heading-6xl` | 42 | 64 | 68 | Reckless |
| `heading-5xl` | 36 | 48 | 50 | Reckless |
| `heading-4xl` | 28 | 40 | 40 | Reckless |
| `heading-3xl` | 22 | 30 | 30 | Haffer |
| `heading-2xl` | 18 | 20 | 24 | Haffer |
| `heading-xl` | 16 | 18 | 20 | Haffer |
| `body-lg` | 17 | 18 | 18 | Haffer |
| `body-base` | 15 | 16 | 16 | Haffer |
| `body-sm` | 13 | 14 | 14 | Haffer |
| `body-xs` | 12 | 12 | 12 | Haffer |
| `label-base` | 14 | 15 | 16 | Haffer |
| `label-button` | 15 | 15 | 16 | Haffer |

Body copy is `body-base` at 15px mobile. Weights: Light 300, Regular 400, Medium 500, Bold 700; body uses Regular.

### 8.3 Spacing

| Token | Mobile | Desktop |
|---|---|---|
| `3xs` | 4 | 4 |
| `2xs` | 6 | 8 |
| `xs` | 10 | 12 |
| `sm` | 12 | 16 |
| `md` | 16 | 24 |
| `lg` | 24 | 32 |
| `xl` | 32 | 48 |
| `side-padding` | 12 | 48 |

Radius mobile: 0 / 3 / 6 / 10 / 100. Desktop: 4 / 8 / 12. No maximum content width defined.

### 8.4 Colour

Primitives: Neutral (13 stops), Blue, Brown, Beige (Beige-500 is teal `#1C7A8C` — intentional), plus **Warning**, **Information**, **Error**, **Success** ramps of 5 stops each.

Prohibited in BP Reset under A.3.3:

| Token | Value |
|---|---|
| `text/error` | `#ea2121` |
| `border/error` | `#ea2121` |
| `text/success` | `#0b8036` |
| Warning ramp | `#78350f` → `#fef9c3` |
| Error ramp | reds |
| Success ramp | greens |
| Information ramp | blues (distinct from brand blue) |

**The app currently uses none of them.** Validation copy is mechanical; error states use `text-ink-secondary` and a black border. Correct — maintain it.

### 8.5 Components

Searched for: accordion, modal, tabs, card, button, expandable, drawer, bottom sheet, stepper, disclosure, collapsible, progress.

**None found.** The file holds variable collections only. Card and Button do not exist as components either — they exist as token-layer patterns.

Needed for the restructure and not available:

| Component | For | Priority |
|---|---|---|
| Accordion / expandable | UX-06, UX-07, UX-08 | High |
| Auth form pattern | UX-14, UX-15 | High |
| Bottom sheet | Secondary detail | Medium |
| Inline "learn more" | Heavy cards | Medium |
| List row with disclosure | Settings, chapters | Low |
| Interactive stepper | Journey progress | Low |

### 8.6 Where the app diverges

| Area | App | Figma mobile | Deliberate? |
|---|---|---|---|
| `body-sm` | 14 | 13 | Yes — rounded up |
| `body-base` | 16 | 15 | Yes |
| `body-lg` | 18 | 17 | Yes |
| `heading-2xl` | 24 | 18 | Uses desktop value |
| `spacing-sm` | 16 | 12 | Uses desktop value |
| `spacing-md` | 24 | 16 | Uses desktop value |
| `radius-md` | 12 | 10 | Uses desktop value |

**The app uses the desktop column throughout.** This is right for the audience and should be recorded as a deliberate decision rather than left to look like an error — the Figma mobile scale is too small for 60+ users.

Matches: colour tokens, font families, weights, semantic aliases, border token, motion curve, and status-colour avoidance.

---

## 9. Graph redesign — Record screen

Source: meeting 3 September; research 4 September.

**Reference lines at systolic 120 / diastolic 75.**

These are not neutral anchors. In the ambulatory BP monitoring literature, the horizontal lines drawn on those reports are the commonly used static measures of upper limit of normal for daytime and nighttime — SBP 135/120 and DBP 85/75. Systolic 120 and diastolic 75 are precisely the **nighttime upper limits of normal**.

A.3.3 prohibits applying "a clinical threshold, colour zone or band." Leaving a line unlabelled does not change its function: the patient sees dots above and below it and draws the conclusion. Unlabelled is arguably worse — a verdict without the context that would make it safe.

**Greyed normal/abnormal bands.** The ABPM format uses a shaded grey region for the normal range. A.3.3 prohibits bands without qualifying on colour. Grey is a colour.

Both are Variations under A.10.2 requiring Corveo's regulatory contractor before build. **Andrew's clinical reasoning is sound** — averaging away a 200 systolic reading is genuinely dangerous and spikes are the signal. The constraint is on the mechanism, not the goal.

### 9.2 The current defect

The chart averages all readings per day. A 200 systolic disappears if three readings were already logged that day.

Worth noting: **daily averaging is itself processing.** Showing raw values is not a compliance risk to be managed — it is the app doing *less* to the data, and it is both the clinically better and the more compliant choice.

### 9.3 What the research shows

**ABPM reports** use raw scatter, a fitted trend, daytime and nighttime periods separated (typically 6am–10pm / 10pm–6am), and separate day/night/24-hour averages. The structure transfers. The threshold lines and shaded bands do not.

**Consumer apps** mostly do prohibited things. SmartBP colour-codes history averages by classification. Omron surfaces high-BP flags. Omron Connect's home screen is latest reading, 7-day average and a small trend chart — heavily averaged, the failure mode being escaped here.

One counterpoint worth holding: Omron's TruRead takes three readings a minute apart and averages them, because the AHA considers home BP averages more reliable than single readings. Averaging is not wrong in itself. Averaging *across a whole day* is, because it flattens diurnal variation and buries outliers. The morning/evening split resolves this without discarding averages.

The AM/PM structure is conventional — SmartBP offers 7, 14 and 30 day summaries grouped by daily AM/PM averages.

### 9.4 The compliant design

**Fixed y-axis, 40–200 mmHg.** This does most of the work the reference lines were meant to do. A 200 systolic sits visibly at the top; a normal week sits mid-range with headroom. The spike is obvious from position alone, with nothing on screen saying what it means. Auto-scaling is what currently makes every week look the same shape.

**Uniform gridlines every 20 mmHg** — 60, 80, 100, 120, 140, 160, 180. 120 appears as a scale increment, not as an emphasised line. The distinction is real and legible to a reviewer: a single emphasised line at 120 singles out a clinical boundary; a uniform grid does not.

**Raw dots as primary.** One mark per reading. No aggregation in the default view.

**Systolic and diastolic joined per reading** — a vertical connector, the classic ABPM look. Shows pulse pressure implicitly, interprets nothing.

**Morning and evening distinguished by marker shape**, not colour alone. Afternoon omitted per the meeting.

**Greyed mean line behind**, visually recessive so it reads as context rather than answer.

**Raw / averaged toggle**, raw as default.

**Tap a dot** to reveal exact values and timestamp.

### 9.5 Explicitly not

No emphasised reference line at any value. No shaded bands or zones. No colour carrying meaning. No annotation, callout or marker that distinguishes one reading from another on the basis of its value.

### 9.6 The reading list may matter more than the chart

From Omron's App Store reviews, an older user: *"Changing the blood pressure history from list to graph view was a big mistake... it would be better if I could toggle list view to be the default view. Especially once you have become an old curmudgeon."*

Deliverable 6 contracts both — "a trend chart over time plus a reading list." For a 60+ audience the list is plausibly the primary artefact. See UX-13.

---

## 10. Signup screen changes

Current: email plus 18+ attestation only. No password, no sign-in. Comment notes real auth is wired at integration.

**UX-14 — password field.** `Field` below email, type `password`, label from `JOURNEY.signup.passwordLabel` (already defined). `canContinue` requires non-empty; minimum length set at auth integration.

**UX-15 — sign-in mode.** Secondary button below the primary CTA: "Already have an account? Sign in". In sign-in mode the title changes, the 18+ checkbox is hidden (already attested), the CTA becomes "Sign in", and "Create account instead" reverses it. `StepDots` stays visible in both.

**UX-16 — copy.** In `src/copy/journey.ts` under `JOURNEY.signup`:

```
signInTitle:  "Sign in to your record.",
signInCta:    "Sign in",
signInToggle: "Already have an account? Sign in",
createToggle: "Create account instead",
```

In `src/copy/validation.ts`:

```
VALIDATION_AUTH_FAILED: "Please check your email and password."
```

Mechanical only. Never indicate which field failed — that is both a security convention and consistent with the non-diagnostic copy rule.

Layout: ~32 words currently, ~50 after. Still non-scrolling. Keep the pinned footer.

**Open:** whether sign-in skips consent when consent already exists. Backend and state question, resolve at integration.

---

# PART C — GOVERNANCE

## 11. Content ownership

SOW A.5.3 places clinical content and sign-off with Corveo. A.5.2 item 5 makes the six weeks of signed-off content a pre-commencement dependency.

- **How much appears per screen, and in what order** — presentation. Ours.
- **What the words say** — clinical content. Andrew's.

If a restructure requires cutting or rewriting sentences rather than moving them, stop and mark it `REQUIRES CLIENT CONTENT SIGN-OFF`. Do not proceed on that item.

The consent screen is stricter again — see UX-09.

## 12. Needs Andrew

| # | Item | Blocks |
|---|---|---|
| A-01 | Reference lines and bands — clinical rationale versus A.3.3 | UX-B1, UX-B2 |
| A-02 | Any education content rewording, if UX-07 requires it | UX-B3 |
| A-03 | Whether Sign in with Apple stays in V1, given the deletion implication | Auth integration |

## 13. Needs Userkind

| # | Item | Blocks |
|---|---|---|
| U-01 | Does a component library file exist? The token file has no components (§8.5) | UX-06 and every component task |
| U-02 | If form components exist, do they carry `text/error` red, and is a neutral variant available? | Field states |
| U-03 | Confirmation that the app using the desktop scale on mobile is acceptable (§8.6) | Nothing — record only |

## 14. Corrections to v0.1

| # | v0.1 claim | Correction |
|---|---|---|
| C-01 | Contrast against `#f2ede9` at 15.5 / 9.1 / 5.8 / 3.1 | Recomputed: 18.07 / 10.87 / 7.27 / 3.40. All understated. |
| C-02 | Secondary on page "fails AAA" | 7.27:1 — **passes AAA**. Makes it a safe UX-05 target. |
| C-03 | Secondary on card "borderline AAA" | 8.45:1 — comfortable. |
| C-04 | "WCAG AAA recommends body text at 18px or larger" | **WCAG specifies no minimum font size.** 18pt (24px), or 14pt bold (18.66px), is WCAG's *large text* definition for contrast thresholds — not a body-size recommendation. 18px here is a project standard for this audience. |
| C-05 | Touch targets framed against 48px as if a standard | 48px is our project standard. WCAG 2.2 AA is 24×24, AAA is 44×44, Apple HIG is 44×44pt. |
| C-06 | Dynamic Type "inherent to the Capacitor architecture" | Bridgeable via `preferredContentSizeCategory`. Now UX-02. |
| C-07 | Line lengths 45–55 chars at 16px | Closer to 40–48. Conclusion unchanged — no violations. |
| C-08 | Reference lines listed as an agreed direction | Blocked. See §9.1. |
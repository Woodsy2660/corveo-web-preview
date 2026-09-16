# Motion Design for BP Reset V1: Market Research & Implementation Plan (2026)

## TL;DR
- **Build the motion system almost entirely from native CSS transitions and the Web Animations API — no motion library, no Lottie, no third-party SDK — because the constraints (zero sub-processors, WKWebView performance, restrained aesthetic, older audience) all point the same way.** The one exception worth considering is AutoAnimate (2.2 kB minzipped, MIT, zero dependencies, no network calls) for reading-list reordering.
- **Motion must never carry a clinical judgement.** The hardest constraint is regulatory: colour-coding or celebrating a reading is exactly what pushes an app from "low-risk wellness/log" into "medical device" territory — the FDA Warning Letter to WHOOP, Inc. (CMS #709755, July 14, 2025) is the cautionary tale. Every animation in BP Reset must be value-neutral: the same subtle fade whether the number is 110/70 or 180/110.
- **Design for older adults means slower, simpler, fewer.** Use durations at the upper end of general guidance (~250–400 ms), favour opacity/position fades over scale/zoom/parallax, honour `prefers-reduced-motion` completely, and never rely on motion as the only signal. Reserve animation for the few places it aids orientation or confirms an action.

## Key Findings

### The regulatory constraint dominates every motion decision
BP Reset's "no interpretation" position is not merely cautious — it tracks the exact line regulators draw. In the FDA Warning Letter to WHOOP, Inc. (CMS #709755, dated July 14, 2025, from the Center for Devices and Radiological Health), the FDA stated that WHOOP's "Blood Pressure Insights" feature was a medical device because providing blood-pressure estimates is "inherently associated with the diagnosis of hypo- and hypertension, and is therefore intended for use in the diagnosis of a disease or other condition." (Notably, on June 17, 2026 the FDA issued a closeout letter saying it "does not intend to enforce the device statutory and regulatory requirements for your BPI product as modified" after WHOOP changed the product and labeling — but the modification, not disclaimers, resolved it.) FDA's 2026 General Wellness guidance (per legal analyses from AGG and Faegre Drinker) permits wellness notifications only if they do not "name a disease, characterize outputs as diagnostic, include clinical thresholds, or provide ongoing disease monitoring alerts." Colour-coding a reading green/amber/red against AHA/ESC hypertension categories *is* applying a clinical threshold. Australia's TGA takes the same view: it explicitly classifies "a mobile phone app that connects via Bluetooth to a blood pressure cuff… used to track the blood pressure" as a medical device because it monitors symptoms related to a disease.

Critically for the design team, **the incumbents BP Reset is compared against all cross the line it must not cross:**
- **Hello Heart** colour-codes readings and shows evaluative feedback: "It will show you if your blood pressure is in the normal, high, or low range." A physician review on iMedicalApps called its "Am I OK" feedback "an overreach."
- **Withings** BPM Vision uses colour-coded feedback — "Green indicates a safe zone, while red signals a need for action and consultation" — based on AHA/ESC 2017 guidelines. Withings labels its BPM hardware "a medical device."
- **Omron Connect** shows "colour-coded results" on its dashboard and offers a hardware "Hypertension Indicator."
- **Apple Health** is the model to emulate: it presents an individual reading neutrally (a number and a trend graph). Any AHA/ESC classification is confined to the opt-in "Blood Pressure Log" *averages*, framed for clinician discussion, and Apple states logged values "do not influence the Hypertension Notification feature in any way."

No app surveyed used celebratory animation (confetti/rewards) tied to a specific reading value; the only gamification found (Omron "rewards for consistent tracking") rewards the logging habit, not the number.

### Motion trends in 2026 health apps favour restraint and progressive disclosure
The 2025–26 redesigns of the leading apps moved *away* from decoration toward calm data hierarchy. Oura's late-2025 app overhaul (by agency Instrument) collapsed five tabs into three and is "grounded in progressive disclosure, a unified semantic color language, and a data visualization framework that scales." WHOOP's visualization system (built by information designer Bureau Oberhaeuser) uses a strict three-tier progressive-disclosure model — glanceable score, trend view, deep-dive graph. The broader "2026 trend" commentary pushing 3D, immersive visuals and vibrant micro-interactions is aimed at consumer/e-commerce audiences and is largely inapplicable here; the credible signal for a clinician-led product is "calm, predictable, readable."

### Older-adult evidence: slower, simpler, stable, optional
A 2025 mixed-methods study in *Frontiers in Psychology* ("Age-friendly design framework for information animations," Yang & Gan, doi:10.3389/fpsyg.2025.1557924) found that for older adults **information complexity has a significant negative effect on perceived ease of use**, and recommends "short-duration, simplified information, visual clarity, visual stability, controlled pacing, soft and neutral colors." A companion source notes older adults (60+) have slower cognitive processing and that the optimal number of dynamic transitions may be lower than the 2–3 per second appropriate for younger users. Apple added the Reduce Motion setting *specifically because* iOS 7's animations "induced cybersickness in a significant number of people." Vestibular sensitivity is prevalent in the target age band: as many as 35% of adults aged 40+ in the US — approximately 69 million Americans — have experienced some form of vestibular dysfunction (Vestibular Disorders Association, citing Agrawal et al., 2009, NHANES). The practical implications: keep motion durations toward the upper end of the general 200–500 ms range, avoid zoom/scale/parallax (Apple HIG: reduce "large animations, especially those that simulate the third dimension"), and never make motion the sole channel for information.

### General duration/easing guidance
Nielsen Norman Group: "a range of 100–400 ms is appropriate, with 400 ms being a very slow animation, to be used only for big movements"; at 500 ms animations "feel like a real drag." Material Design: mobile durations 200–300 ms for standard transitions, larger/hero transitions up to 400 ms; entering elements slightly longer than exiting. The widely-used ease-out curve `cubic-bezier(0.16, 1, 0.3, 1)` (adopted as a "motion contract" by several 2026 practitioners) starts fast and settles gently — appropriate here. Best practice: never `scale(0)` — start from `scale(0.97) + opacity:0`; animate only `transform` and `opacity` (GPU-composited); `padding/margin/height/width/top/left` trigger layout and cause jank.

### Loading states: skeletons for structured content, brief spinners for short/unknown waits, optimistic UI for saves
The 2025–26 practitioner consensus favours skeleton screens for structured content because they let the brain pre-process layout and reduce uncertainty. **The strength of the evidence, however, is weaker than commonly claimed.** The widely-repeated "skeletons feel 20–30% faster" figure traces to secondary practitioner blogs, not primary research: the Viget (2017) study actually found skeleton screens "performed the worst in terms of perceived duration of time," and the peer-reviewed ResearchGate study (Mejtoft et al., ECCE'18) found skeletons "scored higher on average on both perceived speed and ease of navigation" but concluded the results "cannot show any significant differences." The safe takeaway is that skeletons are at least as good as spinners for structured lists and reduce layout shift, so use them there — but don't over-invest in shimmer detail. The modern orchestration: 0–300 ms show nothing; 300 ms–1 s a subtle inline spinner where layout is unknown; 1–10 s skeletons that mirror incoming content; and swap any spinner running >4 s for a progress/status message. Optimistic UI (React 19 `useOptimistic`) suits field updates like manual reading entry and toggles; a busy indicator is better when the outcome/ID is unknown (e.g., account creation).

### Technical options in a Capacitor/WKWebView, ranked against the constraints
- **Native CSS transitions/animations** — zero bytes, GPU-composited, no network, honours `prefers-reduced-motion` natively. WKWebView uses Core Animation/hardware acceleration and runs at up to 60 fps. Best default.
- **Web Animations API (WAAPI)** — native, no dependency, good for JS-orchestrated sequences (staggered list reveals). Free.
- **View Transitions API** — same-document (SPA) transitions are Baseline Newly Available as of October 2025; Safari has supported them since Safari 18 (cross-document since 18.2). Usable as a *progressive enhancement* for route transitions in the onboarding wizard, with a CSS fallback. No dependency, no network.
- **AutoAnimate** — 2.2 kB minzipped (BundlePhobia), MIT, zero dependencies, no network calls; described by FormKit creator Justin Schroeder as "a lightweight, zero-config, drop-in animation library" (current version 0.10.0, July 2026). One-line smooth list add/remove/reorder — the only library genuinely worth its weight here (reading list).
- **Motion One / Motion (Framer Motion)** — Motion One's `animate()` is ~3.8 kB; full Motion/Framer Motion is ~30–34 kB (reducible to ~6 kB via LazyMotion). MIT, runs `requestAnimationFrame` on the main thread. No telemetry in the library itself. Only justified if declarative gesture/layout animation becomes essential — probably overkill here.
- **GSAP / React Spring** — capable but heavier and unnecessary for this restrained brief.
- **Lottie** — AVOID. It is a JSON+player animation format optimised for rich illustrative motion (off-brand for near-monochrome clinical restraint), the `lottie-web` player adds weight, and the common LottieFiles CDN workflow phones home to a third party — a direct conflict with the zero-sub-processor rule. If ever used, files must be fully self-hosted; but it isn't needed.

### WKWebView specifics
WKWebView is capped at 60 fps (no 120 Hz ProMotion in a webview, per an Apple Developer Forums engineer response and an open WebKit bug). Practitioners report transition lag when animating non-composited properties or heavy scenes; the fix is to animate only `transform`/`opacity`, use `will-change: transform` sparingly (it costs memory per promoted layer), and avoid animating many elements simultaneously (INP/jank risk). For route transitions specifically, `@capgo/capacitor-transitions` provides Ionic-style iOS page transitions and swipe-back, runs in the web layer, and adds no native plugin code — a no-network option if hand-rolled transitions prove fiddly.

### Haptics on iOS via Capacitor
The official `@capacitor/haptics` plugin supports `impact` (Light/Medium/Heavy/Soft/Rigid), `notification`, `vibrate`, and `selection` events via the Taptic Engine, and resolves silently on unsupported devices. On iOS, custom vibration duration is not respected (fixed system durations). For older users, a single light impact to confirm a discrete action (save, capture) is appropriate and useful as a *non-visual* confirmation channel; avoid continuous or notification-style buzzes that could read as an alarm.

### Anti-patterns to avoid
Health-app UX failures documented in 2025–26 writing: lengthy/confusing onboarding causing older-adult abandonment; cognitive overload from too much on one screen; over-reliance on gestures; unreadable text. Withings' community forums show a large, sustained user backlash to a 2022 chart redesign ("New weight chart is useless," "8 years of data just GONE") — a warning that changing how data is displayed/animated angers exactly the loyal, older users this product serves. Animation-specific anti-patterns: animating every interaction at 400 ms with no skip generates "the app feels slow" one-star reviews; celebration animations that users tap past; parallax/scroll-jacking (vestibular triggers); and any motion that draws the eye to a particular data value.

## Details — Screen-by-Screen Plan

### 1. Recommended motion principles (the team's rules)
1. **Motion is neutral. It confirms actions and orients the user — it never evaluates a reading.** The animation for capturing 118/78 and 175/105 is byte-for-byte identical.
2. **Slower and simpler than a consumer app.** Default transition 250–300 ms; larger/screen-level 300–400 ms; micro-feedback 120–180 ms. Easing `cubic-bezier(0.16, 1, 0.3, 1)` (ease-out) as the single token, extending the one easing token already defined.
3. **Animate only `transform` and `opacity`.** Never height/width/top/left/margin. This is both a performance and a WKWebView requirement.
4. **Fades and short slides only. No zoom, scale-from-zero, parallax, bounce, or 3D.** These are vestibular triggers and read as "playful."
5. **Motion is always optional and never the sole signal.** Full `prefers-reduced-motion` support; every state also has a text/static representation for VoiceOver.
6. **Prefer no animation to a decorative one.** If it doesn't confirm, orient, or reduce perceived wait, cut it.

### 2. Specific patterns by screen (with priority)

**Onboarding "Journey" (welcome → signup → consent → connect → first capture → result → cadence)** — *HIGH VALUE*
- Step-to-step: horizontal slide (translateX ~16–24 px) + crossfade, 280–320 ms ease-out, direction-aware (forward = new content in from right). Implement with the View Transitions API (SPA mode, Safari 18+) with a plain CSS opacity fallback; or a hand-rolled CSS transition on a keyed container. This aids orientation in a wizard — the one place directional motion genuinely helps older users understand "where am I."
- Progress indicator: animate width/position of a step dot or bar, but express progress as **steps completed in the Journey**, never as a health outcome. Under reduced motion, snap the indicator without a tween.
- Reduced-motion fallback: pure crossfade (opacity only), same 280 ms.

**First capture → Result** — *HIGH VALUE, HIGHEST RISK*
- The reading appears with a simple, uniform fade-in (opacity 0→1, ~250 ms). **No count-up animation, no colour, no pulse, no checkmark-with-flourish, no haptic that varies by value.** A single light haptic confirming "captured" is acceptable because it's tied to the *action*, not the *value*.
- Do NOT animate the number "arriving" in a way that emphasises it. Present it the way Apple Health presents a raw reading: neutrally.

**My Heart Record (trend chart + reading list)** — *MIXED*
- Chart: on first load, either render statically or use a single restrained left-to-right line "draw" / fade (≤400 ms) that is purely presentational. **Do not animate the y-axis, do not animate individual points growing, and do not re-animate on every revisit.** Animating chart data risks two problems: (a) implying trend/emphasis (a clinical read), and (b) misrepresentation — the data-viz literature warns animated/zoomed axes distort perceived magnitude. Under reduced motion: no draw, render complete. This is *nice-to-have*, not high value — a static chart is entirely acceptable and arguably safer.
- Reading list: use a skeleton screen mirroring the row layout while data loads (1–10 s window). New rows fade in over ~200 ms. AutoAnimate (2.2 kB, MIT, no network) is justified here for smooth insert/reorder. Under reduced motion, rows appear without animation.

**Education / 6-week program library** — *MEDIUM*
- Card list: skeleton on load; staggered fade-in-up of cards (opacity + translateY 12–16 px, 300 ms, 40–50 ms stagger, capped at the first ~5 items to protect INP). Reduced motion: all cards appear at once, no translate.
- Entering a lesson: same directional slide/crossfade as the Journey for consistency.

**Sync / background data arrival** — *HIGH VALUE, RISK*
- When HealthKit delivers new readings, communicate arrival *quietly and without evaluation*: a subtle inline text update ("Updated just now") and a gentle fade-in of the new row. No toast that celebrates, no badge that alarms, no colour. VoiceOver: announce via a polite `aria-live` region ("New reading added").

**Settings / data export & deletion** — *MEDIUM*
- Export/delete are uncertain-outcome, consequential actions → use a **busy indicator (spinner)**, not optimistic UI, and an explicit confirmation state. Deletion especially must feel deliberate; no fast optimistic disappearance. A brief inline success confirmation (fade-in text + light haptic) on completion.

**Micro-interactions (global)** — *MEDIUM*
- Button press: `transform: scale(0.97)` on `:active`, 140–160 ms ease-out. Large 44×44 pt+ targets.
- Form focus: border/background transition 150 ms; validation shown with icon + text, never colour alone.
- Toggles/checkboxes: 150–200 ms state transition.
- Successful save: fade-in confirmation text + optional single light haptic.
- Pull-to-refresh: acceptable but keep the indicator simple and non-spinny-forever; prefer a skeleton on the refreshed content.

### 3. Recommended technical approach
**Primary: native CSS transitions + Web Animations API, no motion library.** Justification: zero bundle cost, zero network/telemetry (satisfies the zero-sub-processor contract absolutely), GPU-composited so best-in-class in WKWebView, `prefers-reduced-motion` support is native, and the restrained aesthetic needs nothing more. Define a small motion-token file (durations 150/280/400 ms; easing `cubic-bezier(0.16,1,0.3,1)`) extending the existing easing token.
- **Add AutoAnimate (2.2 kB, MIT, zero deps)** only for the reading/education lists — it makes no network calls and is genuinely time-saving.
- **Use the View Transitions API** (Safari 18+, Baseline Oct 2025) as a progressive enhancement for onboarding route transitions, always behind a CSS fallback.
- **Consider `@capgo/capacitor-transitions`** only if hand-rolled iOS page transitions and swipe-back prove hard; it runs in the web layer and adds no native/network code. Verify its licence and that it records no telemetry before adopting.
- **Reject:** Framer Motion/Motion (30 kB, unnecessary), GSAP, React Spring, and especially **Lottie** (off-brand, heavier, and the standard CDN workflow transmits to a third party).

### 4. Explicit "do NOT" list
- **No traffic-light colours (red/amber/green) anywhere** — the core regulatory line; it's what makes Hello Heart/Withings/Omron medical-device-adjacent.
- **No animation that emphasises, celebrates, or alarms about a reading's value** — no count-up, pulse, confetti, shake, or value-dependent haptic.
- **No progress animation that implies a health outcome** — Journey progress = education steps only.
- **No zoom/scale-from-zero/parallax/3D/bounce** — vestibular triggers; off-brand.
- **No animating chart axes or points in a way that implies trend/judgement.**
- **No motion as the only signal** — always pair with text/static state for VoiceOver and reduced-motion.
- **No Lottie/third-party animation CDN, no motion SDK that phones home.**
- **No animating layout properties** (height/width/margin/top/left) — jank in WKWebView.
- **No long (>400 ms) or unskippable animations on repeated actions** — the documented cause of "app feels slow" reviews.

### 5. Accessibility requirements
- **`prefers-reduced-motion: reduce`:** disable all slides, staggers, chart draws, and scale effects; retain only instant opacity crossfades ≤200 ms or no motion. Wrap all non-essential motion in the media query (WCAG 2.2 technique C39).
- **WCAG 2.2:** SC 2.3.3 (Animation from Interactions, AAA) — interaction-triggered motion must be disable-able; SC 2.2.2 (Pause/Stop/Hide) — any auto-playing/looping motion (e.g., a skeleton shimmer) must be pausable or, better, avoided/subtle. Prefer a static or single-cycle skeleton over an infinite shimmer.
- **VoiceOver:** all state changes announced (`aria-live="polite"` for new-data/sync/save; assertive only for errors). Meaningful `accessibilityLabel` on every control; never convey status by colour or motion alone.
- **Duration limits:** cap standard transitions at 400 ms; micro-feedback ≤180 ms. Honour Apple HIG "play tightened animations when Reduce Motion is on."
- **Also respect** Dynamic Type (layouts must not break when text scales), 44×44 pt targets, 4.5:1 contrast — all reinforce the older-adult brief.

### 6. Open questions / decisions needed
1. **Chart entry animation: in or out?** Recommendation is a static or single restrained draw. Needs a decision with the clinical/regulatory reviewer that even a presentational draw doesn't imply emphasis.
2. **Is a light confirmation haptic on capture acceptable** under the "no feedback tied to a reading" rule? Recommendation: yes, because it confirms the *action* not the *value* and is identical regardless of number — but confirm with legal.
3. **View Transitions API vs hand-rolled:** decide based on the app's minimum supported iOS version (VTA needs Safari/WKWebView 18+). If a meaningful share of the older-adult base is on older iOS, default to the CSS fallback path.
4. **Skeleton vs. brief spinner for HealthKit sync** — depends on measured real sync latency; if consistently <1 s, show nothing/inline spinner rather than a skeleton flash.
5. **Confirm `@capgo/capacitor-transitions` (if used) records no telemetry** to satisfy the contractual zero-sub-processor clause.

## Recommendations
**Stage 1 (foundation, do first):** Ship the motion-token file (durations 150/280/400 ms; ease-out `cubic-bezier(0.16,1,0.3,1)`), a global `prefers-reduced-motion` reset, and CSS-only button/form/toggle micro-interactions. Adopt skeleton screens for the reading list and education library. This delivers the highest perceived-quality gain for near-zero risk and zero dependencies.

**Stage 2 (orientation motion):** Implement the onboarding Journey step transitions (directional slide+fade with reduced-motion crossfade fallback), and the neutral fade-in for the result screen. Add AutoAnimate to the reading list. Wire VoiceOver `aria-live` for sync/save.

**Stage 3 (nice-to-have, gated on review):** Decide the chart-entry question; add a single restrained line-draw only if the clinical reviewer signs off. Add a light confirmation haptic on capture if legal approves.

**Benchmarks that would change the plan:** if animation profiling shows dropped frames/jank in WKWebView, strip to opacity-only; if user testing with 60+ participants shows any confusion or discomfort, remove directional slides in favour of crossfades globally; if the regulatory reviewer flags the chart draw as implying emphasis, ship a static chart.

## Caveats
- Several trend/"2026 UI" sources are marketing-oriented practitioner blogs, not peer-reviewed; they're used only for directional consensus (durations, skeleton-vs-spinner). The specific "20–30% faster perceived" skeleton claim is **not well supported** by the primary studies (Viget 2017 found skeletons perceived *worst*; Mejtoft et al. ECCE'18 found no significant difference) — treat skeletons as "at least as good as spinners and better for layout stability," not as a proven speed illusion.
- WKWebView's 60 fps cap and the "animate only transform/opacity" rule are well-established; exact behaviour should still be profiled on the real minimum-supported device.
- The regulatory synthesis is design guidance, not legal advice — the FDA/TGA specifics should be confirmed by Corveo's regulatory counsel, especially the haptic and chart-draw edge cases.
- Older-adult animation evidence is thinner than general-population evidence (the Frontiers study itself notes <2% of educational animation is age-friendly), so the safe default is minimal motion.
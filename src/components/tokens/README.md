# Design tokens

Two files live here, and they are not duplicates.

| File | What it is | Status |
|---|---|---|
| `tokens.css` | The app's working token layer. Names and values were reverse-engineered from the shipped corveo.vercel.app CSS (14 Aug) and refined against the Figma Properties panel (19 Aug). | **In use.** Imported by `src/app.css`. |
| `figma-tokens.css` | The Userkind system exported straight from the Figma Variables panel (28 Aug). All 132 variables, three collections, all three responsive modes. | **Reference.** Not imported yet — adopt deliberately. |

`figma-tokens.css` is the authoritative source. `tokens.css` is what the app
actually renders from today. The gap between them is documented below.

Full written reference: `/docs/corveo-design-system.md`.

## Why `figma-tokens.css` isn't imported yet

Every property in it is prefixed `--fig-`, so importing it collides with
nothing and cannot restyle the app by accident. It is unimported only because
**adopting it is a design decision, not a mechanical one** — see the scale
question below.

To make it available, add one line to `src/app.css` under the existing import:

```css
@import "./components/tokens/figma-tokens.css";
```

That alone changes nothing visually. Components only pick up the new values
when they are pointed at `--fig-*` names, or when `tokens.css` re-points its
own variables at them, e.g.:

```css
--color-text-primary: var(--fig-text-primary);
```

Migrating one group at a time (colour first, scale last) keeps each step
reviewable.

## The decision that matters: which responsive mode

Figma's `Responsive` collection has three modes — Desktop, Tablet, Mobile — and
all 43 scale values differ per mode.

**`tokens.css` currently carries the Desktop values.** That follows from how it
was built: read off the shipped website, which is desktop. But Corveo BP Reset
is an iPhone app rendering in a 393px frame, so the mode that matches the
product is **Mobile**.

Some of what that means in practice:

| Token | tokens.css today (Desktop) | Figma Mobile |
|---|---|---|
| `spacing-md` | 24px | 16px |
| `spacing-lg` | 32px | 24px |
| `spacing-xl` | 48px | 32px |
| `spacing-2xl` | 80px | 56px |
| `radius-sm` | 8px | 6px |
| `radius-md` | 12px | 10px |
| `text-body-base` | 16px | 15px |
| `text-heading-4xl` | 40px | 28px |
| `text-heading-3xl` | 30px | 22px |

This is not a bug to be quietly fixed. Switching to the Mobile scale would
retighten spacing and typography across every screen already built, which is a
visual redesign and needs to be looked at, not merged. `figma-tokens.css` is
authored mobile-first precisely so that decision is one import away when
someone wants to make it.

Worth noting either way: the current app is internally consistent and looks
deliberate. It is just built to the web scale rather than the phone scale.

## What was corrected in `tokens.css`

One value, because it was wrong rather than merely different:

- `--color-text-link` was `#000`. The Figma alias `text/link` resolves to
  `Blue/500` = `#3E4FB5`. The black came from reading the homepage, which is
  the outlier — article bodies use blue. Nothing consumed this token yet, so
  the change is inert until something does.

Nothing else was touched.

## Tokens the authoritative export has that `tokens.css` does not

Add these as they are needed rather than up front:

- Text: `text-tertiary-inverse`, `text-disabled-inverse`, `text-error`,
  `text-success`, `text-info`
- Surface: `surface-action-hover`, `surface-action-disabled`
- Border: `border-default-active`, `border-disabled`, `border-error`
- Spacing: `spacing-3xl`
- The full Brand primitive ramps (Neutral 13 steps, Blue/Beige/Warning/
  Information/Error/Success 5 steps each, Brown 3)
- Paragraph-spacing tokens
- Absolute heading line-heights (`h1`–`h5`)

## Corveo-side additions that are NOT in Figma

These are ours, deliberate, and should survive any migration:

- `--color-chart-teal: #00839b` — a chroma-raised step of `surface-color-3`, so
  a translucent area fill still reads as colour on a white card. Validated
  against `color-1` for colour-vision separation.
- `--radius-lg: 16px`, `--radius-xl: 28px` — Figma's radius set is only
  `none / xs / sm / md / Round`. `xl` is concentric with the 44px device screen
  minus the 16px inset.
- `--ease-brand`, `--ease-overshoot`, `--duration-*` — motion curves measured
  from the shipped site. Figma holds no motion variables.
- `--safe-top`, `--safe-bottom` — iOS safe areas.
- `--font-mono` — no mono family exists in the Figma system.

## Things in the source we mirrored rather than fixed

The export is verbatim, including two oddities. They are Userkind's to resolve;
we work around them rather than diverging from the source:

- `beige-500` is `#1C7A8C`, a teal, in the middle of a brown ramp. It drives
  `surface-color-3`.
- `text-tertiary-inverse` resolves to the same value as `text-tertiary`, so it
  does not invert. If tertiary text is ever needed on a dark surface, pick a
  value locally and leave a comment — do not "fix" the token.

## Rule

Components consume semantic tokens only. No raw hex, no raw px in component
files. That rule is unchanged by any of the above.

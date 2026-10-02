# Prototype Limitations

**For**: External designer (Userkind)
**Date**: 2 October 2026

---

## What This Prototype Is

This is a **React web prototype** of the Corveo BP Reset app. The shipping product is a **native SwiftUI iOS app**.

The prototype exists as a design surface for reviewing layout, typography, and content arrangement. It is synced to the current SwiftUI build but cannot represent all native behaviours.

---

## Native Behaviours It Cannot Show

The following iOS-native interactions are not present in the web prototype:

- **iOS navigation chrome** — large titles that collapse on scroll, automatic back swipe gestures, native sheet presentation with drag-to-dismiss
- **Dynamic Type** — iOS system-wide text size settings that scale typography
- **Safe area insets** — notch avoidance and home indicator spacing (approximated with CSS env() but not identical)
- **HealthKit authorisation sheets** — native Apple Health permission dialogs
- **Haptics** — tactile feedback on interactions
- **Native date/time pickers** — iOS wheel-style selectors

---

## Content Status

All education content (six-week programme and Pulse articles) is marked **draft** with `publishable: false`.

A preview banner appears at the top of the Program tab while any content is unpublishable. Review hold markers appear on chapters with editorial holds.

This is the author's draft material, clinically authored but not yet approved for release. It is not guidance.

---

## What Remains Drifted

The following differences remain between the prototype and the Swift build:

- **Settings structure** — React has a separate "Readings Arrive" page; Swift handles this inline in the Connect flow
- **Behind the Scenes** — a React-only presentation surface not in the native app
- **Token bumps** — text-tertiary, text-label, and text-body-sm are intentionally larger in React for web readability (14px/16px vs 12px/14px). Both are valid for their platform.

---

## Access

The prototype is publicly reachable. A `<meta name="robots" content="noindex, nofollow">` tag discourages search indexing, but this is not access control.

If access restriction is needed, contact the development team about Vercel Deployment Protection or an in-app password gate.

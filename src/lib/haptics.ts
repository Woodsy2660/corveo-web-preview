/**
 * Haptic feedback stub (docs/UI animation research.md §Haptics).
 *
 * A single light impact confirming a discrete action (save, capture).
 * Value-neutral: the haptic is identical for 110/70 and 180/110 — it
 * confirms the *action*, not the *value*.
 *
 * On web this is a no-op. When the Capacitor shell lands (L-1), swap
 * the body of `confirmHaptic` to:
 *
 *   import { Haptics, ImpactStyle } from "@capacitor/haptics";
 *   Haptics.impact({ style: ImpactStyle.Light });
 *
 * The plugin resolves silently on unsupported devices, so no feature
 * detection is needed.
 */
export function confirmHaptic(): void {
  // Capacitor not installed yet — silent no-op on web.
  // The native shell will wire @capacitor/haptics here.
}

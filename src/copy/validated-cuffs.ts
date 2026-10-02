/**
 * Validated upper-arm cuff list (Deliverable 8).
 * Source: STRIDE BP (stridebp.org).
 *
 * SYNCED FROM: ios/BPReset/Copy/Copy.swift — ValidatedCuffsCopy enum
 */

export const VALIDATED_CUFFS = {
  eyebrow: "Choosing a monitor",
  title: "Validated upper-arm cuffs.",
  intro:
    "Corveo recommends clinically validated upper-arm monitors. These models appear on the STRIDE BP validated device register. Corveo doesn't sell monitors and has no affiliation with any manufacturer.",
  devices: [
    {
      brand: "Omron",
      model: "HEM-7361T (Gold / Platinum)",
      connectivity: "Bluetooth via OMRON connect → Apple Health",
    },
    {
      brand: "Withings",
      model: "BPM Connect",
      connectivity: "Wi-Fi / Bluetooth via Withings app → Apple Health",
    },
    {
      brand: "Omron",
      model: "HEM-7156 (Standard)",
      connectivity: "Manual entry",
    },
  ],
  sourceNote: "Validation status per STRIDE BP (stridebp.org), accessed August 2026.",
} as const;

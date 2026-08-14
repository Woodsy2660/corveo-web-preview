import { describe, expect, it } from "vitest";
import { isValidManualEntry, validateManualEntry } from "./bounds";

// Bounds from observation_definition seed values, docs/02 §1.3:
// systolic 60–260, diastolic 30–160, systolic > diastolic.
describe("validateManualEntry", () => {
  it("accepts a plausible reading", () => {
    expect(isValidManualEntry({ systolic: "128", diastolic: "82" })).toBe(true);
  });

  it("accepts boundary values", () => {
    expect(isValidManualEntry({ systolic: "260", diastolic: "30" })).toBe(true);
    expect(isValidManualEntry({ systolic: "61", diastolic: "60" })).toBe(true);
    expect(isValidManualEntry({ systolic: "60", diastolic: "60" })).toBe(false);
  });

  it("rejects out-of-bounds typos like 900/600", () => {
    const errors = validateManualEntry({ systolic: "900", diastolic: "600" });
    expect(errors.systolic).toBe("OUT_OF_BOUNDS");
    expect(errors.diastolic).toBe("OUT_OF_BOUNDS");
  });

  it("rejects systolic below 60 and diastolic above 160", () => {
    expect(validateManualEntry({ systolic: "59", diastolic: "80" }).systolic).toBe("OUT_OF_BOUNDS");
    expect(validateManualEntry({ systolic: "180", diastolic: "161" }).diastolic).toBe("OUT_OF_BOUNDS");
  });

  it("requires systolic to exceed diastolic", () => {
    expect(validateManualEntry({ systolic: "90", diastolic: "90" }).cross).toBe("SYSTOLIC_NOT_GREATER");
    expect(validateManualEntry({ systolic: "85", diastolic: "95" }).cross).toBe("SYSTOLIC_NOT_GREATER");
  });

  it("requires both fields", () => {
    expect(validateManualEntry({ systolic: "", diastolic: "80" }).systolic).toBe("REQUIRED");
    expect(validateManualEntry({ systolic: "120", diastolic: "abc" }).diastolic).toBe("REQUIRED");
  });
});

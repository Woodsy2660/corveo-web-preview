import { createHash } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  CON04_RELEASE_BLOCKED,
  IN_FOCUS_CATALOGUE,
  PULSE_CATALOGUE,
  PULSE_REFERENCES,
} from "./education-content";

/** SHA-256 over UTF-8 of the body paragraphs, in order, joined by a single space. */
function pulseBodyDigest(paragraphs: readonly string[]): string {
  return createHash("sha256").update(paragraphs.join(" "), "utf8").digest("hex");
}

describe("Pulse articles (CORV-EDU-002 v0.4)", () => {
  it("verifies SHA-256 of each body (paragraphs joined by a single space)", () => {
    const withBodies = PULSE_CATALOGUE.filter((a) => a.body && a.bodySHA256);
    expect(withBodies).toHaveLength(6);
    for (const article of withBodies) {
      expect(pulseBodyDigest(article.body ?? [])).toBe(article.bodySHA256);
    }
  });

  it("does not invent In Focus bodies", () => {
    expect(IN_FOCUS_CATALOGUE).toHaveLength(4);
    for (const article of IN_FOCUS_CATALOGUE) {
      expect(article.body).toBeNull();
      expect(article.doNotGenerateBody).toBe(true);
      expect(article.emptyReaderMessage.length).toBeGreaterThan(0);
    }
  });

  it("keeps the CON-04 release gate closed", () => {
    expect(PULSE_CATALOGUE.every((a) => a.publishable === false)).toBe(true);
    expect(IN_FOCUS_CATALOGUE.every((a) => a.publishable === false)).toBe(true);
    expect(CON04_RELEASE_BLOCKED).toBe(true);
  });

  it("loads sixteen references without wiring them into navigation", () => {
    expect(PULSE_REFERENCES).toHaveLength(16);
    expect(PULSE_REFERENCES.map((r) => r.id)).toContain("S16");
  });

  it("marks three articles for setup-time access", () => {
    const setup = PULSE_CATALOGUE.filter((a) => a.setupAccess).map((a) => a.title);
    expect(setup).toEqual([
      "Cuff size and fit",
      "Morning and evening",
      "How clinicians use home records",
    ]);
  });
});

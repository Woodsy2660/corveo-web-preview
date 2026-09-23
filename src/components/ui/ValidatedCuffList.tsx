import { VALIDATED_CUFFS } from "@/copy/safety";

/**
 * The validated-cuff list as it appears in the journey: hairline rows,
 * brand and model, connectivity underneath, source cited at the foot.
 * Settings uses the same block so the two cannot drift.
 */
export function ValidatedCuffList() {
  const c = VALIDATED_CUFFS;
  return (
    <div>
      <p className="pb-[var(--spacing-xs)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
        {c.intro}
      </p>
      {c.devices.map((d) => (
        <div key={d.model} className="border-b border-hairline py-[var(--spacing-xs)] last:border-b-0">
          <span style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}>
            {d.brand} {d.model}
          </span>
          <span className="block text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
            {d.connectivity}
          </span>
        </div>
      ))}
      <p className="pt-[var(--spacing-xs)] text-ink-tertiary" style={{ fontSize: "var(--text-label)" }}>
        {c.sourceNote}
      </p>
    </div>
  );
}

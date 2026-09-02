import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { APP } from "@/copy/app";
import { VALIDATED_CUFFS } from "@/copy/safety";

/**
 * Validated-cuff recommendation list (Deliverable 8). The cited source is
 * part of what gets accepted — keep the reference visible in the screen.
 */
export function ValidatedCuffs() {
  const navigate = useNavigate();
  const c = VALIDATED_CUFFS;

  return (
    <Screen
      title={c.title}
      footer={
        <Button variant="ghost" onClick={() => navigate(-1)}>
          {APP.common.back}
        </Button>
      }
    >
      <p className="pb-[var(--spacing-md)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
        {c.intro}
      </p>

      <div className="flex flex-col gap-[var(--spacing-xs)]">
        {c.devices.map((d) => (
          <Card key={d.model}>
            <h2 className="pb-[var(--spacing-3xs)]" style={{ fontSize: "var(--text-heading-xl)" }}>
              {d.brand} {d.model}
            </h2>
            <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
              {d.connectivity}
            </p>
          </Card>
        ))}
      </div>

      <p className="pt-[var(--spacing-md)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
        {c.sourceNote}
      </p>
    </Screen>
  );
}

import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { ManualEntryForm } from "@/components/ManualEntryForm";
import { Button } from "@/components/ui/Button";
import { APP } from "@/copy/app";

/** Add-a-reading screen, reachable from the Readings tab. */
export function ManualEntry() {
  const navigate = useNavigate();
  const c = APP.manualEntry;

  return (
    <Screen
      eyebrow={c.eyebrow}
      title={c.title}
      footer={
        <Button variant="ghost" onClick={() => navigate(-1)}>
          Cancel
        </Button>
      }
    >
      <p className="pb-[var(--spacing-md)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
        {c.timeNote}
      </p>
      <ManualEntryForm ctaLabel={c.cta} onSaved={() => navigate("/app/readings")} />
    </Screen>
  );
}

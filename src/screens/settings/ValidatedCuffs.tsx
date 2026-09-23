import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { ValidatedCuffList } from "@/components/ui/ValidatedCuffList";
import { APP } from "@/copy/app";
import { VALIDATED_CUFFS } from "@/copy/safety";

/**
 * Validated-cuff recommendation list (Deliverable 8). Same block as the
 * journey connect step — hairline rows, not cards — so the two match.
 */
export function ValidatedCuffs() {
  const navigate = useNavigate();
  const c = VALIDATED_CUFFS;

  return (
    <Screen
      overline={APP.settings.menu.monitors}
      title={c.title}
      footer={
        <Button variant="ghost" onClick={() => navigate(-1)}>
          {APP.common.back}
        </Button>
      }
    >
      <ValidatedCuffList />
    </Screen>
  );
}

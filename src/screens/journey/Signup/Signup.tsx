import { useState } from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { Field } from "@/components/ui/Field";
import { StepDots } from "@/components/ui/StepDots";
import { JOURNEY } from "@/copy/journey";

/**
 * Account creation. MOCK — real auth (email+password and Sign in with
 * Apple, anonymous-session linking) is wired at integration per docs/02
 * Part 2. The 18+ attestation maps to app_user.adult_attested.
 */
export function Signup() {
  const navigate = useNavigate();
  const c = JOURNEY.signup;
  const [email, setEmail] = useState("");
  const [adult, setAdult] = useState(false);

  const canContinue = email.includes("@") && adult;

  return (
    <Screen
      overline={c.eyebrow}
      title={c.title}
      footer={
        <Button disabled={!canContinue} onClick={() => navigate("/journey/consent")}>
          {c.cta}
        </Button>
      }
    >
      <StepDots total={5} current={1} />
      <p className="pb-[var(--spacing-md)] text-ink-secondary">{c.intro}</p>

      <div className="flex flex-col gap-[var(--spacing-sm)]">
        <Field
          id="email"
          label={c.emailLabel}
          type="email"
          inputMode="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />

        <label className="flex items-start gap-[var(--spacing-xs)]">
          <input
            type="checkbox"
            checked={adult}
            onChange={(e) => setAdult(e.target.checked)}
            className="mt-[4px] size-[18px] accent-heading"
          />
          <span style={{ fontSize: "var(--text-body-sm)" }}>{c.adultAttestation}</span>
        </label>
      </div>

    </Screen>
  );
}

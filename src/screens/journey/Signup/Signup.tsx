import { useState } from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { Field } from "@/components/ui/Field";
import { StepDots } from "@/components/ui/StepDots";
import { JOURNEY } from "@/copy/journey";

/**
 * Account creation and sign-in. MOCK — real auth (email+password and Sign in
 * with Apple, anonymous-session linking) is wired at integration per docs/02
 * Part 2. The 18+ attestation maps to app_user.adult_attested and is shown
 * only in create-account mode (already attested at creation for returning
 * users).
 */
export function Signup() {
  const navigate = useNavigate();
  const c = JOURNEY.signup;
  const [mode, setMode] = useState<"create" | "signin">("create");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [adult, setAdult] = useState(false);

  const creating = mode === "create";

  const canContinue = creating
    ? email.includes("@") && password.length > 0 && adult
    : email.includes("@") && password.length > 0;

  return (
    <Screen
      overline={c.eyebrow}
      title={creating ? c.title : c.signInTitle}
      className="step-enter"
      footer={
        <div className="flex flex-col gap-[var(--spacing-xs)]">
          <Button disabled={!canContinue} onClick={() => navigate("/journey/consent")}>
            {creating ? c.cta : c.signInCta}
          </Button>
          <Button variant="ghost" onClick={() => setMode(creating ? "signin" : "create")}>
            {creating ? c.signInToggle : c.createToggle}
          </Button>
        </div>
      }
    >
      <StepDots total={5} current={1} />
      <p className="pb-[var(--spacing-md)] text-ink-secondary">
        {creating ? c.intro : c.signInIntro}
      </p>

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

        <Field
          id="password"
          label={c.passwordLabel}
          type="password"
          autoComplete={creating ? "new-password" : "current-password"}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />

        {creating ? (
          <label className="flex items-start gap-[var(--spacing-xs)] min-h-[48px]">
            <span className="flex size-[48px] flex-none items-center justify-center -m-[15px] mr-[calc(var(--spacing-xs)-15px)]">
              <input
                type="checkbox"
                checked={adult}
                onChange={(e) => setAdult(e.target.checked)}
                className="size-[22px] accent-heading"
              />
            </span>
            <span style={{ fontSize: "var(--text-body-sm)" }}>{c.adultAttestation}</span>
          </label>
        ) : null}
      </div>

    </Screen>
  );
}

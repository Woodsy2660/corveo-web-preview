import { Screen, ProfileLink } from "@/components/ui/Screen";
import { APP } from "@/copy/app";
import { SAFETY } from "@/copy/safety";

/**
 * About this app: the safety surface (Deliverable 12), what Corveo does
 * and does not do, on its own page under Settings. Reached from the
 * Settings menu; the profile icon in the header returns to Settings.
 */
export function About() {
  const c = APP.settings;

  return (
    <Screen overline={c.menu.about} title={SAFETY.title} action={<ProfileLink />}>
      <p className="eyebrow pb-[var(--spacing-3xs)]">{SAFETY.does.title}</p>
      <ul
        className="list-disc pb-[var(--spacing-sm)] pl-[var(--spacing-sm)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-base)" }}
      >
        {SAFETY.does.items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>

      <p className="eyebrow pb-[var(--spacing-3xs)]">{SAFETY.doesNot.title}</p>
      <ul
        className="list-disc pb-[var(--spacing-sm)] pl-[var(--spacing-sm)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-base)" }}
      >
        {SAFETY.doesNot.items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>

      <p className="pb-[var(--spacing-2xs)]" style={{ fontSize: "var(--text-body-base)" }}>
        {SAFETY.seekAdvice}
      </p>
      <p className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
        {SAFETY.disclaimer}
      </p>
    </Screen>
  );
}

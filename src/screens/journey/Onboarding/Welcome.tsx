import { useNavigate } from "react-router";
import { Button } from "@/components/ui/Button";
import { JOURNEY } from "@/copy/journey";
import { CORVEO_WORDMARK } from "@/copy/product";
import logoUrl from "@/assets/brand/logo.svg";

/**
 * Landing — the first thing the app shows. Deliberately empty: the logotype
 * at full size, a greeting, one button. The reading starts on the next
 * screen, so this one carries no eyebrow, no step dots and no copy to
 * scroll. Not wrapped in <Screen>, which would add the small header mark.
 */
export function Welcome() {
  const navigate = useNavigate();
  const c = JOURNEY.welcome;

  return (
    <div className="screen-shell" style={{ paddingTop: "var(--safe-top)" }}>
      <main className="flex flex-1 flex-col items-center justify-center px-[var(--spacing-md)]">
        <img
          src={logoUrl}
          alt={CORVEO_WORDMARK}
          className="fade-up"
          style={{ width: "176px", height: "auto" }}
        />
        <h1
          className="fade-up pt-[var(--spacing-lg)] text-center"
          style={{ fontSize: "var(--text-heading-4xl)", lineHeight: "var(--leading-heading-tight)" }}
        >
          {c.title}
        </h1>
      </main>

      <footer
        className="px-[var(--spacing-md)] pt-[var(--spacing-xs)]"
        style={{ paddingBottom: "calc(var(--spacing-md) + var(--safe-bottom))" }}
      >
        <Button onClick={() => navigate("/journey/intro")}>{c.cta}</Button>
      </footer>
    </div>
  );
}

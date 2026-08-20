import { useEffect, useRef, useState } from "react";
import { HEALTH_SYNC } from "@/copy/health-sync";

/**
 * The iOS Health permission sheet.
 *
 * DELIBERATE EXCEPTION to the semantic-token rule (docs/01 §8): this element
 * is drawn by iOS, not by Corveo. Reproducing it with Corveo's tokens would
 * make it look like our UI, which is exactly the wrong impression — the whole
 * point of the moment is that the patient is talking to Apple, not to us. So
 * the values below are Apple's system values, kept in one block, and used
 * nowhere else in the app.
 *
 * The green switch is iOS's own control colour and encodes switch position,
 * not anything about a reading. Nothing here evaluates a value; the sheet
 * never sees one.
 *
 * Behavioural fidelity that matters more than the pixels: whichever button
 * the patient presses, the app is told the same thing — that the sheet was
 * shown. iOS does not disclose the outcome, which is why `onDismiss` carries
 * no verdict. The toggles decide whether readings will subsequently arrive;
 * they do not tell the app anything.
 */

const IOS = {
  sheetBg: "#F2F2F7",
  rowBg: "#FFFFFF",
  separator: "#C6C6C8",
  label: "#000000",
  secondary: "rgba(60, 60, 67, 0.6)",
  blue: "#007AFF",
  switchOn: "#34C759",
  switchOff: "#E9E9EA",
  heart: "#FF2D55",
  heartTint: "rgba(255, 45, 85, 0.12)",
  scrim: "rgba(0, 0, 0, 0.32)",
  font: '-apple-system, "SF Pro Text", "SF Pro Display", system-ui, "Segoe UI", sans-serif',
  /** The iOS sheet presentation curve. */
  ease: "cubic-bezier(0.32, 0.72, 0, 1)",
} as const;

function HeartGlyph({ size = 15, color = IOS.heart }: { size?: number; color?: string }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true">
      <path
        d="M12 21s-7.5-4.7-9.3-9.1C1.3 8.3 3.3 5 6.6 5c2 0 3.4 1.1 4.2 2.3l.6.9.6-.9C12.8 6.1 14.2 5 16.2 5c3.3 0 5.3 3.3 3.9 6.9C18.3 16.3 12 21 12 21z"
        fill={color}
      />
    </svg>
  );
}

function AppIcon() {
  return (
    <div
      style={{
        width: 60,
        height: 60,
        borderRadius: 13.5,
        background: "var(--color-surface-color-1)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flex: "0 0 auto",
        boxShadow: "0 1px 3px rgba(0,0,0,0.16)",
      }}
      aria-hidden="true"
    >
      <HeartGlyph size={30} color="#FFFFFF" />
    </div>
  );
}

function Switch({
  on,
  onChange,
  label,
}: {
  on: boolean;
  onChange: (next: boolean) => void;
  label: string;
}) {
  return (
    <button
      role="switch"
      aria-checked={on}
      aria-label={label}
      onClick={() => onChange(!on)}
      style={{
        width: 51,
        height: 31,
        borderRadius: 31,
        border: "none",
        padding: 2,
        flex: "0 0 auto",
        background: on ? IOS.switchOn : IOS.switchOff,
        transition: `background 200ms ${IOS.ease}`,
        cursor: "pointer",
      }}
    >
      <span
        style={{
          display: "block",
          width: 27,
          height: 27,
          borderRadius: "50%",
          background: "#FFFFFF",
          boxShadow: "0 3px 8px rgba(0,0,0,0.15), 0 1px 1px rgba(0,0,0,0.16)",
          transform: `translateX(${on ? 20 : 0}px)`,
          transition: `transform 200ms ${IOS.ease}`,
        }}
      />
    </button>
  );
}

export function AppleHealthSheet({
  open,
  appName,
  onDismiss,
}: {
  open: boolean;
  appName: string;
  /**
   * Fires when the sheet closes. `readable` says whether data will now flow —
   * it is for the demo's simulated Health store, NOT for the app. The app is
   * never told the outcome (docs/03 §4).
   */
  onDismiss: (readable: boolean) => void;
}) {
  const c = HEALTH_SYNC.sheet;
  const [granted, setGranted] = useState<Record<string, boolean>>({});
  const [shown, setShown] = useState(false);
  const closing = useRef(false);

  useEffect(() => {
    if (!open) return;
    setGranted({});
    closing.current = false;
    // One frame before animating in, so the transition actually runs.
    const id = requestAnimationFrame(() => setShown(true));
    return () => {
      cancelAnimationFrame(id);
      setShown(false);
    };
  }, [open]);

  if (!open) return null;

  const allOn = c.types.every((t) => granted[t.id]);
  const anyOn = c.types.some((t) => granted[t.id]);

  const close = (readable: boolean) => {
    if (closing.current) return;
    closing.current = true;
    setShown(false);
    window.setTimeout(() => onDismiss(readable), 320);
  };

  const rowStyle: React.CSSProperties = {
    display: "flex",
    alignItems: "center",
    gap: 12,
    background: IOS.rowBg,
    padding: "11px 16px",
    minHeight: 44,
    fontSize: 17,
    letterSpacing: "-0.41px",
    color: IOS.label,
  };

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 60,
        display: "flex",
        flexDirection: "column",
        justifyContent: "flex-end",
        fontFamily: IOS.font,
      }}
      role="dialog"
      aria-modal="true"
      aria-label={c.title(appName)}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: IOS.scrim,
          opacity: shown ? 1 : 0,
          transition: `opacity 320ms ${IOS.ease}`,
        }}
      />

      <div
        style={{
          position: "relative",
          background: IOS.sheetBg,
          borderRadius: "14px 14px 0 0",
          maxHeight: "92%",
          display: "flex",
          flexDirection: "column",
          transform: shown ? "translateY(0)" : "translateY(100%)",
          transition: `transform 380ms ${IOS.ease}`,
          overflow: "hidden",
        }}
      >
        {/* Navigation bar — iOS puts the decision here, not at the bottom. */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            padding: "14px 16px",
            borderBottom: `0.5px solid ${IOS.separator}`,
            background: IOS.sheetBg,
            flex: "0 0 auto",
          }}
        >
          <button
            onClick={() => close(false)}
            style={{
              background: "none",
              border: "none",
              padding: 0,
              color: IOS.blue,
              fontSize: 17,
              letterSpacing: "-0.41px",
              cursor: "pointer",
            }}
          >
            {c.dontAllow}
          </button>
          <button
            onClick={() => close(anyOn)}
            style={{
              background: "none",
              border: "none",
              padding: 0,
              color: IOS.blue,
              fontSize: 17,
              fontWeight: 600,
              letterSpacing: "-0.41px",
              cursor: "pointer",
            }}
          >
            {c.allow}
          </button>
        </div>

        <div style={{ overflowY: "auto", paddingBottom: 28 }}>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 14,
              padding: "20px 16px 16px",
            }}
          >
            <AppIcon />
            <p
              style={{
                margin: 0,
                fontSize: 17,
                fontWeight: 600,
                lineHeight: 1.29,
                letterSpacing: "-0.41px",
                color: IOS.label,
              }}
            >
              {c.title(appName)}
            </p>
          </div>

          <p
            style={{
              margin: 0,
              padding: "0 16px 20px",
              fontSize: 13,
              lineHeight: 1.38,
              color: IOS.secondary,
            }}
          >
            {c.body}
          </p>

          <div
            style={{
              borderTop: `0.5px solid ${IOS.separator}`,
              borderBottom: `0.5px solid ${IOS.separator}`,
            }}
          >
            <div style={rowStyle}>
              <span style={{ flex: 1 }}>{c.turnOnAll}</span>
              <Switch
                on={allOn}
                label={c.turnOnAll}
                onChange={(next) =>
                  setGranted(
                    next ? Object.fromEntries(c.types.map((t) => [t.id, true])) : {},
                  )
                }
              />
            </div>
          </div>

          <p
            style={{
              margin: 0,
              padding: "26px 16px 6px",
              fontSize: 13,
              letterSpacing: "0.06px",
              color: IOS.secondary,
            }}
          >
            {c.readSection(appName)}
          </p>

          <div
            style={{
              borderTop: `0.5px solid ${IOS.separator}`,
              borderBottom: `0.5px solid ${IOS.separator}`,
            }}
          >
            {c.types.map((t, i) => (
              <div
                key={t.id}
                style={{
                  ...rowStyle,
                  borderTop: i === 0 ? "none" : `0.5px solid ${IOS.separator}`,
                }}
              >
                <span
                  style={{
                    width: 29,
                    height: 29,
                    borderRadius: 7,
                    background: IOS.heartTint,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    flex: "0 0 auto",
                  }}
                >
                  <HeartGlyph />
                </span>
                <span style={{ flex: 1 }}>{t.label}</span>
                <Switch
                  on={!!granted[t.id]}
                  label={t.label}
                  onChange={(next) => setGranted((g) => ({ ...g, [t.id]: next }))}
                />
              </div>
            ))}
          </div>

          <p
            style={{
              margin: 0,
              padding: "10px 16px 0",
              fontSize: 13,
              lineHeight: 1.38,
              color: IOS.secondary,
            }}
          >
            {c.footnote}
          </p>
        </div>
      </div>
    </div>
  );
}

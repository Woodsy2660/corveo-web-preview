import { useEffect, useState } from "react";

/**
 * The stage graphics for "Behind the scenes".
 *
 * One cast, recurring: a luminous capsule (a single reading), the phone, the
 * Apple Health mark, the Corveo mark, and the record card. Each scene is a
 * composition of those under one light source, not a boxes-and-arrows
 * diagram — the capsule is the thing the audience follows from the first
 * frame to the last.
 *
 * Nothing here encodes a value. The only number that appears is in the
 * penultimate scene, shown plainly and with deliberate emptiness around it.
 */

const W = 720;
const H = 400;

export function useReducedMotion(): boolean {
  const [reduced, setReduced] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReduced(mq.matches);
    const on = () => setReduced(mq.matches);
    mq.addEventListener("change", on);
    return () => mq.removeEventListener("change", on);
  }, []);
  return reduced;
}

/* ------------------------------------------------------------------ defs */

function Defs() {
  return (
    <defs>
      {/* Edge light: bright where the key light falls, falling away with the form. */}
      <linearGradient id="edge" x1="0" y1="0" x2="0.6" y2="1">
        <stop offset="0%" stopColor="rgba(255,255,255,0.58)" />
        <stop offset="55%" stopColor="rgba(255,255,255,0.20)" />
        <stop offset="100%" stopColor="rgba(255,255,255,0.07)" />
      </linearGradient>

      <linearGradient id="edgeSoft" x1="0" y1="0" x2="0.6" y2="1">
        <stop offset="0%" stopColor="rgba(255,255,255,0.26)" />
        <stop offset="100%" stopColor="rgba(255,255,255,0.05)" />
      </linearGradient>

      <linearGradient id="glass" x1="0" y1="0" x2="0.4" y2="1">
        <stop offset="0%" stopColor="rgba(255,255,255,0.055)" />
        <stop offset="100%" stopColor="rgba(255,255,255,0.012)" />
      </linearGradient>

      <linearGradient id="screen" x1="0" y1="0" x2="0.3" y2="1">
        <stop offset="0%" stopColor="rgba(120,140,255,0.10)" />
        <stop offset="100%" stopColor="rgba(0,0,0,0)" />
      </linearGradient>

      {/* The reading itself. */}
      <linearGradient id="capsule" x1="0" y1="0" x2="1" y2="0.6">
        <stop offset="0%" stopColor="#9AA7FF" />
        <stop offset="100%" stopColor="#4FD1E6" />
      </linearGradient>

      <linearGradient id="indigoFill" x1="0" y1="0" x2="0.5" y2="1">
        <stop offset="0%" stopColor="#6B7BF0" />
        <stop offset="100%" stopColor="#3D4CA8" />
      </linearGradient>

      <linearGradient id="healthFill" x1="0" y1="0" x2="0.4" y2="1">
        <stop offset="0%" stopColor="#FF4E74" />
        <stop offset="100%" stopColor="#E4093F" />
      </linearGradient>

      {/* A path that carries light at one end and dissolves at the other. */}
      <linearGradient id="pathLive" x1="0" y1="0" x2="1" y2="0">
        <stop offset="0%" stopColor="rgba(154,167,255,0.10)" />
        <stop offset="45%" stopColor="rgba(154,167,255,0.75)" />
        <stop offset="100%" stopColor="rgba(79,209,230,0.85)" />
      </linearGradient>

      <linearGradient id="pathDead" x1="1" y1="0" x2="0" y2="0">
        <stop offset="0%" stopColor="rgba(255,255,255,0.22)" />
        <stop offset="70%" stopColor="rgba(255,255,255,0.03)" />
        <stop offset="100%" stopColor="rgba(255,255,255,0)" />
      </linearGradient>

      <filter id="bloom" x="-90%" y="-90%" width="280%" height="280%">
        <feGaussianBlur stdDeviation="11" />
      </filter>
      <filter id="bloomTight" x="-60%" y="-60%" width="220%" height="220%">
        <feGaussianBlur stdDeviation="4.5" />
      </filter>
    </defs>
  );
}

function Frame({ children }: { children: React.ReactNode }) {
  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      style={{ width: "min(720px, 86vw)", height: "100%", overflow: "visible" }}
      aria-hidden="true"
    >
      <Defs />
      {children}
    </svg>
  );
}

function Label({ x, y, children }: { x: number; y: number; children: string }) {
  return (
    <text
      x={x}
      y={y}
      textAnchor="middle"
      fontSize="13"
      letterSpacing="0.015em"
      /* 0.58 over black measures 5.9:1. At 0.44 it was 4.06:1, which is
         under the floor for text this size and disappears on a projector. */
      fill="rgba(235,235,245,0.58)"
      style={{ fontFamily: "inherit" }}
    >
      {children}
    </text>
  );
}

/* ----------------------------------------------------------------- cast */

/** The reading. Bloom behind, solid in front. */
function Capsule({
  x,
  y,
  w = 62,
  h = 28,
  o = 1,
}: {
  x: number;
  y: number;
  w?: number;
  h?: number;
  o?: number;
}) {
  return (
    <g opacity={o}>
      <rect
        x={x - w / 2}
        y={y - h / 2}
        width={w}
        height={h}
        rx={h / 2}
        fill="url(#capsule)"
        filter="url(#bloom)"
        opacity={0.55}
      />
      <rect
        x={x - w / 2}
        y={y - h / 2}
        width={w}
        height={h}
        rx={h / 2}
        fill="url(#capsule)"
      />
      <rect
        x={x - w / 2 + 1}
        y={y - h / 2 + 1}
        width={w - 2}
        height={(h - 2) / 2}
        rx={(h - 2) / 2}
        fill="rgba(255,255,255,0.22)"
      />
    </g>
  );
}

function Tile({
  cx,
  cy,
  size = 112,
  fill,
  children,
}: {
  cx: number;
  cy: number;
  size?: number;
  fill?: string;
  children?: React.ReactNode;
}) {
  const r = size / 2;
  return (
    <g>
      <rect
        x={cx - r}
        y={cy - r}
        width={size}
        height={size}
        rx={size * 0.28}
        fill={fill ?? "url(#glass)"}
        stroke="url(#edge)"
        strokeWidth={1.4}
      />
      {children}
    </g>
  );
}

function Heart({ cx, cy, size = 46, fill }: { cx: number; cy: number; size?: number; fill: string }) {
  const s = size / 24;
  return (
    <g transform={`translate(${cx - size / 2} ${cy - size / 2}) scale(${s})`}>
      <path
        d="M12 21.2s-7.3-4.6-9.1-9C1.4 8.6 3.4 5.4 6.6 5.4c2 0 3.3 1.1 4.1 2.2l.6.9.6-.9c.8-1.1 2.1-2.2 4.1-2.2 3.2 0 5.2 3.2 3.8 6.8-1.8 4.4-9.1 9-9.1 9z"
        fill={fill}
      />
    </g>
  );
}

/** Corveo — the same mark the iOS permission sheet shows. */
function CorveoMark({ cx, cy, size = 112 }: { cx: number; cy: number; size?: number }) {
  return (
    <g>
      <rect
        x={cx - size / 2}
        y={cy - size / 2}
        width={size}
        height={size}
        rx={size * 0.28}
        fill="url(#indigoFill)"
        filter="url(#bloom)"
        opacity={0.34}
      />
      <Tile cx={cx} cy={cy} size={size} fill="url(#indigoFill)" />
      <Heart cx={cx} cy={cy} size={size * 0.42} fill="rgba(255,255,255,0.95)" />
    </g>
  );
}

function HealthMark({ cx, cy, size = 112 }: { cx: number; cy: number; size?: number }) {
  return (
    <g>
      <Tile cx={cx} cy={cy} size={size} fill="rgba(255,255,255,0.045)" />
      <Heart cx={cx} cy={cy} size={size * 0.44} fill="url(#healthFill)" />
    </g>
  );
}

/** An upper-arm cuff, schematic: the band, its bladder, and the tube. */
function CuffMark({ cx, cy, size = 112 }: { cx: number; cy: number; size?: number }) {
  const r = size / 2;
  return (
    <g>
      <Tile cx={cx} cy={cy} size={size} />
      <rect
        x={cx - r * 0.52}
        y={cy - r * 0.34}
        width={r * 1.04}
        height={r * 0.68}
        rx={7}
        fill="none"
        stroke="url(#edge)"
        strokeWidth={1.5}
      />
      <rect
        x={cx - r * 0.32}
        y={cy - r * 0.16}
        width={r * 0.64}
        height={r * 0.32}
        rx={4}
        fill="rgba(255,255,255,0.10)"
      />
      <path
        d={`M${cx - r * 0.52} ${cy} h${-r * 0.2} a6 6 0 0 0 -6 6 v${r * 0.22}`}
        fill="none"
        stroke="url(#edgeSoft)"
        strokeWidth={1.5}
      />
    </g>
  );
}

function Phone({
  cx,
  cy,
  w = 168,
  h = 320,
  screen,
}: {
  cx: number;
  cy: number;
  w?: number;
  h?: number;
  screen?: React.ReactNode;
}) {
  return (
    <g>
      <rect
        x={cx - w / 2}
        y={cy - h / 2}
        width={w}
        height={h}
        rx={38}
        fill="url(#glass)"
        stroke="url(#edge)"
        strokeWidth={1.5}
      />
      <rect
        x={cx - w / 2 + 9}
        y={cy - h / 2 + 9}
        width={w - 18}
        height={h - 18}
        rx={30}
        fill="url(#screen)"
        stroke="rgba(255,255,255,0.06)"
        strokeWidth={1}
      />
      {/* the notch bar, for read as "phone" at a glance */}
      <rect
        x={cx - 26}
        y={cy - h / 2 + 20}
        width={52}
        height={6}
        rx={3}
        fill="rgba(255,255,255,0.16)"
      />
      {screen}
    </g>
  );
}

function RecordCard({
  cx,
  cy,
  w = 300,
  h = 150,
  children,
}: {
  cx: number;
  cy: number;
  w?: number;
  h?: number;
  children?: React.ReactNode;
}) {
  return (
    <g>
      <rect
        x={cx - w / 2}
        y={cy - h / 2}
        width={w}
        height={h}
        rx={22}
        fill="url(#glass)"
        stroke="url(#edge)"
        strokeWidth={1.4}
      />
      {children}
    </g>
  );
}

/* --------------------------------------------------------------- scenes */

export function Visual({ id }: { id: string }) {
  const still = useReducedMotion();

  switch (id) {
    /* ------------------------------------------------------------ intro */
    case "intro":
      return (
        <Frame>
          <ellipse cx={360} cy={200} rx={210} ry={90} fill="rgba(124,140,248,0.10)" filter="url(#bloom)" />
          <g style={still ? undefined : { animation: "bts-breathe 5s ease-in-out infinite", transformOrigin: "360px 200px" }}>
            <Capsule x={360} y={200} w={132} h={54} />
          </g>
          <Label x={360} y={286}>one reading</Label>
        </Frame>
      );

    /* ----------------------------------------------------------- health */
    case "health":
      return (
        <Frame>
          <path id="p-health" d="M212 200 C 300 148, 420 148, 508 200" fill="none" stroke="none" />
          <path
            d="M212 200 C 300 148, 420 148, 508 200"
            fill="none"
            stroke="url(#pathLive)"
            strokeWidth={2}
            strokeLinecap="round"
          />
          <CuffMark cx={150} cy={200} />
          <HealthMark cx={570} cy={200} />
          <Label x={150} y={286}>Cuff</Label>
          <Label x={570} y={286}>Apple Health</Label>

          {still ? (
            <Capsule x={360} y={166} w={52} h={24} />
          ) : (
            <g>
              <Capsule x={0} y={0} w={52} h={24} />
              <animateMotion dur="3.4s" repeatCount="indefinite" keyPoints="0;1" keyTimes="0;1" calcMode="spline" keySplines="0.42 0 0.58 1">
                <mpath href="#p-health" />
              </animateMotion>
            </g>
          )}
        </Frame>
      );

    /* ------------------------------------------------------------- read */
    case "read":
      return (
        <Frame>
          {/* reads — the direction that exists */}
          <path id="p-read" d="M258 168 C 320 132, 400 132, 462 168" fill="none" stroke="none" />
          <path
            d="M258 168 C 320 132, 400 132, 462 168"
            fill="none"
            stroke="url(#pathLive)"
            strokeWidth={2.2}
            strokeLinecap="round"
          />
          <path d="M462 168 l-11 -7 l1.5 9.5 z" fill="#4FD1E6" />
          <text x={360} y={122} textAnchor="middle" fontSize="13" fill="rgba(160,200,255,0.85)" letterSpacing="0.02em">
            reads
          </text>

          {/* writes — shown as the absence it is */}
          <path
            d="M462 246 C 400 284, 320 284, 258 246"
            fill="none"
            stroke="url(#pathDead)"
            strokeWidth={2}
            strokeLinecap="round"
            strokeDasharray="2 9"
          />
          <g opacity={0.55}>
            <circle cx={360} cy={272} r={13} fill="none" stroke="rgba(255,255,255,0.32)" strokeWidth={1.3} />
            <path d="M352 264 l16 16" stroke="rgba(255,255,255,0.4)" strokeWidth={1.4} strokeLinecap="round" />
          </g>
          {/* Subordinate to "reads", but it still has to be readable — the
              whole scene is about what this word does NOT do. */}
          <text x={360} y={306} textAnchor="middle" fontSize="13" fill="rgba(235,235,245,0.46)" letterSpacing="0.02em">
            writes
          </text>

          <HealthMark cx={196} cy={200} />
          <CorveoMark cx={524} cy={200} />
          <Label x={196} y={286}>Apple Health</Label>
          <Label x={524} y={286}>Corveo</Label>

          {!still ? (
            <g>
              <Capsule x={0} y={0} w={46} h={22} />
              <animateMotion dur="2.9s" repeatCount="indefinite" calcMode="spline" keySplines="0.42 0 0.58 1" keyPoints="0;1" keyTimes="0;1">
                <mpath href="#p-read" />
              </animateMotion>
            </g>
          ) : null}
        </Frame>
      );

    /* ------------------------------------------------------------- wake */
    case "wake": {
      /* The ripple has to originate from the phone, so both are driven off
         one centre. Hard-coding 360 while the phone sat at 430 put the
         pulse 70px off its own source. */
      const PX = 408;
      return (
        <Frame>
          {!still
            ? [0, 1].map((i) => (
                <rect
                  key={i}
                  x={PX - 84}
                  y={200 - 160}
                  width={168}
                  height={320}
                  rx={38}
                  fill="none"
                  stroke="rgba(79,209,230,0.5)"
                  strokeWidth={1.2}
                  style={{
                    transformOrigin: `${PX}px 200px`,
                    animation: `bts-ripple 3.4s ${i * 1.7}s cubic-bezier(0.22,1,0.36,1) infinite`,
                  }}
                />
              ))
            : null}

          {/* Reaches the phone's edge rather than stopping short of it. */}
          <path id="p-wake" d={`M104 200 H ${PX - 84}`} fill="none" stroke="none" />
          <path
            d={`M104 200 H ${PX - 84}`}
            fill="none"
            stroke="url(#pathLive)"
            strokeWidth={2}
            strokeLinecap="round"
            opacity={0.75}
          />
          <Phone cx={PX} cy={200} />
          <Label x={PX} y={382}>screen off</Label>

          {still ? (
            <Capsule x={200} y={200} w={52} h={24} />
          ) : (
            <g>
              <Capsule x={0} y={0} w={52} h={24} />
              <animateMotion dur="3.2s" repeatCount="indefinite" calcMode="spline" keySplines="0.5 0 0.5 1" keyPoints="0;1" keyTimes="0;1">
                <mpath href="#p-wake" />
              </animateMotion>
            </g>
          )}
        </Frame>
      );
    }

    /* ------------------------------------------------------------- hold */
    case "hold":
      return (
        <Frame>
          <ellipse cx={360} cy={200} rx={150} ry={140} fill="rgba(124,140,248,0.08)" filter="url(#bloom)" />
          <Phone
            cx={360}
            cy={200}
            screen={
              <g>
                {[0, 1, 2].map((i) => (
                  <g key={i} opacity={0.9 - i * 0.16}>
                    <Capsule x={360} y={150 + i * 50} w={104} h={30} />
                  </g>
                ))}
                {/* the seal: a frosted pane closing over them */}
                <rect
                  x={360 - 75}
                  y={200 - 151}
                  width={150}
                  height={302}
                  rx={30}
                  fill="rgba(10,12,24,0.42)"
                  stroke="rgba(255,255,255,0.10)"
                  strokeWidth={1}
                />
                <g transform="translate(360 296)">
                  <rect x={-11} y={-8} width={22} height={17} rx={4.5} fill="rgba(255,255,255,0.62)" />
                  <path
                    d="M-6 -8 v-5 a6 6 0 0 1 12 0 v5"
                    fill="none"
                    stroke="rgba(255,255,255,0.62)"
                    strokeWidth={2}
                  />
                </g>
              </g>
            }
          />
          <Label x={360} y={382}>held on device</Label>
        </Frame>
      );

    /* ------------------------------------------------------------- once */
    case "once":
      return (
        <Frame>
          {/* Start clear of the capsules rather than under them. */}
          {[-58, 0, 58].map((dy, i) => (
            <path
              key={i}
              d={`M186 ${200 + dy} C 268 ${200 + dy}, 310 200, 372 200`}
              fill="none"
              stroke="rgba(255,255,255,0.20)"
              strokeWidth={1.6}
              strokeDasharray={i === 1 ? undefined : "3 7"}
              strokeLinecap="round"
            />
          ))}
          {[-58, 0, 58].map((dy, i) => (
            <g key={i} opacity={i === 1 ? 0.85 : 0.4}>
              <Capsule x={150} y={200 + dy} w={54} h={24} o={i === 1 ? 0.9 : 0.45} />
            </g>
          ))}
          <Label x={150} y={306}>three attempts</Label>

          <RecordCard cx={512} cy={200} w={272} h={132}>
            <g>
              <Capsule x={512} y={172} w={150} h={34} />
              <rect x={512 - 75} y={206} width={150} height={7} rx={3.5} fill="rgba(255,255,255,0.10)" />
              <rect x={512 - 75} y={224} width={96} height={7} rx={3.5} fill="rgba(255,255,255,0.07)" />
            </g>
          </RecordCard>
          <Label x={512} y={306}>one row</Label>
        </Frame>
      );

    /* ------------------------------------------------------------ plain */
    case "plain":
      return (
        <Frame>
          <ellipse cx={360} cy={196} rx={230} ry={96} fill="rgba(124,140,248,0.07)" filter="url(#bloom)" />
          <RecordCard cx={360} cy={196} w={352} h={172}>
            <text
              x={360}
              y={196}
              textAnchor="middle"
              fontSize="64"
              fontWeight="600"
              letterSpacing="-0.035em"
              fill="#F5F5F7"
              style={{ fontFamily: "inherit" }}
            >
              134/86
            </text>
            <text
              x={360}
              y={232}
              textAnchor="middle"
              fontSize="13.5"
              fill="rgba(235,235,245,0.42)"
              letterSpacing="0.02em"
              style={{ fontFamily: "inherit" }}
            >
              mmHg · 19 Aug, 8:14 am · Apple Health
            </text>
          </RecordCard>
          <Label x={360} y={336}>as recorded, and nothing else</Label>
        </Frame>
      );

    /* -------------------------------------------------------------- end */
    default: {
      const marks = [
        { x: 96, label: "Cuff" },
        { x: 264, label: "Health" },
        { x: 442, label: "Phone" },
        { x: 618, label: "Record" },
      ];
      return (
        <Frame>
          <path id="p-end" d="M96 200 H 618" fill="none" stroke="none" />
          <path
            d="M96 200 H 618"
            fill="none"
            stroke="url(#pathLive)"
            strokeWidth={2}
            strokeLinecap="round"
            strokeDasharray={still ? undefined : "522"}
            style={
              still
                ? undefined
                : { animation: "bts-draw 1.5s cubic-bezier(0.22,1,0.36,1) both", ["--len" as string]: "522" }
            }
          />
          {marks.map((m, i) => (
            <g key={m.label}>
              <circle
                cx={m.x}
                cy={200}
                r={i === marks.length - 1 ? 13 : 9}
                fill={i === marks.length - 1 ? "url(#capsule)" : "rgba(255,255,255,0.14)"}
                stroke={i === marks.length - 1 ? "none" : "rgba(255,255,255,0.26)"}
                strokeWidth={1.2}
              />
              {i === marks.length - 1 ? (
                <circle cx={m.x} cy={200} r={13} fill="url(#capsule)" filter="url(#bloomTight)" opacity={0.8} />
              ) : null}
              <Label x={m.x} y={244}>
                {m.label}
              </Label>
            </g>
          ))}
        </Frame>
      );
    }
  }
}

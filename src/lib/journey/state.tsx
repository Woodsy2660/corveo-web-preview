/**
 * Journey (onboarding) progression state.
 *
 * App state only — never health data (readings live behind the API; nothing
 * clinical is stored here). Persisted to localStorage so a half-finished
 * journey resumes where it left off.
 */

import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";

export type ConnectChoice = "healthkit" | "manual" | "none";
export type CadenceChoice = "twice_daily" | "daily" | "few_weekly";

export interface JourneyState {
  journeyComplete: boolean;
  connectChoice: ConnectChoice | null;
  cadence: CadenceChoice | null;
  /** Email captured at signup/sign-in. Mock auth — no password stored. */
  email: string | null;
}

interface JourneyContextValue extends JourneyState {
  setConnectChoice: (c: ConnectChoice) => void;
  setCadence: (c: CadenceChoice) => void;
  setEmail: (email: string) => void;
  completeJourney: () => void;
  resetJourney: () => void;
}

const KEY = "corveo.journey.v1";

const DEFAULT_STATE: JourneyState = {
  journeyComplete: false,
  connectChoice: null,
  cadence: null,
  email: null,
};

function load(): JourneyState {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return { ...DEFAULT_STATE, ...(JSON.parse(raw) as JourneyState) };
  } catch {
    /* fall through */
  }
  return DEFAULT_STATE;
}

const JourneyContext = createContext<JourneyContextValue | null>(null);

export function JourneyProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<JourneyState>(load);

  const update = useCallback((patch: Partial<JourneyState>) => {
    setState((prev) => {
      const next = { ...prev, ...patch };
      localStorage.setItem(KEY, JSON.stringify(next));
      return next;
    });
  }, []);

  const value = useMemo<JourneyContextValue>(
    () => ({
      ...state,
      setConnectChoice: (connectChoice) => update({ connectChoice }),
      setCadence: (cadence) => update({ cadence }),
      setEmail: (email) => update({ email }),
      completeJourney: () => update({ journeyComplete: true }),
      resetJourney: () => {
        localStorage.removeItem(KEY);
        setState(DEFAULT_STATE);
      },
    }),
    [state, update],
  );

  return <JourneyContext.Provider value={value}>{children}</JourneyContext.Provider>;
}

export function useJourney(): JourneyContextValue {
  const ctx = useContext(JourneyContext);
  if (!ctx) throw new Error("useJourney must be used inside JourneyProvider");
  return ctx;
}

/**
 * Centralised configuration from environment variables.
 *
 * All env access goes through this module so that:
 * - TypeScript catches typos in env var names
 * - Defaults and validation live in one place
 * - The mock/real API decision is made once, not scattered
 */

export type AppEnv = "local" | "dev" | "staging" | "prod";

function getAppEnv(): AppEnv {
  const raw = import.meta.env.VITE_APP_ENV;
  if (raw === "local" || raw === "dev" || raw === "staging" || raw === "prod") {
    return raw;
  }
  return "local";
}

export const config = {
  /** Supabase project URL. Empty in local dev with mock API. */
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL ?? "",

  /** Supabase anon key. Empty in local dev with mock API. */
  supabaseAnonKey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? "",

  /** Current environment: local, dev, staging, or prod */
  appEnv: getAppEnv(),

  /** True in Vite dev server (npm run dev) */
  isDev: import.meta.env.DEV,

  /** True in production build (npm run build) */
  isProd: import.meta.env.PROD,

  /**
   * Demo mode — enables synthetic cuff readings in web preview.
   * Active when VITE_DEMO=true OR when running in dev mode.
   */
  isDemo: import.meta.env.DEV || import.meta.env.VITE_DEMO === "true",

  /**
   * True when Supabase credentials are configured.
   * When false, the app uses the mock API.
   */
  hasSupabase:
    !!import.meta.env.VITE_SUPABASE_URL &&
    !!import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
} as const;

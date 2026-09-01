/// <reference types="vite/client" />

/**
 * Type definitions for environment variables.
 *
 * All custom env vars must be prefixed with VITE_ to be exposed to the client.
 * See .env.example for documentation on each variable.
 */
interface ImportMetaEnv {
  /** Supabase project URL — public, compiled into the bundle */
  readonly VITE_SUPABASE_URL: string;

  /** Supabase anon/publishable key — public by design, safe to bundle */
  readonly VITE_SUPABASE_PUBLISHABLE_KEY: string;

  /** Environment label: 'local' | 'dev' | 'staging' | 'prod' */
  readonly VITE_APP_ENV: "local" | "dev" | "staging" | "prod";

  /** Demo mode flag — enables synthetic cuff readings in web preview */
  readonly VITE_DEMO?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

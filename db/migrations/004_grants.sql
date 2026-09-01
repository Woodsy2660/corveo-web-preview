-- =============================== 004_grants.sql
revoke execute on function public.ingest_bp_batch(uuid, jsonb)
  from public, anon;
grant  execute on function public.ingest_bp_batch(uuid, jsonb)
  to authenticated;
revoke execute on function public.canonicalise_bp(uuid, timestamptz, timestamptz)
  from public, anon;
grant  execute on function public.canonicalise_bp(uuid, timestamptz, timestamptz)
  to authenticated;   -- REQUIRED (B3): EXECUTE is checked against the CALLING
                      -- role even inside ingest_bp_batch's call chain; the
                      -- ownership guard makes direct calls safe.
-- Function owner must be a privileged migration role (e.g. postgres) so the
-- DEFINER identity carries the update capability clients lack.

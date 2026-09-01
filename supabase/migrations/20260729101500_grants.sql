-- Migration: GRANT / REVOKE in one auditable place
-- Purpose: PostgREST exposes only what is granted; default privileges to
--          anon/authenticated on new public tables would otherwise leak.
-- Ref: docs/migration-plan-v0.2.md §16
--
-- Base tables are not the client contract. Reads go through views, writes
-- through RPCs. security_invoker views require SELECT on the underlying
-- tables; RLS is the isolation. Tables are tagged @omit so PostgREST does
-- not list them in the OpenAPI.

revoke all on all tables in schema public from public, anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
revoke all on all sequences in schema public from public, anon, authenticated;

grant usage on schema public to anon, authenticated, service_role;

-- Owner-equivalent access for the dashboard / service role. Revoking PUBLIC
-- above would otherwise drop the grants they inherited.
grant all on all tables in schema public to postgres, service_role;
grant all on all functions in schema public to postgres, service_role;
grant all on all sequences in schema public to postgres, service_role;

-- Invoker views read these through RLS. No INSERT/UPDATE/DELETE on clinical
-- tables for the patient role.
grant select on
  public.app_user,
  public.observation,
  public.observation_component,
  public.consent_event
to authenticated;

grant select on
  public.v_bp_readings,
  public.v_bp_trend,
  public.v_consent_status,
  public.v_program_progress
to authenticated;

grant select, insert, update on public.program_progress to authenticated;

-- RLS helpers must be executable by the role whose queries they gate.
grant execute on function public.get_app_user_id() to authenticated;
grant execute on function public.has_active_consent(uuid) to authenticated;
grant execute on function public.ingest_observations(jsonb) to authenticated;
grant execute on function public.enrol_patient(text, boolean) to authenticated;
grant execute on function public.record_consent(text, text) to authenticated;
grant execute on function public.withdraw_consent() to authenticated;
grant execute on function public.soft_delete_observation(uuid) to authenticated;
grant execute on function public.delete_account() to authenticated;
grant execute on function public.export_patient_data() to authenticated;

-- anon (pre-signup anonymous session) gets schema usage only.

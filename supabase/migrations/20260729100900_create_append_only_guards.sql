-- Migration: Append-only guards on consent_event and audit_event
-- Purpose: Enforce A.12.6 in the database, not in a comment
-- Ref: docs/migration-plan-v0.2.md §10
--
-- Revokes catch the patient role. The trigger catches security-definer
-- paths that a revoke does not.

revoke update, delete on public.consent_event from anon, authenticated;
revoke update, delete on public.audit_event  from anon, authenticated;

create trigger consent_event_append_only
  before update or delete on public.consent_event
  for each row execute function public.prevent_mutation();

create trigger audit_event_append_only
  before update or delete on public.audit_event
  for each row execute function public.prevent_mutation();

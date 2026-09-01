-- Migration: Create read views
-- Purpose: Flatten the parent/child model for the front end
-- Ref: docs/02-data-model-and-api.md §4.3; docs/migration-plan-v0.2.md §12
--
-- All views are security_invoker so RLS on the base tables is the authority.
-- The user_id filter is therefore not repeated in the view body.

--------------------------------------------------------------------------------
-- v_bp_readings
--------------------------------------------------------------------------------

create view public.v_bp_readings
with (security_invoker = true) as
select
  o.id,
  o.user_id,
  o.effective_time,
  o.effective_tz,
  sys.value_quantity as systolic,
  dia.value_quantity as diastolic,
  o.source_type,
  o.source_name,
  o.body_site_code,
  case o.body_site_code
    when '368208006' then 'Left arm'
    when '368209003' then 'Right arm'
    else null
  end as body_site_display
from public.observation o
join public.observation_component sys
  on sys.observation_id = o.id and sys.code = '8480-6'
join public.observation_component dia
  on dia.observation_id = o.id and dia.code = '8462-4'
where o.code = '85354-9'
  and o.deleted_at is null;

comment on view public.v_bp_readings is
  'Flattened BP readings. Front end codes against this, never the base tables.';

--------------------------------------------------------------------------------
-- v_bp_trend — daily grain (D-02), local calendar date from effective_tz
--------------------------------------------------------------------------------

create view public.v_bp_trend
with (security_invoker = true) as
select
  o.user_id,
  (o.effective_time at time zone o.effective_tz)::date as day,
  min(sys.value_quantity)           as min_systolic,
  max(sys.value_quantity)           as max_systolic,
  round(avg(sys.value_quantity), 0) as mean_systolic,
  min(dia.value_quantity)           as min_diastolic,
  max(dia.value_quantity)           as max_diastolic,
  round(avg(dia.value_quantity), 0) as mean_diastolic,
  count(*)                          as reading_count
from public.observation o
join public.observation_component sys
  on sys.observation_id = o.id and sys.code = '8480-6'
join public.observation_component dia
  on dia.observation_id = o.id and dia.code = '8462-4'
where o.code = '85354-9'
  and o.deleted_at is null
group by o.user_id, (o.effective_time at time zone o.effective_tz)::date;

comment on view public.v_bp_trend is
  'Daily BP aggregates for the trend chart. Day is derived from effective_tz, never from UTC.';

--------------------------------------------------------------------------------
-- v_consent_status — one row even when the patient has no events yet
--------------------------------------------------------------------------------

create view public.v_consent_status
with (security_invoker = true) as
select
  public.has_active_consent(public.get_app_user_id()) as has_active_consent,
  (select ce.version
     from public.consent_event ce
    where ce.user_id = public.get_app_user_id()
    order by ce.occurred_at desc, ce.id desc
    limit 1) as version,
  (select ce.occurred_at
     from public.consent_event ce
    where ce.user_id = public.get_app_user_id()
    order by ce.occurred_at desc, ce.id desc
    limit 1) as last_event_at;

comment on view public.v_consent_status is
  'Current consent state for the authenticated user, derived from the latest consent_event.';

--------------------------------------------------------------------------------
-- v_program_progress
--------------------------------------------------------------------------------

create view public.v_program_progress
with (security_invoker = true) as
select
  pp.current_week,
  pp.completed_steps,
  pp.updated_at
from public.program_progress pp;

comment on view public.v_program_progress is
  'Program progress for the authenticated user. RLS on program_progress is the filter.';

-- =============================== 002_ingest_bp_batch.sql
-- SECURITY INVOKER. All-or-nothing: any structurally invalid row raises and
-- rolls back the whole call, so the client's whole-snapshot acknowledge is
-- sound. No temporary tables (no TEMP-privilege dependency); the jsonb input
-- is scanned inline. Returns counts for caller logging.
create or replace function public.ingest_bp_batch(
  p_enrolment_ref uuid,
  p_rows          jsonb
) returns table (inserted int, duplicates int)
language plpgsql security invoker
set search_path = public, pg_temp
as $$
declare
  v_patient uuid;
  v_start   timestamptz;
  v_total   int;
  v_ins     int;
begin
  -- Server-side binding: the enrolment must belong to the caller.
  select e.patient_id, e.program_start into v_patient, v_start
    from public.enrolments e
   where e.id = p_enrolment_ref and e.auth_user_id = auth.uid();
  if v_patient is null then
    raise exception 'ENROLMENT_NOT_OWNED';
  end if;

  select count(*) into v_total
    from jsonb_to_recordset(p_rows) as r(client_uuid uuid);
  if v_total = 0 then
    return query select 0, 0; return;      -- zero-row batch fast path
  end if;

  -- Structural validation (never clinical). Any failure aborts the batch.
  if exists (
    select 1 from jsonb_to_recordset(p_rows) as r(
      client_uuid uuid, source_kind text, systolic numeric, diastolic numeric,
      taken_at timestamptz, tz_offset_min smallint, source_bundle_id text,
      source_name text, device_model text, received_at timestamptz)
    where r.client_uuid is null
       or r.source_kind not in ('healthkit','manual')
       or r.systolic is null or r.diastolic is null
       or r.taken_at is null or r.taken_at < v_start
       or (r.source_kind = 'healthkit'
           and (r.source_bundle_id is null or r.source_name is null))
       or (r.source_kind = 'manual'
           and (r.source_bundle_id is not null or r.source_name is not null)))
  then
    raise exception 'STRUCTURAL_VALIDATION_FAILED';
  end if;

  with ins as (
    insert into public.observations
      (patient_id, client_uuid, source_kind, systolic, diastolic,
       taken_at, tz_offset_min, source_bundle_id, source_name,
       device_model, received_at)
    select v_patient, r.client_uuid, r.source_kind, r.systolic, r.diastolic,
           r.taken_at, r.tz_offset_min, r.source_bundle_id, r.source_name,
           r.device_model, r.received_at
      from jsonb_to_recordset(p_rows) as r(
        client_uuid uuid, source_kind text, systolic numeric,
        diastolic numeric, taken_at timestamptz, tz_offset_min smallint,
        source_bundle_id text, source_name text, device_model text,
        received_at timestamptz)
    on conflict (patient_id, client_uuid) do nothing
    returning 1)
  select count(*) into v_ins from ins;

  -- Layer-2 canonicalisation over the padded neighbourhood (§8.2),
  -- computed from PERSISTED rows (replay-safe).
  perform public.canonicalise_bp(
    v_patient,
    (select min(r.taken_at) from jsonb_to_recordset(p_rows)
       as r(taken_at timestamptz)) - interval '3 minutes',
    (select max(r.taken_at) from jsonb_to_recordset(p_rows)
       as r(taken_at timestamptz)) + interval '3 minutes');

  return query select v_ins, v_total - v_ins;
end $$;


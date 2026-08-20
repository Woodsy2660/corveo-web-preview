-- =============================== 003_canonicalise_bp.sql
-- SECURITY DEFINER — deliberately, under the ship-gate-16 carve-out (B3):
-- pinned search_path, schema-qualified objects, internal ownership guard,
-- explicit grants. DEFINER is required because clients hold NO update
-- privilege on observations (by design), yet canonicalisation must set
-- superseded_by. Deterministic, idempotent, reversible (§8.2).
create or replace function public.canonicalise_bp(
  p_patient uuid, p_from timestamptz, p_to timestamptz
) returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare r record; v_canon_id bigint; v_canon_at timestamptz;
        v_canon_s numeric; v_canon_d numeric;
begin
  -- Ownership guard: direct client calls may only touch the caller's data.
  if not exists (select 1 from public.enrolments e
                  where e.patient_id = p_patient
                    and e.auth_user_id = auth.uid()) then
    raise exception 'CANONICALISE_NOT_OWNED';
  end if;

  update public.observations
     set superseded_by = null
   where patient_id = p_patient and obs_type = 'blood_pressure'
     and taken_at between p_from and p_to;

  v_canon_id := null;
  for r in
    select id, systolic, diastolic, taken_at
      from public.observations
     where patient_id = p_patient and obs_type = 'blood_pressure'
       and deleted_at is null
       and taken_at between p_from and p_to
     order by systolic, diastolic,                    -- value groups together
              (source_kind <> 'healthkit'),           -- healthkit first
              ingested_at, id, client_uuid            -- total order [R25]
  loop
    if v_canon_id is not null
       and r.systolic = v_canon_s and r.diastolic = v_canon_d
       and abs(extract(epoch from (r.taken_at - v_canon_at))) <= 180
    then
      update public.observations
         set superseded_by = v_canon_id where id = r.id;
    else
      v_canon_id := r.id; v_canon_at := r.taken_at;   -- new cluster anchor
      v_canon_s  := r.systolic; v_canon_d := r.diastolic;
    end if;
  end loop;
end $$;


-- 05 - RLS negative: another patient's rows are neither selectable nor
-- insertable by this session.
begin;
-- Seed a row for patient B as the privileged session role. A table owner
-- bypasses RLS unless FORCE ROW LEVEL SECURITY is set, which is what makes
-- this seed possible and is itself worth knowing.
insert into public.observations
  (patient_id, client_uuid, source_kind, systolic, diastolic, taken_at,
   source_bundle_id, source_name)
values ('22222222-2222-4222-8222-222222222222',
        '0a000005-0000-4000-8000-0000000000b1','healthkit',2001,2002,
        '2026-06-01T00:00:00Z','dev.lucab.bpwriter','BP Writer');

select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_n int; v_blocked boolean := false;
begin
  select count(*) into v_n from public.observations
   where client_uuid = '0a000005-0000-4000-8000-0000000000b1';
  if v_n <> 0 then
    raise exception 'FAIL 05: patient B row is visible to patient A (got % rows)', v_n;
  end if;

  begin
    insert into public.observations
      (patient_id, client_uuid, source_kind, systolic, diastolic, taken_at,
       source_bundle_id, source_name)
    values ('22222222-2222-4222-8222-222222222222',
            '0a000005-0000-4000-8000-0000000000b2','healthkit',2001,2002,
            '2026-06-01T00:02:00Z','dev.lucab.bpwriter','BP Writer');
  exception when insufficient_privilege then
    v_blocked := true;
  end;

  if not v_blocked then
    raise exception 'FAIL 05: insert against a foreign patient_id was PERMITTED';
  end if;
  raise notice 'PASS 05 - foreign rows blocked on both select and insert';
end $$;
rollback;

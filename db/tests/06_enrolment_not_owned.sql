-- 06 - ENROLMENT_NOT_OWNED on a foreign enrolmentRef.
-- The server-side binding: the caller cannot ingest against someone else's
-- enrolment even though the RPC takes the ref as a parameter. This is the
-- reason the RPC can stay SECURITY INVOKER (ship-gate 16).
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_guarded boolean := false; v_n int;
begin
  begin
    perform public.ingest_bp_batch(
      'eeeeeeee-2222-4222-8222-eeeeeeeeeeee'::uuid,     -- enrolment B, not ours
      jsonb_build_array(jsonb_build_object(
        'client_uuid','0a000006-0000-4000-8000-000000000001',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:00:00Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null)));
  exception when others then
    if sqlerrm like '%ENROLMENT_NOT_OWNED%' then
      v_guarded := true;
    else
      raise exception 'FAIL 06: unexpected error: %', sqlerrm;
    end if;
  end;

  if not v_guarded then
    raise exception 'FAIL 06: ingest against a foreign enrolmentRef was PERMITTED';
  end if;

  select count(*) into v_n from public.observations
   where client_uuid = '0a000006-0000-4000-8000-000000000001';
  if v_n <> 0 then
    raise exception 'FAIL 06: % row(s) landed despite the rejection', v_n;
  end if;
  raise notice 'PASS 06 - foreign enrolmentRef rejected, nothing written';
end $$;
rollback;

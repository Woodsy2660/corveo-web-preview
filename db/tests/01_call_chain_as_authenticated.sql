-- 01 - Full call chain as role `authenticated` succeeds end to end (B3).
-- Exercises, in order: enrolments select policy (migration 000) ->
-- ingest_bp_batch EXECUTE grant -> observations insert policy ->
-- canonicalise_bp EXECUTE grant (checked against the CALLING role even from
-- inside the invoker function, B3) -> DEFINER update. Any broken link in that
-- chain fails here rather than in the field.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_ins int; v_dup int;
begin
  select inserted, duplicates into v_ins, v_dup
  from public.ingest_bp_batch(
    'eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid,
    jsonb_build_array(jsonb_build_object(
      'client_uuid','0a000001-0000-4000-8000-000000000001',
      'source_kind','healthkit',
      'systolic',1001,'diastolic',1002,
      'taken_at','2026-06-01T00:00:00Z',
      'tz_offset_min',600,
      'source_bundle_id','dev.lucab.bpwriter',
      'source_name','BP Writer',
      'device_model',null,
      'received_at','2026-06-01T00:00:05Z')));

  if v_ins <> 1 or v_dup <> 0 then
    raise exception 'FAIL 01: expected (inserted=1, duplicates=0), got (%,%)',
                    v_ins, v_dup;
  end if;
  raise notice 'PASS 01 - call chain green as authenticated';
end $$;
rollback;

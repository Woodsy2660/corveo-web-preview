-- 08 - Uniqueness replay: duplicates counted, zero new rows.
-- This is Layer 1 (§8.1) and it is the entire correctness basis for the
-- replay-generous fetch path and for M5/M8 (crash between server success and
-- acknowledge). If this test fails, acknowledged-items-reappearing stops
-- being harmless.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_ins int; v_dup int; v_n int;
  v_batch jsonb := jsonb_build_array(jsonb_build_object(
    'client_uuid','0a000008-0000-4000-8000-000000000001',
    'source_kind','healthkit','systolic',1001,'diastolic',1002,
    'taken_at','2026-06-01T00:00:00Z','tz_offset_min',null,
    'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
    'device_model',null,'received_at',null));
begin
  select inserted, duplicates into v_ins, v_dup
  from public.ingest_bp_batch('eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid, v_batch);
  if v_ins <> 1 or v_dup <> 0 then
    raise exception 'FAIL 08: first pass expected (1,0), got (%,%)', v_ins, v_dup;
  end if;

  select inserted, duplicates into v_ins, v_dup
  from public.ingest_bp_batch('eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid, v_batch);
  if v_ins <> 0 or v_dup <> 1 then
    raise exception 'FAIL 08: replay expected (0,1), got (%,%)', v_ins, v_dup;
  end if;

  select count(*) into v_n from public.observations
   where client_uuid = '0a000008-0000-4000-8000-000000000001';
  if v_n <> 1 then
    raise exception 'FAIL 08: expected exactly 1 persisted row, got %', v_n;
  end if;
  raise notice 'PASS 08 - replay absorbed by the uniqueness constraint';
end $$;
rollback;

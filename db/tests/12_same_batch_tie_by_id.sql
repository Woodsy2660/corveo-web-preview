-- 12 - T8c: two healthkit candidates in ONE RPC. now() is transaction-stable
-- in PostgreSQL [R25], so both rows share ingested_at and the preference
-- order must fall through to id. This test asserts the tie actually exists
-- before asserting how it is broken - otherwise it would pass for the wrong
-- reason on any build where ingested_at happened to differ.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_1 bigint; v_2 bigint; v_1_ing timestamptz; v_2_ing timestamptz;
        v_1_sup bigint; v_2_sup bigint;
        v_lo bigint; v_hi bigint; v_lo_sup bigint; v_hi_sup bigint;
begin
  perform public.ingest_bp_batch(
    'eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid,
    jsonb_build_array(
      jsonb_build_object('client_uuid','0a000012-0000-4000-8000-000000000001',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:00:00Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null),
      jsonb_build_object('client_uuid','0a000012-0000-4000-8000-000000000002',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:01:00Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null)));

  select id, ingested_at, superseded_by into v_1, v_1_ing, v_1_sup
    from public.observations where client_uuid = '0a000012-0000-4000-8000-000000000001';
  select id, ingested_at, superseded_by into v_2, v_2_ing, v_2_sup
    from public.observations where client_uuid = '0a000012-0000-4000-8000-000000000002';

  if v_1_ing <> v_2_ing then
    raise exception 'FAIL 12 (PRECONDITION): same-batch rows have different ingested_at (% vs %) - the id tie-break is not being exercised', v_1_ing, v_2_ing;
  end if;

  if v_1 < v_2 then v_lo := v_1; v_lo_sup := v_1_sup; v_hi := v_2; v_hi_sup := v_2_sup;
                else v_lo := v_2; v_lo_sup := v_2_sup; v_hi := v_1; v_hi_sup := v_1_sup;
  end if;

  if v_lo_sup is not null then
    raise exception 'FAIL 12: smaller id % is not canonical (superseded_by=%)', v_lo, v_lo_sup;
  end if;
  if v_hi_sup is distinct from v_lo then
    raise exception 'FAIL 12: larger id % has superseded_by=%, expected %', v_hi, v_hi_sup, v_lo;
  end if;
  raise notice 'PASS 12 - ingested_at tie broken deterministically by id';
end $$;
rollback;

-- 13 - Replay of an already-persisted batch converges to the IDENTICAL
-- canonical set.
-- The recompute clears and re-elects superseded_by over the neighbourhood on
-- every ingest, operating on persisted rows. If it were not idempotent, every
-- crash-replay (M5/M8) would churn the display set.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_before text[]; v_after text[]; v_ins int; v_dup int;
  v_batch jsonb := jsonb_build_array(
    jsonb_build_object('client_uuid','0a000013-0000-4000-8000-00000000000a',
      'source_kind','healthkit','systolic',1001,'diastolic',1002,
      'taken_at','2026-06-01T00:00:00Z','tz_offset_min',null,
      'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
      'device_model',null,'received_at',null),
    jsonb_build_object('client_uuid','0a000013-0000-4000-8000-00000000000b',
      'source_kind','healthkit','systolic',1001,'diastolic',1002,
      'taken_at','2026-06-01T00:02:50Z','tz_offset_min',null,
      'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
      'device_model',null,'received_at',null),
    jsonb_build_object('client_uuid','0a000013-0000-4000-8000-00000000000c',
      'source_kind','healthkit','systolic',1001,'diastolic',1002,
      'taken_at','2026-06-01T00:05:40Z','tz_offset_min',null,
      'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
      'device_model',null,'received_at',null));
begin
  perform public.ingest_bp_batch('eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid, v_batch);

  select array_agg(id::text || '->' || coalesce(superseded_by::text,'canonical')
                   order by id)
    into v_before
    from public.observations
   where client_uuid::text like '0a000013-%';

  select inserted, duplicates into v_ins, v_dup
  from public.ingest_bp_batch('eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid, v_batch);
  if v_ins <> 0 or v_dup <> 3 then
    raise exception 'FAIL 13: replay expected (0,3), got (%,%)', v_ins, v_dup;
  end if;

  select array_agg(id::text || '->' || coalesce(superseded_by::text,'canonical')
                   order by id)
    into v_after
    from public.observations
   where client_uuid::text like '0a000013-%';

  if v_before is distinct from v_after then
    raise exception 'FAIL 13: canonical set changed on replay. before=% after=%',
                    v_before, v_after;
  end if;
  raise notice 'PASS 13 - replay is idempotent, canonical set unchanged';
end $$;
rollback;

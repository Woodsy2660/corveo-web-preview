-- 03 - Canonicalisation VISIBLY updates superseded_by.
-- B3's second failure mode: with no UPDATE policy on observations the
-- canonicalisation UPDATE silently matched zero rows under RLS. No
-- count-based or error-based assertion would have caught that, so this test
-- reads the column back and fails on NULL.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

-- Deliberately order-agnostic: which of the two rows wins is test 12's
-- subject. All this test asserts is that ONE row was demoted and that it
-- points at the OTHER - i.e. that the UPDATE reached disk at all.
do $$
declare v_1 bigint; v_2 bigint; v_1_sup bigint; v_2_sup bigint; v_n int;
begin
  perform public.ingest_bp_batch(
    'eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid,
    jsonb_build_array(
      jsonb_build_object('client_uuid','0a000003-0000-4000-8000-000000000001',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:00:00Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null),
      jsonb_build_object('client_uuid','0a000003-0000-4000-8000-000000000002',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:01:00Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null)));

  select count(*) into v_n from public.observations
   where client_uuid in ('0a000003-0000-4000-8000-000000000001',
                         '0a000003-0000-4000-8000-000000000002');
  if v_n <> 2 then
    raise exception 'FAIL 03: expected 2 RETAINED rows (canonicalisation never deletes), got %', v_n;
  end if;

  select id, superseded_by into v_1, v_1_sup from public.observations
   where client_uuid = '0a000003-0000-4000-8000-000000000001';
  select id, superseded_by into v_2, v_2_sup from public.observations
   where client_uuid = '0a000003-0000-4000-8000-000000000002';

  if v_1_sup is null and v_2_sup is null then
    raise exception 'FAIL 03: neither row was superseded - the canonicalisation UPDATE matched zero rows (DEFINER path or RLS problem, B3)';
  end if;
  if v_1_sup is not null and v_2_sup is not null then
    raise exception 'FAIL 03: both rows superseded (% and %) - no survivor in the cluster', v_1_sup, v_2_sup;
  end if;
  if coalesce(v_1_sup, v_2_sup) <> case when v_1_sup is null then v_1 else v_2 end then
    raise exception 'FAIL 03: superseded_by does not point at the surviving row';
  end if;
  raise notice 'PASS 03 - superseded_by visibly written through the DEFINER path';
end $$;
rollback;

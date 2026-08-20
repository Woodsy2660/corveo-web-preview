-- 10 - T8: Layer-2 preference, manual vs healthkit, same batch.
-- Total order (§8.2): source_kind='healthkit' beats 'manual' -> earliest
-- ingested_at -> smallest id -> smallest client_uuid. Within one batch the
-- healthkit row wins on the first term regardless of insert order, so this
-- test deliberately puts the manual row FIRST in the array to prove the
-- preference is not accidentally arrival-ordered.
-- Both rows are retained; canonicalisation is presentation-level only.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_hk bigint; v_hk_sup bigint; v_man_sup bigint; v_n int;
begin
  perform public.ingest_bp_batch(
    'eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid,
    jsonb_build_array(
      jsonb_build_object('client_uuid','0a000010-0000-4000-8000-000000000001',
        'source_kind','manual','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:00:00Z','tz_offset_min',null,
        'source_bundle_id',null,'source_name',null,
        'device_model',null,'received_at',null),
      jsonb_build_object('client_uuid','0a000010-0000-4000-8000-000000000002',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:01:30Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null)));

  select id, superseded_by into v_hk, v_hk_sup from public.observations
   where client_uuid = '0a000010-0000-4000-8000-000000000002';   -- healthkit
  select superseded_by into v_man_sup from public.observations
   where client_uuid = '0a000010-0000-4000-8000-000000000001';   -- manual

  if v_hk_sup is not null then
    raise exception 'FAIL 10: healthkit row is not canonical (superseded_by=%)', v_hk_sup;
  end if;
  if v_man_sup is distinct from v_hk then
    raise exception 'FAIL 10: manual row superseded_by=%, expected % (the healthkit id)', v_man_sup, v_hk;
  end if;

  select count(*) into v_n from public.observations
   where client_uuid in ('0a000010-0000-4000-8000-000000000001',
                         '0a000010-0000-4000-8000-000000000002');
  if v_n <> 2 then
    raise exception 'FAIL 10: expected both rows retained, got %', v_n;
  end if;
  raise notice 'PASS 10 - healthkit canonical, manual flagged and retained';
end $$;
rollback;

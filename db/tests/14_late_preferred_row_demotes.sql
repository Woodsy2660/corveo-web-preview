-- 14 - A late-arriving PREFERRED row demotes the earlier canonical.
-- Distinct from test 10: there both rows arrive in one batch. Here the manual
-- row is already persisted with an earlier ingested_at and is canonical on its
-- own, and the healthkit row arrives in a later call. The recompute must
-- re-elect from persisted rows, not from "the rows I just inserted".
begin;
-- Persist the manual row first, as the privileged session role, with an
-- explicitly EARLIER ingested_at. now() is transaction-stable, so this cannot
-- be expressed through two RPC calls inside one transaction.
insert into public.observations
  (patient_id, client_uuid, source_kind, systolic, diastolic, taken_at,
   ingested_at)
values ('11111111-1111-4111-8111-111111111111',
        '0a000014-0000-4000-8000-000000000001','manual',1001,1002,
        '2026-06-01T00:00:00Z','2026-06-01T00:00:10Z');

select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_man bigint; v_man_sup bigint; v_hk bigint; v_hk_sup bigint;
begin
  select id, superseded_by into v_man, v_man_sup from public.observations
   where client_uuid = '0a000014-0000-4000-8000-000000000001';
  if v_man_sup is not null then
    raise exception 'FAIL 14 (PRECONDITION): manual row is not canonical before the healthkit row arrives';
  end if;

  perform public.ingest_bp_batch(
    'eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid,
    jsonb_build_array(jsonb_build_object(
      'client_uuid','0a000014-0000-4000-8000-000000000002',
      'source_kind','healthkit','systolic',1001,'diastolic',1002,
      'taken_at','2026-06-01T00:01:00Z','tz_offset_min',null,
      'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
      'device_model',null,'received_at',null)));

  select id, superseded_by into v_hk, v_hk_sup from public.observations
   where client_uuid = '0a000014-0000-4000-8000-000000000002';   -- healthkit
  select superseded_by into v_man_sup from public.observations
   where client_uuid = '0a000014-0000-4000-8000-000000000001';   -- manual

  if v_hk_sup is not null then
    raise exception 'FAIL 14: late healthkit row is not canonical (superseded_by=%)', v_hk_sup;
  end if;
  if v_man_sup is distinct from v_hk then
    raise exception 'FAIL 14: earlier manual canonical was not demoted (superseded_by=%, expected %)', v_man_sup, v_hk;
  end if;
  raise notice 'PASS 14 - late preferred row demotes the earlier canonical';
end $$;
rollback;

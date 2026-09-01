-- 11 - T8b: the three-row chain that closed the non-transitive-cluster
-- objection. Identical values at +0:00 / +2:50 / +5:40.
-- Expected (§8.2): A canonical; B superseded by A (170s <= 180s); C starts a
-- NEW cluster (340s from A's taken_at, outside the window) - NOT chained to B.
--
-- ARRIVAL-ORDER PRECONDITION (open question Q3, db/migrations/README.md):
-- the preference order contains no taken_at term, so the cluster anchor is
-- whichever row sorts first by (healthkit, ingested_at, id, client_uuid).
-- Within one batch that is insert order. This test pins A first and asserts
-- the id ordering explicitly, because if B held the smallest id the outcome
-- would legitimately differ (B canonical, and C would then fall INSIDE B's
-- window and be superseded rather than starting a new cluster).
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_a bigint; v_b bigint; v_c bigint;
        v_a_sup bigint; v_b_sup bigint; v_c_sup bigint; v_n int;
begin
  perform public.ingest_bp_batch(
    'eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid,
    jsonb_build_array(
      jsonb_build_object('client_uuid','0a000011-0000-4000-8000-00000000000a',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:00:00Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null),
      jsonb_build_object('client_uuid','0a000011-0000-4000-8000-00000000000b',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:02:50Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null),
      jsonb_build_object('client_uuid','0a000011-0000-4000-8000-00000000000c',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:05:40Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null)));

  select id, superseded_by into v_a, v_a_sup from public.observations
   where client_uuid = '0a000011-0000-4000-8000-00000000000a';
  select id, superseded_by into v_b, v_b_sup from public.observations
   where client_uuid = '0a000011-0000-4000-8000-00000000000b';
  select id, superseded_by into v_c, v_c_sup from public.observations
   where client_uuid = '0a000011-0000-4000-8000-00000000000c';

  if not (v_a < v_b and v_b < v_c) then
    raise exception 'FAIL 11 (PRECONDITION): ids not in batch order (a=%, b=%, c=%). The T8b expectation is arrival-ordered - see open question Q3.', v_a, v_b, v_c;
  end if;

  if v_a_sup is not null then
    raise exception 'FAIL 11: A is not canonical (superseded_by=%)', v_a_sup;
  end if;
  if v_b_sup is distinct from v_a then
    raise exception 'FAIL 11: B superseded_by=%, expected % (A)', v_b_sup, v_a;
  end if;
  if v_c_sup is not null then
    raise exception 'FAIL 11: C was chained (superseded_by=%) instead of starting a new cluster - the non-transitive chain has regressed', v_c_sup;
  end if;

  select count(*) into v_n from public.observations
   where client_uuid in ('0a000011-0000-4000-8000-00000000000a',
                         '0a000011-0000-4000-8000-00000000000b',
                         '0a000011-0000-4000-8000-00000000000c');
  if v_n <> 3 then
    raise exception 'FAIL 11: expected all 3 rows retained, got %', v_n;
  end if;
  raise notice 'PASS 11 - B superseded by A, C is a new canonical, all 3 retained';
end $$;
rollback;

-- 15 - The display query returns the expected set throughout.
-- The trend view renders from `superseded_by is null and deleted_at is null`
-- (matching index obs_display_ix). After the three-row chain that is exactly
-- A and C. This is the only test whose subject is what the patient actually
-- sees, and it must never grow a value predicate - filtering by magnitude
-- anywhere in this stack is interpretation (§4.1).
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_visible int; v_total int; v_has_a boolean; v_has_c boolean;
begin
  perform public.ingest_bp_batch(
    'eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid,
    jsonb_build_array(
      jsonb_build_object('client_uuid','0a000015-0000-4000-8000-00000000000a',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:00:00Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null),
      jsonb_build_object('client_uuid','0a000015-0000-4000-8000-00000000000b',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:02:50Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null),
      jsonb_build_object('client_uuid','0a000015-0000-4000-8000-00000000000c',
        'source_kind','healthkit','systolic',1001,'diastolic',1002,
        'taken_at','2026-06-01T00:05:40Z','tz_offset_min',null,
        'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
        'device_model',null,'received_at',null)));

  select count(*) into v_total from public.observations
   where client_uuid::text like '0a000015-%';
  if v_total <> 3 then
    raise exception 'FAIL 15: expected 3 retained rows, got %', v_total;
  end if;

  select count(*),
         bool_or(client_uuid::text = '0a000015-0000-4000-8000-00000000000a'),
         bool_or(client_uuid::text = '0a000015-0000-4000-8000-00000000000c')
    into v_visible, v_has_a, v_has_c
    from public.observations
   where client_uuid::text like '0a000015-%'
     and obs_type = 'blood_pressure'
     and superseded_by is null
     and deleted_at is null;

  if v_visible <> 2 or not v_has_a or not v_has_c then
    raise exception 'FAIL 15: display set is % row(s) (A present=%, C present=%), expected exactly A and C', v_visible, v_has_a, v_has_c;
  end if;
  raise notice 'PASS 15 - display query returns exactly the canonical set';
end $$;
rollback;

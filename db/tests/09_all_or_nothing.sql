-- 09 - All-or-nothing: one structurally invalid row rejects the whole batch,
-- zero inserts.
-- This is what makes the client's whole-snapshot acknowledge sound (§12 P4):
-- a success return means every row is inserted-or-duplicate, so acking the
-- entire snapshotId cannot lose a row that silently failed.
-- The invalid row here is source_kind='healthkit' with a null source_bundle_id,
-- which trips the function's own validation. Note Q5 in
-- db/migrations/README.md: a wrong-TYPE value (e.g. a non-UUID client_uuid)
-- raises a cast error inside jsonb_to_recordset instead of
-- STRUCTURAL_VALIDATION_FAILED. Still all-or-nothing, different error code.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_rejected boolean := false; v_n int;
begin
  begin
    perform public.ingest_bp_batch(
      'eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid,
      jsonb_build_array(
        jsonb_build_object('client_uuid','0a000009-0000-4000-8000-00000000000a',
          'source_kind','healthkit','systolic',1001,'diastolic',1002,
          'taken_at','2026-06-01T00:00:00Z','tz_offset_min',null,
          'source_bundle_id','dev.lucab.bpwriter','source_name','BP Writer',
          'device_model',null,'received_at',null),          -- valid
        jsonb_build_object('client_uuid','0a000009-0000-4000-8000-00000000000b',
          'source_kind','healthkit','systolic',1001,'diastolic',1002,
          'taken_at','2026-06-01T00:01:00Z','tz_offset_min',null,
          'source_bundle_id',null,'source_name','BP Writer',
          'device_model',null,'received_at',null)));        -- INVALID
  exception when others then
    if sqlerrm like '%STRUCTURAL_VALIDATION_FAILED%' then
      v_rejected := true;
    else
      raise exception 'FAIL 09: unexpected error: %', sqlerrm;
    end if;
  end;

  if not v_rejected then
    raise exception 'FAIL 09: batch containing an invalid row was ACCEPTED';
  end if;

  select count(*) into v_n from public.observations
   where client_uuid in ('0a000009-0000-4000-8000-00000000000a',
                         '0a000009-0000-4000-8000-00000000000b');
  if v_n <> 0 then
    raise exception 'FAIL 09: % row(s) survived a rejected batch - NOT all-or-nothing, whole-snapshot ack is unsound', v_n;
  end if;
  raise notice 'PASS 09 - invalid row rejects the batch, zero inserts';
end $$;
rollback;

-- 07 - Zero-row batch returns (0,0) via the fast path.
-- Matters because the drain calls the RPC before it knows the queue is empty
-- in some orderings, and because the fast path skips the min/max taken_at
-- subqueries that would otherwise pass NULL bounds to canonicalise_bp.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_ins int; v_dup int;
begin
  select inserted, duplicates into v_ins, v_dup
  from public.ingest_bp_batch('eeeeeeee-1111-4111-8111-eeeeeeeeeeee'::uuid,
                              '[]'::jsonb);
  if v_ins <> 0 or v_dup <> 0 then
    raise exception 'FAIL 07: expected (0,0), got (%,%)', v_ins, v_dup;
  end if;
  raise notice 'PASS 07 - zero-row batch returns (0,0)';
end $$;
rollback;

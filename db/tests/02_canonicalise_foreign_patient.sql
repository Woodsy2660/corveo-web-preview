-- 02 - Direct canonicalise_bp call with a foreign p_patient ->
-- CANONICALISE_NOT_OWNED.
-- This guard is the entire reason it is safe to GRANT EXECUTE on a SECURITY
-- DEFINER function to `authenticated` (B3). If this test ever goes green by
-- returning normally, the grant becomes a privilege-escalation path.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_guarded boolean := false;
begin
  begin
    perform public.canonicalise_bp(
      '22222222-2222-4222-8222-222222222222'::uuid,   -- patient B, not ours
      '2026-01-01T00:00:00Z'::timestamptz,
      '2027-01-01T00:00:00Z'::timestamptz);
  exception when others then
    if sqlerrm like '%CANONICALISE_NOT_OWNED%' then
      v_guarded := true;
    else
      raise exception 'FAIL 02: unexpected error from guarded call: %', sqlerrm;
    end if;
  end;

  if not v_guarded then
    raise exception 'FAIL 02: foreign direct call was PERMITTED - the DEFINER ownership guard is not effective and the EXECUTE grant is unsafe';
  end if;
  raise notice 'PASS 02 - DEFINER ownership guard holds against direct calls';
end $$;
rollback;

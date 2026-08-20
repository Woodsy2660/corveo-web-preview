-- 04 - RLS positive: own rows readable and insertable.
-- Also asserts the table-level GRANT precondition. Migration §13 never issues
-- a grant on public.observations and relies on the project's default
-- privileges for `authenticated` - see open question Q1 in
-- db/migrations/README.md. This test names that dependency out loud so a
-- hardened project fails here with a readable message instead of failing
-- opaquely inside the ingest RPC.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                    'role','authenticated')::text, true);
set local role authenticated;

do $$
declare v_n int;
begin
  if not has_table_privilege('authenticated','public.observations','SELECT')
  or not has_table_privilege('authenticated','public.observations','INSERT') then
    raise exception 'FAIL 04 (PRECONDITION): role authenticated lacks SELECT/INSERT on public.observations. Migration 001 grants neither and relies on project default privileges - see open question Q1.';
  end if;

  insert into public.observations
    (patient_id, client_uuid, source_kind, systolic, diastolic, taken_at,
     source_bundle_id, source_name)
  values ('11111111-1111-4111-8111-111111111111',
          '0a000004-0000-4000-8000-000000000001','healthkit',1001,1002,
          '2026-06-01T00:00:00Z','dev.lucab.bpwriter','BP Writer');

  select count(*) into v_n from public.observations
   where client_uuid = '0a000004-0000-4000-8000-000000000001';
  if v_n <> 1 then
    raise exception 'FAIL 04: own row not readable back (got %)', v_n;
  end if;
  raise notice 'PASS 04 - own rows insertable and readable under RLS';
end $$;
rollback;

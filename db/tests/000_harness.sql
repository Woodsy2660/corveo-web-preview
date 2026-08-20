-- =============================== 000_harness.sql
-- Test harness for the §13 migration. Run ONCE before the numbered tests.
-- Seeds two patients / two enrolments and COMMITS them; every numbered test
-- runs inside its own begin/rollback so no observation rows survive a run.
--
-- SYNTHETIC-ONLY (§1.1, §4.2): fixture systolic/diastolic values are
-- structurally arbitrary non-clinical numerics. They are not blood-pressure
-- values and must never be replaced with plausible ones. Every assertion in
-- this suite depends on equality, ordering, count or Δt — never magnitude.
-- Their arbitrariness doubles as proof that no range validation exists
-- anywhere in the schema (range checks = interpretation, §4.1).
--
-- auth.uid() EMULATION: Supabase resolves auth.uid() from the
-- 'request.jwt.claims' GUC. Every test sets it, then `set local role
-- authenticated`. If this project's auth.uid() reads a different source,
-- adjust the two lines in each test's "become <user>" block and nowhere else.
-- The session role must be a member of `authenticated` (true for `postgres`).

-- D3 SHIM: §13's 001 FK-references public.patients(id), which no section of
-- the guide specifies (see db/migrations/README.md, open question Q2).
-- These creates are no-ops in the client environment, where both tables
-- already exist. They exist so the suite is runnable on a scratch database.
do $$
begin
  if to_regclass('public.patients') is null then
    create table public.patients (id uuid primary key);
    raise notice 'HARNESS: created shim public.patients (absent in this DB)';
  end if;
  if to_regclass('public.enrolments') is null then
    create table public.enrolments (
      id            uuid primary key,
      patient_id    uuid        not null,
      auth_user_id  uuid        not null,
      program_start timestamptz not null,
      status        text);
    raise notice 'HARNESS: created shim public.enrolments (absent in this DB)';
  end if;
end $$;

insert into public.patients (id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222')
on conflict (id) do nothing;

insert into public.enrolments (id, patient_id, auth_user_id, program_start, status)
values
  ('eeeeeeee-1111-4111-8111-eeeeeeeeeeee',
   '11111111-1111-4111-8111-111111111111',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   '2026-01-01T00:00:00Z', 'active'),
  ('eeeeeeee-2222-4222-8222-eeeeeeeeeeee',
   '22222222-2222-4222-8222-222222222222',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '2026-01-01T00:00:00Z', 'active')
on conflict (id) do nothing;

do $$ begin raise notice 'HARNESS READY'; end $$;

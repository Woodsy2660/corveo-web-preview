-- =============================== 000_prerequisites.sql
-- The INVOKER ingest function must be able to read the caller's own
-- enrolment row. If the enrolments table already carries an equivalent
-- select-own policy, verify it and skip (D3).
alter table public.enrolments enable row level security;
create policy enr_select_own on public.enrolments for select
  using (auth_user_id = auth.uid());
grant select on public.enrolments to authenticated;


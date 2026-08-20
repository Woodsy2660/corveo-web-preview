-- =============================== 001_bp_observations.sql
create table if not exists public.observations (
  id               bigint generated always as identity primary key,
  patient_id       uuid        not null references public.patients(id),
  client_uuid      uuid        not null,   -- HK correlation UUID | manual UUIDv4
  source_kind      text        not null
                     check (source_kind in ('healthkit','manual')),
  obs_type         text        not null default 'blood_pressure'
                     check (obs_type = 'blood_pressure'),   -- server-fixed
  systolic         numeric     not null,   -- structural only; NO range checks
  diastolic        numeric     not null,   --   (range = interpretation)
  unit             text        not null default 'mmHg' check (unit = 'mmHg'),
  taken_at         timestamptz not null,
  tz_offset_min    smallint,               -- nullable; HK metadata only
  source_bundle_id text,
  source_name      text,
  device_model     text,
  received_at      timestamptz,            -- client-assigned; informational
  ingested_at      timestamptz not null default now(),
  superseded_by    bigint references public.observations(id),
  deleted_at       timestamptz,            -- reserved for the reconciliation
                                           --   fast-follow (§8.3)
  constraint obs_patient_clientuuid_uniq unique (patient_id, client_uuid),
  constraint obs_source_fields_chk check (
    (source_kind = 'healthkit' and source_bundle_id is not null
                               and source_name is not null)
    or
    (source_kind = 'manual'    and source_bundle_id is null
                               and source_name is null)
  )
);
create index if not exists obs_display_ix
  on public.observations (patient_id, obs_type, taken_at desc)
  where superseded_by is null and deleted_at is null;
create index if not exists obs_candidate_ix
  on public.observations (patient_id, obs_type, systolic, diastolic, taken_at)
  where deleted_at is null;

alter table public.observations enable row level security;
create policy obs_select_own on public.observations for select
  using (patient_id in (select e.patient_id from public.enrolments e
                        where e.auth_user_id = auth.uid()));
create policy obs_insert_own on public.observations for insert
  with check (patient_id in (select e.patient_id from public.enrolments e
                             where e.auth_user_id = auth.uid()));
-- Deliberately NO update/delete policies and NO update grant to clients:
-- superseded_by is mutated only by canonicalise_bp (DEFINER, guarded below);
-- deleted_at only by the reconciliation fast-follow's own guarded function.


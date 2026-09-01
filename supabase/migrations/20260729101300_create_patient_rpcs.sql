-- Migration: Patient write-path RPCs
-- Purpose: Enrolment, consent, patient-initiated soft delete, account deletion
-- Ref: docs/migration-plan-v0.2.md §14
--
-- v0.1 described a database the app could not use. These four functions are
-- the missing write paths. All are security definer with pinned search_path.

--------------------------------------------------------------------------------
-- enrol_patient
-- Called at signup. The only moment the Apple display name is available.
--------------------------------------------------------------------------------

create or replace function public.enrol_patient(
  p_display_name text,
  p_adult_attested boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_id uuid := auth.uid();
  v_user_id uuid;
begin
  if v_auth_id is null then
    raise exception 'UNAUTHORIZED' using errcode = '28000';
  end if;

  if p_adult_attested is not true then
    raise exception 'ADULT_ATTESTATION_REQUIRED' using errcode = '22023';
  end if;

  select au.id
    into v_user_id
    from public.app_user au
   where au.auth_user_id = v_auth_id
     and au.identity_deleted_at is null;

  if v_user_id is null then
    insert into public.app_user (
      auth_user_id, display_name, adult_attested, adult_attested_at
    ) values (
      v_auth_id, p_display_name, true, now()
    )
    returning id into v_user_id;

    insert into public.audit_event (
      user_id, actor_type, actor_id, event_type, target_table, target_id
    ) values (
      v_user_id, 'patient', v_user_id, 'patient_enrolled', 'app_user', v_user_id
    );

    insert into public.program_progress (user_id)
    values (v_user_id);
  else
    update public.app_user
       set display_name = coalesce(p_display_name, display_name),
           adult_attested = true,
           adult_attested_at = coalesce(adult_attested_at, now())
     where id = v_user_id;
  end if;

  return v_user_id;
end;
$$;

comment on function public.enrol_patient(text, boolean) is
  'Creates or updates the app_user row for auth.uid(). Rejects adult_attested = false. Writes patient_enrolled.';

--------------------------------------------------------------------------------
-- record_consent / withdraw_consent
-- Append-only. Never updates an existing row.
--------------------------------------------------------------------------------

create or replace function public.record_consent(
  p_version text,
  p_document_hash text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := public.get_app_user_id();
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using errcode = '28000';
  end if;

  if coalesce(p_version, '') = '' or coalesce(p_document_hash, '') = '' then
    raise exception 'malformed payload: consent' using errcode = '22023';
  end if;

  insert into public.consent_event (
    user_id, event_type, version, document_hash, method
  ) values (
    v_user_id, 'granted', p_version, p_document_hash, 'in_app_checkbox'
  )
  returning id into v_id;

  insert into public.audit_event (
    user_id, actor_type, actor_id, event_type, target_table, target_id
  ) values (
    v_user_id, 'patient', v_user_id, 'consent_granted', 'consent_event', v_id
  );
end;
$$;

comment on function public.record_consent(text, text) is
  'Inserts a granted consent_event. Never updates. Writes consent_granted.';

create or replace function public.withdraw_consent()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := public.get_app_user_id();
  v_version text;
  v_hash text;
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using errcode = '28000';
  end if;

  select ce.version, ce.document_hash
    into v_version, v_hash
    from public.consent_event ce
   where ce.user_id = v_user_id
   order by ce.occurred_at desc, ce.id desc
   limit 1;

  if v_version is null then
    raise exception 'NO_CONSENT_TO_WITHDRAW' using errcode = 'P0001';
  end if;

  insert into public.consent_event (
    user_id, event_type, version, document_hash, method
  ) values (
    v_user_id, 'withdrawn', v_version, v_hash, 'in_app_checkbox'
  )
  returning id into v_id;

  insert into public.audit_event (
    user_id, actor_type, actor_id, event_type, target_table, target_id
  ) values (
    v_user_id, 'patient', v_user_id, 'consent_withdrawn', 'consent_event', v_id
  );
end;
$$;

comment on function public.withdraw_consent() is
  'Inserts a withdrawn consent_event copying version and hash from the latest event. Writes consent_withdrawn.';

--------------------------------------------------------------------------------
-- soft_delete_observation
-- Patient-facing "remove from my record" (Deliverable 12).
--------------------------------------------------------------------------------

create or replace function public.soft_delete_observation(p_observation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := public.get_app_user_id();
  v_rowcount integer;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using errcode = '28000';
  end if;

  update public.observation o
     set deleted_at = now(),
         deleted_reason = 'patient_removed'
   where o.id = p_observation_id
     and o.user_id = v_user_id
     and o.deleted_at is null;

  get diagnostics v_rowcount = row_count;
  if v_rowcount = 0 then
    raise exception 'NOT_FOUND' using errcode = 'P0002';
  end if;

  insert into public.audit_event (
    user_id, actor_type, actor_id, event_type, target_table, target_id, detail
  ) values (
    v_user_id, 'patient', v_user_id, 'observation_soft_deleted', 'observation',
    p_observation_id,
    jsonb_build_object('reason', 'patient_removed')
  );
end;
$$;

comment on function public.soft_delete_observation(uuid) is
  'Soft-deletes a row owned by the caller with deleted_reason = patient_removed. Writes observation_soft_deleted.';

--------------------------------------------------------------------------------
-- delete_account
-- App Store Guideline 5.1.1(v). Clinical rows are retained under A.12.6.
--------------------------------------------------------------------------------

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_id uuid := auth.uid();
  v_user_id uuid;
begin
  if v_auth_id is null then
    raise exception 'UNAUTHORIZED' using errcode = '28000';
  end if;

  v_user_id := public.get_app_user_id();

  if v_user_id is not null then
    update public.app_user
       set auth_user_id = null,
           identity_deleted_at = now(),
           display_name = null
     where id = v_user_id;

    insert into public.audit_event (
      user_id, actor_type, actor_id, event_type, target_table, target_id
    ) values (
      v_user_id, 'patient', v_user_id, 'identity_deleted', 'app_user', v_user_id
    );
  end if;

  delete from auth.users where id = v_auth_id;
end;
$$;

comment on function public.delete_account() is
  'Nulls auth_user_id, sets identity_deleted_at, clears display_name, writes identity_deleted, then deletes auth.users. Clinical rows are retained.';

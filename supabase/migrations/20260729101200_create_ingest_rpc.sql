-- Migration: ingest_observations RPC
-- Purpose: Single write path for HealthKit sync and manual entry
-- Ref: docs/02-data-model-and-api.md §4.2; docs/migration-plan-v0.2.md §13
--
-- Idempotent on (user_id, source_system, source_uuid).
-- CONSENT_REQUIRED fails the whole call (403), not a per-item rejection.
-- Copies is_panel from observation_definition so the parent CHECK holds.
-- Deletion matches parent OR component source_uuid.

create or replace function public.ingest_observations(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_source_type text;
  v_obs jsonb;
  v_comp jsonb;
  v_obs_id uuid;
  v_def public.observation_definition%rowtype;
  v_comp_def public.observation_definition%rowtype;
  v_inserted integer := 0;
  v_duplicates integer := 0;
  v_soft_deleted integer := 0;
  v_rejected jsonb := '[]'::jsonb;
  v_systolic numeric;
  v_diastolic numeric;
  v_del_uuid text;
  v_effective timestamptz;
  v_reject_reason text;
  v_reject_detail text;
  v_missing text;
  v_rowcount integer;
  v_qty numeric;
begin
  v_user_id := public.get_app_user_id();
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using errcode = '28000';
  end if;

  if not public.has_active_consent(v_user_id) then
    raise exception 'CONSENT_REQUIRED' using errcode = '42501';
  end if;

  if payload is null or jsonb_typeof(payload) <> 'object' then
    raise exception 'malformed payload' using errcode = '22023';
  end if;

  v_source_type := payload->>'source_type';
  if v_source_type is null or v_source_type not in ('healthkit', 'manual') then
    raise exception 'malformed payload: source_type' using errcode = '22023';
  end if;

  if payload ? 'observations'
     and jsonb_typeof(payload->'observations') <> 'array' then
    raise exception 'malformed payload: observations' using errcode = '22023';
  end if;

  if payload ? 'deleted_source_uuids'
     and jsonb_typeof(payload->'deleted_source_uuids') <> 'array' then
    raise exception 'malformed payload: deleted_source_uuids' using errcode = '22023';
  end if;

  for v_obs in
    select value from jsonb_array_elements(coalesce(payload->'observations', '[]'::jsonb))
  loop
    v_reject_reason := null;
    v_reject_detail := null;
    v_obs_id := null;
    v_systolic := null;
    v_diastolic := null;
    v_missing := null;

    select * into v_def
      from public.observation_definition d
     where d.code = v_obs->>'code';

    if v_def is null then
      v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
        'source_uuid', coalesce(v_obs->>'source_uuid', ''),
        'reason', 'UNKNOWN_CODE',
        'detail', coalesce(v_obs->>'code', '')
      ));
      continue;
    end if;

    if coalesce(v_obs->>'source_uuid', '') = ''
       or coalesce(v_obs->>'source_system', '') = '' then
      v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
        'source_uuid', coalesce(v_obs->>'source_uuid', ''),
        'reason', 'MISSING_COMPONENT',
        'detail', 'source_uuid and source_system are required'
      ));
      continue;
    end if;

    begin
      v_effective := (v_obs->>'effective_time')::timestamptz;
    exception
      when invalid_datetime_format or datetime_field_overflow then
        v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
          'source_uuid', v_obs->>'source_uuid',
          'reason', 'MALFORMED_TIMESTAMP',
          'detail', coalesce(v_obs->>'effective_time', '')
        ));
        continue;
    end;

    if v_effective is null then
      v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
        'source_uuid', v_obs->>'source_uuid',
        'reason', 'MALFORMED_TIMESTAMP',
        'detail', 'effective_time is required'
      ));
      continue;
    end if;

    if v_def.is_panel then
      if coalesce(jsonb_typeof(v_obs->'components'), 'null') <> 'array' then
        v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
          'source_uuid', v_obs->>'source_uuid',
          'reason', 'MISSING_COMPONENT',
          'detail', v_def.code
        ));
        continue;
      end if;

      select string_agg(d.code, ',' order by d.sort_order)
        into v_missing
        from public.observation_definition d
       where d.parent_code = v_def.code
         and not exists (
           select 1
             from jsonb_array_elements(v_obs->'components') c
            where c->>'code' = d.code
         );

      if v_missing is not null then
        v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
          'source_uuid', v_obs->>'source_uuid',
          'reason', 'MISSING_COMPONENT',
          'detail', v_missing
        ));
        continue;
      end if;

      for v_comp in select value from jsonb_array_elements(v_obs->'components')
      loop
        select * into v_comp_def
          from public.observation_definition d
         where d.code = v_comp->>'code';

        if v_comp_def is null or v_comp_def.parent_code is distinct from v_def.code then
          v_reject_reason := 'UNKNOWN_CODE';
          v_reject_detail := coalesce(v_comp->>'code', '');
          exit;
        end if;

        if coalesce(v_comp->>'source_uuid', '') = '' then
          v_reject_reason := 'MISSING_COMPONENT';
          v_reject_detail := format('%s source_uuid', v_comp_def.code);
          exit;
        end if;

        if v_comp_def.expected_unit is not null
           and v_comp->>'value_unit' is distinct from v_comp_def.expected_unit then
          v_reject_reason := 'UNIT_MISMATCH';
          v_reject_detail := format(
            '%s expected %s got %s',
            v_comp_def.code, v_comp_def.expected_unit, coalesce(v_comp->>'value_unit', '')
          );
          exit;
        end if;

        begin
          v_qty := (v_comp->>'value_quantity')::numeric;
        exception when others then
          v_reject_reason := 'VALUE_OUT_OF_BOUNDS';
          v_reject_detail := format('%s = %s', v_comp_def.code, coalesce(v_comp->>'value_quantity', ''));
          exit;
        end;

        if v_comp_def.min_value is not null and v_qty < v_comp_def.min_value then
          v_reject_reason := 'VALUE_OUT_OF_BOUNDS';
          v_reject_detail := format('%s = %s', v_comp_def.code, v_qty);
          exit;
        end if;

        if v_comp_def.max_value is not null and v_qty > v_comp_def.max_value then
          v_reject_reason := 'VALUE_OUT_OF_BOUNDS';
          v_reject_detail := format('%s = %s', v_comp_def.code, v_qty);
          exit;
        end if;

        if v_comp_def.code = '8480-6' then
          v_systolic := v_qty;
        elsif v_comp_def.code = '8462-4' then
          v_diastolic := v_qty;
        end if;
      end loop;

      if v_reject_reason is not null then
        v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
          'source_uuid', v_obs->>'source_uuid',
          'reason', v_reject_reason,
          'detail', v_reject_detail
        ));
        continue;
      end if;

      if v_systolic is not null and v_diastolic is not null
         and v_systolic <= v_diastolic then
        v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
          'source_uuid', v_obs->>'source_uuid',
          'reason', 'SYSTOLIC_NOT_GREATER',
          'detail', format('systolic %s <= diastolic %s', v_systolic, v_diastolic)
        ));
        continue;
      end if;
    else
      -- Single-value observation (future modules). V1 has no seeded non-panels.
      if v_def.expected_unit is not null
         and v_obs->>'value_unit' is distinct from v_def.expected_unit then
        v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
          'source_uuid', v_obs->>'source_uuid',
          'reason', 'UNIT_MISMATCH',
          'detail', format('expected %s got %s', v_def.expected_unit, coalesce(v_obs->>'value_unit', ''))
        ));
        continue;
      end if;

      begin
        v_qty := (v_obs->>'value_quantity')::numeric;
      exception when others then
        v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
          'source_uuid', v_obs->>'source_uuid',
          'reason', 'VALUE_OUT_OF_BOUNDS',
          'detail', coalesce(v_obs->>'value_quantity', '')
        ));
        continue;
      end;

      if v_def.min_value is not null and v_qty < v_def.min_value then
        v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
          'source_uuid', v_obs->>'source_uuid',
          'reason', 'VALUE_OUT_OF_BOUNDS',
          'detail', format('%s = %s', v_def.code, v_qty)
        ));
        continue;
      end if;

      if v_def.max_value is not null and v_qty > v_def.max_value then
        v_rejected := v_rejected || jsonb_build_array(jsonb_build_object(
          'source_uuid', v_obs->>'source_uuid',
          'reason', 'VALUE_OUT_OF_BOUNDS',
          'detail', format('%s = %s', v_def.code, v_qty)
        ));
        continue;
      end if;
    end if;

    insert into public.observation (
      user_id, status, is_panel,
      code_system, code, code_display, code_system_snomed, code_snomed,
      value_quantity, value_unit,
      body_site_system, body_site_code, context,
      effective_time, effective_tz, effective_offset_minutes,
      source_type, source_uuid, source_system, source_name,
      source_device_model, source_user_entered
    ) values (
      v_user_id, 'final', v_def.is_panel,
      v_def.code_system, v_def.code, v_def.code_display,
      v_def.code_system_snomed, v_def.code_snomed,
      case when v_def.is_panel then null else v_qty end,
      case when v_def.is_panel then null else v_obs->>'value_unit' end,
      v_obs->>'body_site_system', v_obs->>'body_site_code',
      coalesce(v_obs->'context', '{}'::jsonb),
      v_effective,
      coalesce(nullif(v_obs->>'effective_tz', ''), 'Australia/Sydney'),
      (v_obs->>'effective_offset_minutes')::integer,
      v_source_type, v_obs->>'source_uuid', v_obs->>'source_system',
      v_obs->>'source_name', v_obs->>'source_device_model',
      coalesce((v_obs->>'source_user_entered')::boolean, false)
    )
    on conflict (user_id, source_system, source_uuid) do nothing
    returning id into v_obs_id;

    if v_obs_id is null then
      v_duplicates := v_duplicates + 1;
      continue;
    end if;

    v_inserted := v_inserted + 1;

    if v_def.is_panel then
      for v_comp in select value from jsonb_array_elements(v_obs->'components')
      loop
        select * into v_comp_def
          from public.observation_definition d
         where d.code = v_comp->>'code';

        insert into public.observation_component (
          observation_id, code_system, code, code_display,
          code_system_snomed, code_snomed,
          value_quantity, value_unit, source_uuid
        ) values (
          v_obs_id,
          v_comp_def.code_system, v_comp_def.code, v_comp_def.code_display,
          v_comp_def.code_system_snomed, v_comp_def.code_snomed,
          (v_comp->>'value_quantity')::numeric, v_comp->>'value_unit',
          v_comp->>'source_uuid'
        );
      end loop;
    end if;
  end loop;

  for v_del_uuid in
    select value from jsonb_array_elements_text(coalesce(payload->'deleted_source_uuids', '[]'::jsonb))
  loop
    update public.observation o
       set deleted_at = now(),
           deleted_reason = 'deleted_in_source'
     where o.user_id = v_user_id
       and o.deleted_at is null
       and (
         o.source_uuid = v_del_uuid
         or exists (
           select 1 from public.observation_component c
            where c.observation_id = o.id
              and c.source_uuid = v_del_uuid
         )
       );

    get diagnostics v_rowcount = row_count;
    v_soft_deleted := v_soft_deleted + v_rowcount;
  end loop;

  if v_inserted > 0 then
    insert into public.audit_event (
      user_id, actor_type, actor_id, event_type, target_table, detail
    ) values (
      v_user_id, 'patient', v_user_id, 'observation_ingested', 'observation',
      jsonb_build_object(
        'inserted', v_inserted,
        'duplicates', v_duplicates,
        'rejected_count', jsonb_array_length(v_rejected),
        'source_type', v_source_type
      )
    );
  end if;

  if v_soft_deleted > 0 then
    insert into public.audit_event (
      user_id, actor_type, actor_id, event_type, target_table, detail
    ) values (
      v_user_id, 'patient', v_user_id, 'observation_soft_deleted', 'observation',
      jsonb_build_object(
        'soft_deleted', v_soft_deleted,
        'reason', 'deleted_in_source'
      )
    );
  end if;

  return jsonb_build_object(
    'inserted', v_inserted,
    'duplicates', v_duplicates,
    'soft_deleted', v_soft_deleted,
    'rejected', v_rejected
  );
end;
$$;

comment on function public.ingest_observations(jsonb) is
  'Single write path for observations. Idempotent. Consent-gated. Validates bounds from observation_definition.';

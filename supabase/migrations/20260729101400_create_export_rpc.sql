-- Migration: export_patient_data RPC
-- Purpose: Patient data export (Deliverable 12)
-- Ref: docs/02-data-model-and-api.md §4.4; docs/migration-plan-v0.2.md §15
--
-- FHIR R4 Bundle assembled in plpgsql. Open item D-06 notes this is the one
-- V1 place an Edge Function would earn its keep; amending A-04 is required
-- before moving it. Until then this is the specified implementation.

create or replace function public.export_patient_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_entries jsonb := '[]'::jsonb;
  v_csv text;
  v_obs record;
  v_comp record;
  v_components jsonb;
  v_fhir_obs jsonb;
  v_sign text;
  v_hours integer;
  v_mins integer;
  v_offset integer;
  v_sys numeric;
  v_dia numeric;
begin
  v_user_id := public.get_app_user_id();
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using errcode = '28000';
  end if;

  v_csv := 'id,effective_time,effective_tz,systolic,diastolic,source_type,source_name,body_site' || chr(10);

  for v_obs in
    select
      o.id,
      o.effective_time,
      o.effective_tz,
      o.effective_offset_minutes,
      o.code,
      o.code_system,
      o.code_display,
      o.code_snomed,
      o.code_system_snomed,
      o.source_type,
      o.source_name,
      o.body_site_code,
      o.status
    from public.observation o
    where o.user_id = v_user_id
      and o.deleted_at is null
      and o.code = '85354-9'
    order by o.effective_time desc
  loop
    v_components := '[]'::jsonb;
    v_sys := null;
    v_dia := null;

    for v_comp in
      select c.*
        from public.observation_component c
       where c.observation_id = v_obs.id
       order by c.code
    loop
      v_components := v_components || jsonb_build_array(
        jsonb_build_object(
          'code', jsonb_build_object(
            'coding', jsonb_build_array(
              jsonb_build_object(
                'system', v_comp.code_system,
                'code', v_comp.code,
                'display', v_comp.code_display
              ),
              jsonb_build_object(
                'system', v_comp.code_system_snomed,
                'code', v_comp.code_snomed
              )
            )
          ),
          'valueQuantity', jsonb_build_object(
            'value', v_comp.value_quantity,
            'unit', 'mmHg',
            'system', 'http://unitsofmeasure.org',
            'code', v_comp.value_unit
          )
        )
      );

      if v_comp.code = '8480-6' then
        v_sys := v_comp.value_quantity;
      elsif v_comp.code = '8462-4' then
        v_dia := v_comp.value_quantity;
      end if;
    end loop;

    v_offset := coalesce(v_obs.effective_offset_minutes, 0);
    if v_offset >= 0 then
      v_sign := '+';
      v_hours := v_offset / 60;
      v_mins := v_offset % 60;
    else
      v_sign := '-';
      v_hours := (-v_offset) / 60;
      v_mins := (-v_offset) % 60;
    end if;

    v_fhir_obs := jsonb_build_object(
      'resourceType', 'Observation',
      'id', v_obs.id,
      'status', v_obs.status,
      'category', jsonb_build_array(
        jsonb_build_object(
          'coding', jsonb_build_array(
            jsonb_build_object(
              'system', 'http://terminology.hl7.org/CodeSystem/observation-category',
              'code', 'vital-signs',
              'display', 'Vital Signs'
            )
          )
        )
      ),
      'code', jsonb_build_object(
        'coding', jsonb_build_array(
          jsonb_build_object(
            'system', v_obs.code_system,
            'code', v_obs.code,
            'display', v_obs.code_display
          ),
          jsonb_build_object(
            'system', v_obs.code_system_snomed,
            'code', v_obs.code_snomed
          )
        )
      ),
      'subject', jsonb_build_object('reference', 'Patient/' || v_user_id),
      'effectiveDateTime',
        to_char(v_obs.effective_time at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS')
        || v_sign
        || lpad(v_hours::text, 2, '0')
        || ':'
        || lpad(v_mins::text, 2, '0'),
      'component', v_components
    );

    if v_obs.body_site_code is not null then
      v_fhir_obs := v_fhir_obs || jsonb_build_object(
        'bodySite', jsonb_build_object(
          'coding', jsonb_build_array(
            jsonb_build_object(
              'system', 'http://snomed.info/sct',
              'code', v_obs.body_site_code
            )
          )
        )
      );
    end if;

    v_entries := v_entries || jsonb_build_array(
      jsonb_build_object(
        'fullUrl', 'urn:uuid:' || v_obs.id,
        'resource', v_fhir_obs
      )
    );

    v_csv := v_csv || format(
      '%s,%s,%s,%s,%s,%s,"%s",%s',
      v_obs.id,
      v_obs.effective_time,
      coalesce(v_obs.effective_tz, ''),
      coalesce(v_sys::text, ''),
      coalesce(v_dia::text, ''),
      v_obs.source_type,
      replace(coalesce(v_obs.source_name, ''), '"', '""'),
      coalesce(v_obs.body_site_code, '')
    ) || chr(10);
  end loop;

  insert into public.audit_event (
    user_id, actor_type, actor_id, event_type, detail
  ) values (
    v_user_id, 'patient', v_user_id, 'export_generated',
    jsonb_build_object('observation_count', jsonb_array_length(v_entries))
  );

  return jsonb_build_object(
    'fhir_bundle', jsonb_build_object(
      'resourceType', 'Bundle',
      'type', 'collection',
      'timestamp', to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'entry', v_entries
    ),
    'csv', v_csv
  );
end;
$$;

comment on function public.export_patient_data() is
  'Exports the patient''s observations as a FHIR R4 Bundle plus CSV. Writes export_generated. Deliverable 12.';

-- =============================== 999_teardown.sql
-- Removes harness fixtures. Observation rows never persist (every test
-- rolls back), but this cleans the two patients/enrolments if the suite was
-- run against a shared scratch database.
delete from public.observations
 where patient_id in ('11111111-1111-4111-8111-111111111111',
                      '22222222-2222-4222-8222-222222222222');
delete from public.enrolments
 where id in ('eeeeeeee-1111-4111-8111-eeeeeeeeeeee',
              'eeeeeeee-2222-4222-8222-eeeeeeeeeeee');
delete from public.patients
 where id in ('11111111-1111-4111-8111-111111111111',
              '22222222-2222-4222-8222-222222222222');
do $$ begin raise notice 'TEARDOWN COMPLETE'; end $$;

-- run_all.sql - psql driver for the §13 test suite.
--   psql "$SUPABASE_NONPROD_URL" -v ON_ERROR_STOP=1 -f db/tests/run_all.sql
-- ON_ERROR_STOP=1 is required: every test signals failure by raising, so
-- without it a red run looks green in the tail of the output.
\set ON_ERROR_STOP on
\echo === harness ===
\i db/tests/000_harness.sql
\echo === B3 privilege chain ===
\i db/tests/01_call_chain_as_authenticated.sql
\i db/tests/02_canonicalise_foreign_patient.sql
\i db/tests/03_canonicalisation_visible.sql
\echo === RLS ===
\i db/tests/04_rls_positive.sql
\i db/tests/05_rls_negative.sql
\i db/tests/06_enrolment_not_owned.sql
\echo === batch semantics ===
\i db/tests/07_zero_row_batch.sql
\i db/tests/08_uniqueness_replay.sql
\i db/tests/09_all_or_nothing.sql
\echo === Layer 2 canonicalisation ===
\i db/tests/10_pref_manual_vs_healthkit.sql
\i db/tests/11_three_row_chain.sql
\i db/tests/12_same_batch_tie_by_id.sql
\i db/tests/13_replay_converges.sql
\i db/tests/14_late_preferred_row_demotes.sql
\i db/tests/15_display_query.sql
\echo === teardown ===
\i db/tests/999_teardown.sql
\echo ALL TESTS COMPLETED - any FAIL would have aborted this run

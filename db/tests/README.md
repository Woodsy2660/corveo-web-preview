# §13 migration test suite — executable checklist

Covers every test named in §13's *"Required SQL tests (delivered with the migration, run in
the client non-prod env at T15)"* paragraph. Runs against the **client-controlled
non-production** Supabase environment (§14 T15). Never against production, never against a
database holding real patient rows.

## Running it

```bash
psql "$SUPABASE_NONPROD_URL" -v ON_ERROR_STOP=1 -f db/tests/run_all.sql
```

`ON_ERROR_STOP=1` is **required**. Every test signals failure by `raise exception`, so
without it a red run scrolls past and the tail still looks green.

Each numbered file is self-contained: `begin` → seed → assert → `rollback`. No observation
rows survive a run. `000_harness.sql` seeds two patients / two enrolments and commits them;
`999_teardown.sql` removes them.

Individual test: `psql "$URL" -v ON_ERROR_STOP=1 -f db/tests/000_harness.sql -f db/tests/11_three_row_chain.sql`

## Two things about this suite that are deliberate

**Fixture values are non-clinical sentinels (`1001`/`1002`, `2001`/`2002`).** No health value
appears in any fixture, per §1.1 and §4.2 — and these are not health values, they are
structural sentinels. Every assertion in the suite depends on equality, ordering, count or
Δt, never on magnitude, so the specific numbers are irrelevant to every result. Their
implausibility is also a free proof that no range validation exists anywhere in the schema —
range checks are interpretation (§4.1), and their absence is a contract requirement, not an
oversight. **Do not "improve" these to realistic values.**

**`auth.uid()` is emulated via the `request.jwt.claims` GUC**, which is how Supabase resolves
it. Each test sets the claim then `set local role authenticated`. If this project resolves
`auth.uid()` differently, change the two-line "become user" block in each test and nothing
else. The session role must be a member of `authenticated` (true for `postgres`).

## Checklist

Fill the Result column during the T15 run and attach to the evidence index.

| # | §13 required test | File | What a failure means | Result |
|---|---|---|---|---|
| 01 | Full call chain **as role `authenticated`** succeeds end to end | `01_call_chain_as_authenticated.sql` | The B3 grant chain is broken somewhere between the enrolments read policy and the DEFINER update | |
| 02 | Direct `canonicalise_bp` with a foreign `p_patient` → `CANONICALISE_NOT_OWNED` | `02_canonicalise_foreign_patient.sql` | The EXECUTE grant on a DEFINER function is a privilege-escalation path | |
| 03 | Canonicalisation **visibly updates** `superseded_by` | `03_canonicalisation_visible.sql` | The UPDATE is matching zero rows under RLS — B3's silent no-op has regressed | |
| 04 | RLS positive: own rows readable/insertable | `04_rls_positive.sql` | Ingest cannot work at all. Check the grant precondition first (Q1) | |
| 05 | RLS negative: other-patient insert/select blocked | `05_rls_negative.sql` | Cross-patient data exposure | |
| 06 | `ENROLMENT_NOT_OWNED` on a foreign `enrolmentRef` | `06_enrolment_not_owned.sql` | The server-side binding is not bound; INVOKER + `auth.uid()` is no longer sufficient | |
| 07 | Zero-row batch returns `(0,0)` | `07_zero_row_batch.sql` | The fast path is gone; NULL bounds reach `canonicalise_bp` | |
| 08 | Uniqueness replay → `duplicates` counted, zero new rows | `08_uniqueness_replay.sql` | Layer 1 is gone, and with it the safety of M5/M8 crash-replay | |
| 09 | All-or-nothing: one malformed row rejects the batch, zero inserts | `09_all_or_nothing.sql` | Whole-snapshot `acknowledge` becomes unsound — silent data loss | |
| 10 | T8 manual-vs-healthkit preference | `10_pref_manual_vs_healthkit.sql` | The total order's first term is not applied | |
| 11 | T8b three-row chain (B superseded by A, C new canonical) | `11_three_row_chain.sql` | The non-transitive-chain fix has regressed. See Q3 on arrival order | |
| 12 | T8c same-batch healthkit tie broken by `id` | `12_same_batch_tie_by_id.sql` | Canonical election is non-deterministic across replays | |
| 13 | Replay of a persisted batch converges to the identical canonical set | `13_replay_converges.sql` | The recompute is not idempotent; every crash-replay churns the display set | |
| 14 | Late-arriving preferred row demotes the earlier canonical | `14_late_preferred_row_demotes.sql` | The recompute is operating on "rows I just inserted", not persisted rows | |
| 15 | Display query returns the expected set throughout | `15_display_query.sql` | The trend view renders the wrong set | |

Environment recorded with the results: Postgres version, Supabase project ref (non-prod),
date, operator.

# Backend migration — BP Reset V1 (native HealthKit lane handoff)

**Owner of this directory's *content*: the guide. Owner of its *application*: Ben (backend lane).**

## Provenance

`000`–`004` are a **verbatim** extract of §13 of `BP-Reset-HealthKit-Implementation-Guide-v1.3.md`
(guide lines 797–997), split at the section banners already present in the source. The
concatenation of the five files is byte-identical to the guide block:

```
sha256(guide lines 797-997) == sha256(000+001+002+003+004)
== 3b4af7126599515ef6551b30f402477ba941f55b30c3e6a7e26fa3d0ccd57db9
```

Nothing has been corrected, reformatted, or "improved" in transit. Where I believe the
migration has a problem, it is written up as an open question below and left in the SQL
unchanged — the guide is frozen and gets amended, never quietly patched (guide §1,
authority rules).

Re-verify at any time:

```bash
sed -n '797,997p' BP-Reset-HealthKit-Implementation-Guide-v1.3.md | sha256sum
cat db/migrations/00*.sql | sha256sum
```

## Apply order

| # | File | What it does |
|---|---|---|
| 000 | `000_prerequisites.sql` | `enrolments` RLS + select-own policy + grant. **Closes B3's third failure**: the INVOKER ingest binding `select` presumed a read policy that was never migrated. |
| 001 | `001_bp_observations.sql` | `observations` table, CHECK constraints, indexes, RLS select/insert policies. Deliberately **no** update/delete policy. |
| 002 | `002_ingest_bp_batch.sql` | The ingest RPC. SECURITY **INVOKER**, all-or-nothing, no temp tables, zero-row fast path. |
| 003 | `003_canonicalise_bp.sql` | Layer-2 canonicalisation. SECURITY **DEFINER** under the ship-gate-16 carve-out. |
| 004 | `004_grants.sql` | Revokes from `public`/`anon`, grants EXECUTE to `authenticated` on **both** functions. |

Then run the test suite: see `db/tests/README.md`.

## Privilege model (§13, quoted — this is the part that fails at runtime if altered)

> `ingest_bp_batch` is SECURITY INVOKER and depends on the caller being able to *read their
> own enrolment* (migration 000). Clients hold **no update privilege** on `observations` and
> no RLS update policy exists — by design — which is exactly why `canonicalise_bp` is
> SECURITY **DEFINER** under the ship-gate-16 carve-out: pinned `search_path`,
> schema-qualified objects, an internal `auth.uid()` ownership guard, explicit grants.
> EXECUTE on it is **granted** to `authenticated` because PostgreSQL checks EXECUTE against
> the *calling role* even when the call comes from inside another function; the internal
> guard is what makes direct client calls safe.

Per §17.2 the non-negotiables from this lane's correctness argument are: INVOKER ingest with
the in-function `auth.uid()`→enrolment binding; `canonicalise_bp` DEFINER **with all four
carve-out conditions intact**; no client update policy on `observations`; all-or-nothing
batch semantics; the total order ending in `id`; canonicalisation computed from persisted
rows; migration 000's enrolments read policy present. Tests 01–03 exist specifically to
prove the privilege chain, because B3 was three separate runtime failures that a desk-check
had passed.

## Open questions for the backend lane

These are **questions, not redlines**. None is a blocker for applying the migration; Q1 and
Q2 are the two that can stop it executing in a given project.

**Q1 — There is no table-level `GRANT` on `public.observations`.**
`001` enables RLS and creates policies, but never grants SELECT/INSERT to `authenticated`.
In a stock Supabase project this works because the project's default privileges grant table
DML to `anon`/`authenticated` on new tables in `public`. In a project with hardened default
privileges it fails with `permission denied`, *after* passing every RLS desk-check — the
same shape of defect as B3. Test 04 asserts the precondition explicitly so this fails
readably. **Please confirm the client project's default privileges**, or tell me to raise a
guide amendment adding explicit grants to `001`.
*Related nuance, so nobody fixes the wrong thing:* in a stock project `authenticated` will
also hold a table-level UPDATE grant. What actually prevents client updates is the **absent
RLS UPDATE policy**, which is the mechanism B3 relies on. §17.2's phrase "no client update
privilege" should be read as "no update policy". Do not add an update policy to make
canonicalisation work — that is precisely the hole DEFINER exists to avoid.

**Q2 — `001` FK-references `public.patients(id)`, which no section of the guide specifies.**
D3 covers the `enrolments` shape only. I need the `patients` shape (or confirmation it
exists as-is) before the suite can run anywhere but a scratch DB. `db/tests/000_harness.sql`
creates a minimal shim **only if the table is absent**, and says so in a NOTICE.

**Q3 — T8b's expected outcome is arrival-ordered, and the guide does not say so.**
The preference order (`healthkit` → `ingested_at` → `id` → `client_uuid`) contains **no
`taken_at` term**, so the cluster anchor is whichever row sorts first on arrival, not the
earliest reading. §14 T8b asserts "B superseded by A; C is a new canonical" — that holds
when A has the smallest `id`. If B arrived first (entirely possible in production: a
backdated vendor insert enqueues *after* a later-taken reading, so it carries a higher
`itemId` and lands later in the snapshot array), then B anchors, A falls inside B's window,
and C at 170 s from B falls **inside** the window too — a different, also-correct-by-the-rules
result. Test 11 pins the arrival order and asserts the id ordering as an explicit
precondition rather than hiding the assumption. **Please confirm the arrival-ordered anchor
is intended** (I believe it is — it is what makes the recompute replay-stable), so it can be
stated in §8.2 at the as-built republish.

**Q4 — `000`/`001` are not re-runnable.** `create policy` has no `IF NOT EXISTS`, so a second
apply errors even though the `create table if not exists` succeeds. §13 already anticipates
this for `000` ("verify it and skip"). For a project that already carries an `observations`
table, §13 says you derive a diff migration from this canonical form — flag if you want that
diff from me instead.

**Q5 — Wrong-*type* input raises a cast error, not `STRUCTURAL_VALIDATION_FAILED`.**
Validation runs *inside* `jsonb_to_recordset(...) as r(client_uuid uuid, ...)`, so a
non-UUID `client_uuid` or unparseable `taken_at` fails at the cast before the `exists` check
runs. Behaviour is still all-or-nothing and still safe — the batch rolls back and the client
acknowledges nothing — only the error code differs. Noted in test 09. Confirm acceptable;
the plugin's own structural validation (§7.3) makes it unreachable in practice from this
lane, but the RPC is also the manual lane's contract.

# BP Reset V1 — Migration Plan

| | |
|---|---|
| **Status** | Implemented in `supabase/migrations/` (applied to `corveo-ios-app` / `ltggfrlnhquvrrnxpdtr`) |
| **Owner** | Ben (platform) |
| **Version** | 0.2 |
| **Date** | 20 August 2026 |
| **Source** | `02-data-model-and-api.md`, `03-plugin-bridge-spec.md` |
| **Supersedes** | v0.1 (Claude Code draft) |

---

## What changed in 0.2

v0.1 transcribed the schema tables from doc 02 accurately but omitted every write path the app needs, and carried two security defects. Corrections:

**Security** — `search_path` pinned on all `security definer` functions; views created `security_invoker`; explicit GRANT/REVOKE added; append-only enforced by trigger rather than by comment.

**Missing write paths** — added `enrol_patient()`, `record_consent()`, `soft_delete_observation()`, `delete_account()`. Without these the app cannot set the adult attestation, capture the Apple display name, let a patient remove a reading, or satisfy App Store Guideline 5.1.1(v).

**Integrity** — `UNIQUE` on `auth_user_id`; `is_panel` denormalised so the value CHECK is implementable; enum CHECKs on `status`, `source_type`, `deleted_reason`, `actor_type`; FK from `observation.code` to the definition table.

**Performance** — indexes on `observation_component(observation_id)`, `observation_component(source_uuid)`, `consent_event(user_id, occurred_at desc)`.

**Behaviour** — `auth.users` trigger removed (it fired on anonymous sessions, creating rows for people who never enrolled); component-level deletion matching made explicit; `v_bp_trend` fully specified.

**Deferred** — heart rate seed split out until the AU Core SNOMED code is confirmed. No `TBD` ships into a `NOT NULL` column.

---

## Migration sequence

Use real creation timestamps. All migrations in the `public` schema. Forward-only, one concern per file, never edited after merge.

| # | File | Description | Depends on |
|---|---|---|---|
| 01 | `create_app_user.sql` | `app_user` table, unique auth link | — |
| 02 | `create_observation_definition.sql` | Reference table | — |
| 03 | `seed_observation_definitions_bp.sql` | BP panel, systolic, diastolic | 02 |
| 04 | `create_observation.sql` | Parent table, constraints, indexes | 01, 02 |
| 05 | `create_observation_component.sql` | Child table, constraints, indexes | 04 |
| 06 | `create_consent_event.sql` | Append-only consent log | 01 |
| 07 | `create_audit_event.sql` | Append-only audit log | 01 |
| 08 | `create_program_progress.sql` | Journey state | 01 |
| 09 | `create_helper_functions.sql` | `get_app_user_id()`, `has_active_consent()`, `prevent_mutation()` | 01, 06 |
| 10 | `create_append_only_guards.sql` | Triggers + revokes on 06, 07 | 06, 07, 09 |
| 11 | `create_rls_policies.sql` | RLS on all patient tables | 01–08, 09 |
| 12 | `create_views.sql` | `v_bp_readings`, `v_bp_trend`, `v_consent_status`, `v_program_progress` | 04, 05, 06, 09 |
| 13 | `create_ingest_rpc.sql` | `ingest_observations()` | 04, 05, 09 |
| 14 | `create_patient_rpcs.sql` | `enrol_patient()`, `record_consent()`, `soft_delete_observation()`, `delete_account()` | 04, 06, 09 |
| 15 | `create_export_rpc.sql` | `export_patient_data()` (Deliverable 12) | 04, 05 |
| 16 | `grants.sql` | All GRANT/REVOKE in one auditable place | 01–15 |
| — | `seed_observation_definitions_hr.sql` | Heart rate — **blocked on D-01** | 02 |

---

## 01 — `create_app_user.sql`

As v0.1, with three changes.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | `primary key default gen_random_uuid()` |
| `auth_user_id` | `uuid` | `unique references auth.users(id) on delete set null` |
| `display_name` | `text` | |
| `adult_attested` | `boolean` | `not null default false` |
| `adult_attested_at` | `timestamptz` | |
| `identity_deleted_at` | `timestamptz` | |
| `created_at` | `timestamptz` | `not null default now()` |

**`unique` on `auth_user_id`** — without it, nothing prevents two rows per auth user, and `get_app_user_id()` returns a scalar. Ambiguous at best.

**No trigger on `auth.users`.** v0.1 auto-created an `app_user` row on every auth insert. The onboarding flow opens an anonymous session at app launch, so that trigger would create a permanent patient record for everyone who opens the app once and never signs up — junk accumulation, and a record about someone who never enrolled, which sits badly against data minimisation. Enrolment is explicit via `enrol_patient()` (migration 14), so `app_user` means "enrolled in BP Reset" rather than "launched the app".

**Index:** `unique (auth_user_id)` covers the `get_app_user_id()` lookup.

---

## 02 — `create_observation_definition.sql`

As v0.1. Add `check (expected_unit is not null or is_panel)` — a non-panel definition without a unit cannot be validated against.

---

## 03 — `seed_observation_definitions_bp.sql`

| code | display | snomed | parent | unit | min | max | panel | display_v1 | sort |
|---|---|---|---|---|---|---|---|---|---|
| `85354-9` | Blood pressure panel | `75367002` | — | — | — | — | yes | yes | 10 |
| `8480-6` | Systolic BP | `271649006` | `85354-9` | `mm[Hg]` | 60 | 260 | no | yes | 11 |
| `8462-4` | Diastolic BP | `271650006` | `85354-9` | `mm[Hg]` | 30 | 160 | no | yes | 12 |

Heart rate is **not seeded here**. v0.1 put `TBD` into a `not null` SNOMED column, which means the placeholder ships. It gets its own migration once D-01 resolves the code against the AU Core Heart Rate profile. Until then the ingest RPC rejects `8867-4` with `UNKNOWN_CODE`, which is correct behaviour — the plugin requests the HealthKit permission but nothing is stored, and that needs to be understood before Stage 2 sign-off.

---

## 04 — `create_observation.sql`

Columns as v0.1, plus `is_panel boolean not null default false`, and the following corrections.

**`is_panel` denormalised.** v0.1's CHECK constraint was described as "exactly one of: value column populated, `data_absent_reason` set, or `is_panel` code". A CHECK cannot reference another table, so it was not implementable. The ingest RPC copies `is_panel` from `observation_definition` on write, making this local:

```sql
alter table public.observation add constraint observation_value_shape check (
  (is_panel
     and num_nonnulls(value_quantity, value_code, value_string, value_boolean) = 0
     and data_absent_reason is null)
  or (not is_panel
     and num_nonnulls(value_quantity, value_code, value_string, value_boolean) = 1
     and data_absent_reason is null)
  or (not is_panel
     and num_nonnulls(value_quantity, value_code, value_string, value_boolean) = 0
     and data_absent_reason is not null)
);

alter table public.observation add constraint observation_unit_with_quantity check (
  value_quantity is null or value_unit is not null
);
```

**Enum constraints** — absent in v0.1, cheap, and they prevent silent garbage:

```sql
check (status in ('registered','preliminary','final','amended','corrected','entered-in-error','cancelled','unknown'))
check (source_type in ('healthkit','manual'))
check (deleted_reason is null or deleted_reason in ('deleted_in_source','patient_removed','entered_in_error'))
check ((deleted_at is null) = (deleted_reason is null))
```

The last one prevents a soft delete with no reason, and a reason with no deletion.

**FK to the definition table:**

```sql
foreign key (code) references public.observation_definition(code)
```

The RPC validates too; this is defence in depth for one line.

**`effective_tz not null default 'Australia/Sydney'`.** v0.1 left it nullable while doc 02 derives all local time from it. Either it's always present or the fallback is explicit. Australian users first, so the default is defensible and documented.

**Indexes:**

```sql
unique (user_id, source_system, source_uuid)
index (user_id, effective_time desc) where deleted_at is null
```

---

## 05 — `create_observation_component.sql`

Columns as v0.1, with:

**`source_uuid text not null`.** v0.1 had it nullable on the child and `not null` on the parent — inconsistent, and it's the *component* one that deletion matching depends on. Doc 03 §5.3 is explicit that `HKDeletedObject` carries only a UUID, and which UUID arrives depends on the type the deletion was observed against. Nullable here silently reintroduces the half-of-cases failure doc 02 warns about.

**Same value-shape CHECK** as the parent, minus the panel branch (components are never panels).

**Indexes — both missing in v0.1:**

```sql
index (observation_id)          -- Postgres does NOT auto-index FKs.
                                -- This is the join behind every read
                                -- and the RLS subquery on top of it.
index (source_uuid)             -- deletion matching; otherwise every
                                -- deletion batch is a sequential scan
unique (observation_id, code)
```

---

## 06 / 07 — `consent_event`, `audit_event`

Columns as v0.1, plus enum CHECKs:

```sql
-- audit_event
check (actor_type in ('patient','system','corveo_admin'))
check (event_type in (
  'observation_ingested','observation_soft_deleted',
  'consent_granted','consent_withdrawn',
  'export_generated','identity_deleted','patient_enrolled'
))
```

**Indexes:**

```sql
-- consent_event
index (user_id, occurred_at desc)   -- has_active_consent() sorts on every
                                     -- call, and it is called from RLS paths
-- audit_event
index (user_id, occurred_at desc)
```

---

## 08 — `create_program_progress.sql`

As v0.1, plus a trigger to maintain `updated_at` — v0.1 declares the column with a default and never updates it.

```sql
check (current_week between 1 and 6)
```

---

## 09 — `create_helper_functions.sql`

**Every `security definer` function must pin `search_path` and fully qualify.** v0.1 did neither. An unpinned `security definer` function is a privilege-escalation vector: a caller who can create objects in an earlier schema on the path can shadow `app_user` and have the function execute their table with the owner's rights. Supabase's own linter flags this.

```sql
create or replace function public.get_app_user_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select au.id
  from public.app_user au
  where au.auth_user_id = auth.uid()
    and au.identity_deleted_at is null
$$;

create or replace function public.has_active_consent(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select ce.event_type = 'granted'
       from public.consent_event ce
      where ce.user_id = p_user_id
      order by ce.occurred_at desc, ce.id desc
      limit 1),
    false
  )
$$;

create or replace function public.prevent_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '%.% is append-only', tg_table_schema, tg_table_name
    using errcode = 'P0001';
end;
$$;
```

`has_active_consent()` is `security definer` because it reads an RLS-protected table and is called from contexts where the caller may not have a policy match. v0.1 left it invoker, making its result depend on calling context.

---

## 10 — `create_append_only_guards.sql` (new)

v0.1 wrote "**No UPDATE or DELETE** — append-only by design" and enforced nothing. For a log discharging a contractual obligation under A.12.6, a comment in a markdown file is not evidence to a reviewer.

```sql
revoke update, delete on public.consent_event from anon, authenticated;
revoke update, delete on public.audit_event  from anon, authenticated;

create trigger consent_event_append_only
  before update or delete on public.consent_event
  for each row execute function public.prevent_mutation();

create trigger audit_event_append_only
  before update or delete on public.audit_event
  for each row execute function public.prevent_mutation();
```

The trigger catches `security definer` paths that the revoke does not.

---

## 11 — `create_rls_policies.sql`

v0.1 listed a "Rule" per policy without stating `using` vs `with check`, and used `upsert_own`, which is not a Postgres policy type — `INSERT` takes `with check` only, `UPDATE` takes both.

| Table | Policy | Command | Clause |
|---|---|---|---|
| `app_user` | `select_own` | SELECT | `using (id = get_app_user_id())` |
| `observation` | `select_own` | SELECT | `using (user_id = get_app_user_id() and deleted_at is null)` |
| `observation_component` | `select_own` | SELECT | see below |
| `consent_event` | `select_own` | SELECT | `using (user_id = get_app_user_id())` |
| `audit_event` | *(none)* | — | RLS enabled, no policy — patients cannot read |
| `program_progress` | `select_own` | SELECT | `using (user_id = get_app_user_id())` |
| `program_progress` | `insert_own` | INSERT | `with check (user_id = get_app_user_id())` |
| `program_progress` | `update_own` | UPDATE | `using (...)` **and** `with check (...)` |

`consent_event` has **no INSERT policy** — v0.1 gave patients direct insert, which would let a client forge a consent record. Writes go through `record_consent()`.

**`observation_component` policy** — v0.1 said "via parent join", which is not a policy:

```sql
create policy observation_component_select_own on public.observation_component
  for select using (
    exists (
      select 1 from public.observation o
      where o.id = observation_component.observation_id
        and o.user_id = public.get_app_user_id()
        and o.deleted_at is null
    )
  );
```

This is why the `observation_component(observation_id)` index in migration 05 is not optional.

No INSERT, UPDATE or DELETE policy on `observation` or `observation_component`. All writes go through RPCs.

---

## 12 — `create_views.sql`

**All views created `with (security_invoker = true)`.** v0.1 omitted this. Views default to running with the *owner's* privileges, so a view owned by `postgres` reads underlying tables ignoring RLS entirely. `v_bp_readings` happened to carry its own `user_id` filter, so it wasn't leaking — but the security rested on a `WHERE` clause instead of on RLS, and one careless edit exposes every patient's readings.

```sql
create view public.v_bp_readings with (security_invoker = true) as
select
  o.id,
  o.user_id,
  o.effective_time,
  o.effective_tz,
  sys.value_quantity as systolic,
  dia.value_quantity as diastolic,
  o.source_type,
  o.source_name,
  o.body_site_code
from public.observation o
join public.observation_component sys
  on sys.observation_id = o.id and sys.code = '8480-6'
join public.observation_component dia
  on dia.observation_id = o.id and dia.code = '8462-4'
where o.code = '85354-9'
  and o.deleted_at is null;
```

Joins rather than v0.1's correlated subqueries — one scan instead of two per row. The `user_id` filter is dropped from the view body because `security_invoker` now applies the RLS policy; keeping both is harmless but the policy is the authority.

**`v_bp_trend`** — v0.1 described this in one line. It is the view the entire trend chart depends on, so it is specified here. Daily grain (D-02) assumed; confirm with Michael before Stage 3.

```sql
create view public.v_bp_trend with (security_invoker = true) as
select
  o.user_id,
  (o.effective_time at time zone o.effective_tz)::date as day,
  min(sys.value_quantity)            as min_systolic,
  max(sys.value_quantity)            as max_systolic,
  round(avg(sys.value_quantity), 0)  as mean_systolic,
  min(dia.value_quantity)            as min_diastolic,
  max(dia.value_quantity)            as max_diastolic,
  round(avg(dia.value_quantity), 0)  as mean_diastolic,
  count(*)                           as reading_count
from public.observation o
join public.observation_component sys
  on sys.observation_id = o.id and sys.code = '8480-6'
join public.observation_component dia
  on dia.observation_id = o.id and dia.code = '8462-4'
where o.code = '85354-9'
  and o.deleted_at is null
group by o.user_id, 2;
```

The date is derived from `effective_tz`, not from UTC — that is the entire reason the column exists. A reading taken at 8am Sydney must group to that day, not to the previous one.

**`v_consent_status`** as v0.1, with `security_invoker`. **`v_program_progress`** added — v0.1 omitted it while doc 02 §4.3 lists it.

---

## 13 — `create_ingest_rpc.sql`

As v0.1, with these additions.

`security definer`, `set search_path = ''`, all references qualified.

Copies `is_panel` from `observation_definition` onto the row so the CHECK in migration 04 works.

**Deletion matches parent *or* component `source_uuid`.** v0.1 said only "soft-deletes by `deleted_source_uuids`", which reads as parent-only:

```sql
update public.observation o
   set deleted_at = now(), deleted_reason = 'deleted_in_source'
 where o.user_id = v_user_id
   and o.deleted_at is null
   and (
     o.source_uuid = any(v_deleted)
     or exists (
       select 1 from public.observation_component c
        where c.observation_id = o.id
          and c.source_uuid = any(v_deleted)
     )
   );
```

Rejection reasons unchanged. Add `CONSENT_REQUIRED` handling as an exception, not a rejection — it fails the whole call, per doc 02 §4.2.

---

## 14 — `create_patient_rpcs.sql` (new — entirely missing from v0.1)

v0.1 described a database the app cannot use: no path to set the adult attestation, capture the display name, remove a reading, or delete an account.

**`enrol_patient(p_display_name text, p_adult_attested boolean)`**
Creates the `app_user` row for `auth.uid()`, or updates it if one exists. Rejects `p_adult_attested = false`. Writes `patient_enrolled`.

Called at the signup step. **This is the only moment the Apple display name is available** — Apple returns the name once, on first authorisation, and never again. If it is not captured here it is gone permanently.

**`record_consent(p_version text, p_document_hash text)`**
Inserts a `granted` event. `withdraw_consent()` inserts a `withdrawn` event. Never updates. Writes the corresponding audit event.

**`soft_delete_observation(p_observation_id uuid)`**
Sets `deleted_at` and `deleted_reason = 'patient_removed'` for a row owned by the caller. Writes `observation_soft_deleted`. This is the patient-facing "remove from my record" path required by Deliverable 12 — v0.1 had no way for a patient to remove a reading at all.

**`delete_account()`**
Nulls `auth_user_id`, sets `identity_deleted_at`, clears `display_name`, writes `identity_deleted`, then deletes the `auth.users` row. Clinical rows are retained under the health-records floor per A.12.6. Required by App Store Guideline 5.1.1(v) — its absence is review-blocking, not cosmetic.

---

## 15 — `create_export_rpc.sql`

As v0.1, with `search_path` pinned.

**Decision needed before building.** v0.1 assumes a FHIR R4 Bundle assembled in plpgsql. It is doable with `jsonb_build_object`, but it will be long, brittle and unpleasant to test — and it is the one place in V1 where an Edge Function would genuinely earn its keep, since the alternative is hand-writing nested JSON construction in SQL. Decide deliberately rather than discovering it in week four. If the answer is an Edge Function, decision A-04 needs an explicit amendment rather than a quiet exception.

---

## 16 — `grants.sql` (new — entirely missing from v0.1)

Without grants, PostgREST exposes nothing and Michael gets 404s on every endpoint. Supabase also applies default privileges to `anon` and `authenticated` on new `public` tables, so explicit revokes matter as much as the grants.

```sql
revoke all on all tables in schema public from anon, authenticated;

grant usage on schema public to anon, authenticated;

grant select on
  public.v_bp_readings,
  public.v_bp_trend,
  public.v_consent_status,
  public.v_program_progress
to authenticated;

grant select, insert, update on public.program_progress to authenticated;

grant execute on function
  public.ingest_observations(jsonb),
  public.enrol_patient(text, boolean),
  public.record_consent(text, text),
  public.withdraw_consent(),
  public.soft_delete_observation(uuid),
  public.delete_account(),
  public.export_patient_data()
to authenticated;

-- anon (pre-signup anonymous session) gets nothing beyond schema usage
```

Base tables are never granted to clients. Reads go through views, writes through RPCs.

---

## Constraints summary

### Prohibited columns (A.3.3)

Never to be added: `category`, `severity`, `band`, `is_high`, `is_low`, `is_normal`, `risk_score`, `heart_age`, `normal_range`, `reference_range`, or any column interpreting a clinical value.

`is_panel` is a structural flag describing whether components are expected. It carries no clinical meaning and is not an exception to the above.

### Required audit trail (A.12.6)

Every state change writes to `audit_event` in the same transaction: `patient_enrolled`, `observation_ingested`, `observation_soft_deleted`, `consent_granted`, `consent_withdrawn`, `export_generated`, `identity_deleted`.

---

## Pre-apply checklist

Run before pushing to any hosted project:

- [ ] `supabase db lint` clean — particularly `security definer` and RLS warnings
- [ ] Every table in `public` has RLS enabled
- [ ] Every `security definer` function has `set search_path = ''`
- [ ] Every view has `security_invoker = true`
- [ ] No base table granted to `anon` or `authenticated`
- [ ] Every foreign key has a supporting index
- [ ] Seed data contains no `TBD` or placeholder values
- [ ] `supabase db reset` replays cleanly from empty

---

## Open items

| # | Item | Blocks |
|---|---|---|
| D-01 | AU Core Heart Rate SNOMED code | Heart rate seed migration |
| D-02 | Trend aggregation grain confirmed with Michael | `v_bp_trend` final |
| D-03 | NCTS body-site codes, left/right upper arm | Manual entry validation |
| D-06 | FHIR Bundle in plpgsql vs Edge Function | Migration 15 |

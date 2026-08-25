# Drain harness — end-to-end pipeline test

**Throwaway test code.** Not the product drain, and it does not implement §12 P4. It exists to
answer one question: does the whole chain hold together — Apple Health, the native plugin, the
durable queue, and the client's schema.

## What it does

Takes a snapshot exported from the device and writes each reading to the client's FHIR AU Core
shape: one `observation` panel row (LOINC `85354-9`) plus two `observation_component` rows
(`8480-6` systolic, `8462-4` diastolic). Then prints the `itemId`s to acknowledge.

Before writing anything it checks three things that otherwise fail mid-insert: that the token
resolves to an `app_user` row (RLS refuses everything without one), that the LOINC codes are
seeded in `observation_definition` (`observation.code` is a foreign key to it), and — with
`--dry-run` — stops there.

## Two caveats, both properties of the project rather than of this script

1. **Not atomic.** The deployed schema has no ingest RPC, so a reading is three separate
   PostgREST calls with no transaction. If the components fail after the panel lands, the panel
   is orphaned; the harness says so explicitly. §13 wanted all-or-nothing for exactly this
   reason. This is what C15 looks like in practice.
2. **No uniqueness constraint.** The schema has no unique index on `(user_id, source_uuid)`, so
   a replay duplicates. §8.1 says Layer-1 correctness *"depends solely on the constraint"* — it
   is not there. This script compensates by checking for an existing `source_uuid` first, which
   is a workaround, not a fix: it races, and concurrent drains both pass the check.

## Running it

Export a snapshot from the device (writer-generated **synthetic** readings only, §4.2):

```bash
xcrun devicectl device process launch --device <udid> --console --terminate-existing \
  dev.lucab.bpspike -- -spikeNoAutoArm -spikeExportSnapshot
```

Lift the JSON between `SPIKE-SNAPSHOT-JSON-BEGIN` / `END` into a file. That payload carries
values by design — it is the drain payload, not a log line. Do not commit it, do not put it in
evidence, and run it against synthetic data only.

Against the client's Supabase, once someone with dashboard access has created a confirmed user
**and** its matching `app_user` row:

```bash
SUPABASE_URL=... SUPABASE_KEY=<publishable> BP_EMAIL=... BP_PASSWORD=... \
  python3 drain.py --snapshot snapshot.json --dry-run
```

Against a local stand-in (Postgres + PostgREST, no auth service), pass a pre-minted JWT and an
empty REST prefix, since Supabase fronts PostgREST at `/rest/v1` and a bare PostgREST serves at
the root:

```bash
SUPABASE_URL=http://127.0.0.1:54330 SUPABASE_REST_PREFIX="" \
  SUPABASE_KEY=unused BP_ACCESS_TOKEN=<jwt> python3 drain.py --snapshot snapshot.json
```

The stand-in needs an `auth` schema, `auth.uid()`, `get_app_user_id()`, RLS policies, PostgREST
roles and the LOINC definitions — **none of which are in the client's dump**, which is tables
only. Those parts are reconstructed, so the stand-in validates the shape rather than their exact
policies.

Credentials come from the environment. They are never written to disk and never echoed.

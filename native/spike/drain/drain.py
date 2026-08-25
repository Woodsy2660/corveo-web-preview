#!/usr/bin/env python3
"""End-to-end drain harness: device snapshot -> Supabase observation/observation_component.

THROWAWAY TEST CODE. This is not the product drain and does not implement §12 P4.
It exists to answer one question: does the whole chain hold together — Apple Health,
the native plugin, the durable queue, and the client's live Supabase schema.

Two honest caveats, both consequences of the project as it stands rather than of this script:

  1. NOT ATOMIC. The deployed schema carries no ingest RPC, so a blood-pressure reading has
     to be written as three separate PostgREST calls: one `observation` panel row and two
     `observation_component` rows. There is no transaction across them. If the components
     fail after the panel lands, the panel is orphaned. Guide §13 wanted all-or-nothing for
     exactly this reason, and this is what C15 looks like in practice.

  2. NO UNIQUENESS CONSTRAINT. The schema has no unique index on (user_id, source_uuid), so
     a replay inserts duplicates. Guide §8.1 states that Layer-1 idempotency correctness
     "depends solely on the constraint" — that constraint does not exist here. This script
     compensates client-side by checking for an existing source_uuid first, which is a
     workaround, not a fix: it races and it does not survive concurrent drains.

Credentials come from the environment and are never written to disk or echoed.
Run against writer-generated SYNTHETIC readings only (§4.2).
"""
import json, os, sys, urllib.request, urllib.error, argparse

LOINC = "http://loinc.org"
SNOMED = "http://snomed.info/sct"
PANEL = ("85354-9", "Blood pressure panel with all children optional", "75367002")
SYS   = ("8480-6", "Systolic blood pressure", "271649006")
DIA   = ("8462-4", "Diastolic blood pressure", "271650006")


def req(method, url, key, token=None, body=None, prefer=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("apikey", key)
    r.add_header("Authorization", f"Bearer {token or key}")
    r.add_header("Content-Type", "application/json")
    if prefer:
        r.add_header("Prefer", prefer)
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            raw = resp.read().decode() or "null"
            return resp.status, json.loads(raw)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw[:400]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", required=True)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    url = os.environ["SUPABASE_URL"].rstrip("/")
    # Supabase fronts PostgREST at /rest/v1; a bare PostgREST (the local stand-in) serves
    # at the root. Everything else about the request is identical.
    rest = url + os.environ.get("SUPABASE_REST_PREFIX", "/rest/v1")
    key = os.environ["SUPABASE_KEY"]
    email = os.environ.get("BP_EMAIL")
    pw = os.environ.get("BP_PASSWORD")
    pretoken = os.environ.get("BP_ACCESS_TOKEN")
    if not pretoken and (not email or not pw):
        sys.exit("set BP_EMAIL and BP_PASSWORD, or BP_ACCESS_TOKEN, in the environment")

    snap = json.load(open(a.snapshot))
    rows = snap["readings"]
    print(f"snapshot {snap['snapshotId']}: {len(rows)} reading(s)")

    # 1. authenticate — either a real GoTrue sign-in, or a pre-minted token when running
    #    against the local stand-in, which has PostgREST but no auth service.
    if pretoken:
        import base64
        token = pretoken
        payload = token.split(".")[1]
        payload += "=" * (-len(payload) % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload))
        auth_uid = claims["sub"]
        print(f"  auth        ok   pre-minted token, sub {auth_uid[:8]}… role={claims.get('role')}")
    else:
        st, tok = req("POST", f"{url}/auth/v1/token?grant_type=password", key,
                      body={"email": email, "password": pw})
        if st != 200:
            sys.exit(f"  AUTH FAILED http {st}: {json.dumps(tok)[:300]}")
        token = tok["access_token"]
        auth_uid = tok["user"]["id"]
        print(f"  auth        ok   auth.users id {auth_uid[:8]}…")

    # 2. resolve app_user.id under RLS
    st, au = req("GET", f"{rest}/app_user?select=id&auth_user_id=eq.{auth_uid}", key, token)
    if st != 200 or not au:
        sys.exit(f"  NO app_user ROW for this auth user (http {st}: {json.dumps(au)[:200]}).\n"
                 "  The account exists in auth.users but has no app_user record, so RLS will\n"
                 "  refuse every write. Something has to create that row — that is the\n"
                 "  enrolment step, and it is exactly what has no home in this schema (C16).")
    user_id = au[0]["id"]
    print(f"  app_user    ok   {user_id[:8]}…")

    # 3. the FK target must exist or every insert fails
    codes = ",".join(c[0] for c in (PANEL, SYS, DIA))
    st, defs = req("GET", f"{rest}/observation_definition?select=code&code=in.({codes})", key, token)
    found = {d["code"] for d in defs} if st == 200 and isinstance(defs, list) else set()
    missing = {c[0] for c in (PANEL, SYS, DIA)} - found
    print(f"  definitions {'ok' if not missing else 'MISSING ' + ','.join(sorted(missing))}"
          f"   (observation.code is a FK to observation_definition)")
    if missing and not a.dry_run:
        sys.exit("  cannot insert: the LOINC codes above are not seeded in observation_definition")

    if a.dry_run:
        print("  dry run — stopping before any write")
        return

    inserted, skipped, failed, acked = 0, 0, 0, []
    for r in rows:
        # client-side idempotency, standing in for the absent unique constraint
        st, dup = req("GET",
                      f"{rest}/observation?select=id&source_uuid=eq.{r['hkUuid']}&user_id=eq.{user_id}",
                      key, token)
        if st == 200 and dup:
            print(f"  {r['hkUuid'][:8]}  skip (already present)")
            skipped += 1
            acked.append(r["itemId"])
            continue

        panel = {
            "user_id": user_id, "status": "final",
            "code_system": LOINC, "code": PANEL[0], "code_display": PANEL[1],
            "code_system_snomed": SNOMED, "code_snomed": PANEL[2],
            "is_panel": True,
            "effective_time": r["takenAt"],
            "effective_offset_minutes": r.get("tzOffsetMinutes"),
            "recorded_at": r["receivedAt"],
            "source_type": "healthkit",
            "source_uuid": r["hkUuid"],
            "source_system": r["sourceBundleId"],
            "source_name": r.get("sourceName"),
            "source_device_model": r.get("deviceModel"),
            "source_user_entered": False,
            "context": {},
        }
        st, obs = req("POST", f"{rest}/observation", key, token,
                      body=panel, prefer="return=representation")
        if st not in (200, 201) or not obs:
            print(f"  {r['hkUuid'][:8]}  PANEL FAILED http {st}: {json.dumps(obs)[:220]}")
            failed += 1
            continue
        oid = obs[0]["id"]

        comps = []
        for code, uuid_key, val_key in ((SYS, "systolicUuid", "systolic"),
                                        (DIA, "diastolicUuid", "diastolic")):
            comps.append({
                "observation_id": oid,
                "code_system": LOINC, "code": code[0], "code_display": code[1],
                "code_system_snomed": SNOMED, "code_snomed": code[2],
                "value_quantity": r[val_key], "value_unit": "mm[Hg]",
                "source_uuid": r.get(uuid_key) or r["hkUuid"],
            })
        st, cres = req("POST", f"{rest}/observation_component", key, token,
                       body=comps, prefer="return=representation")
        if st not in (200, 201):
            print(f"  {r['hkUuid'][:8]}  panel {oid[:8]} inserted but COMPONENTS FAILED "
                  f"http {st}: {json.dumps(cres)[:200]}  <- ORPHANED PANEL (see caveat 1)")
            failed += 1
            continue

        print(f"  {r['hkUuid'][:8]}  ok  observation {oid[:8]} + {len(cres)} components")
        inserted += 1
        acked.append(r["itemId"])

    print(f"\ninserted={inserted} skipped={skipped} failed={failed}")
    if acked:
        print("ACK-ITEMS " + ",".join(acked))
        print(f"ACK-SNAPSHOT {snap['snapshotId']}")


if __name__ == "__main__":
    main()

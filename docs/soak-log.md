# T6 soak log — 48 hours of background capture on the acceptance handset

| | |
|---|---|
| **Test** | T6 in `docs/stage2-test-script.md` (guide v1.3 §14): still capturing on day 3; every deferred pass converges; zero duplicate rows. Evidences Stage 2 criterion (c). |
| **Started** | Tuesday 2 September 2026, 10:39 AEST |
| **Ends** | Thursday 4 September 2026, 10:39 AEST or later |
| **Handset** | iPhone 17, `iPhone18,3`, iOS 26.6.1 build 23G83 |
| **Build under test** | `dev.aiplease.bpreset` Debug, commit `0d4a0b4` on `integration/native-app`. **Not reinstalled, rebuilt or force-quit for the duration.** The free-team profile is valid until 9 September. |
| **Sources** | `dev.lucab.bpwriter` (synthetic, the only app with Health write permission; delayed saves of 10 to 90 s) and the loan Omron cuff through OMRON connect. |
| **Backend** | Corveo dev project, v0.2 schema. |
| **Operator** | Nick |

## Rules for the 48 hours

- Use the phone normally. Do not swipe BP Reset away in the app switcher (that is T5b, a separate test). Do not reinstall it.
- Never write a reading value here, in a screenshot, or in chat. Counts, states, codes and yes/no only.
- Before each checkpoint, note the Apple Health row count on the Record tab and the development card line (state, pending, held, rejected with codes, malformed). After the checkpoint, note them again.
- If a checkpoint fails (no row, a duplicate row, a rejection), stop and record exactly what the card says before doing anything else.

## Checkpoints

| # | When | What to do | Expected | Result |
|---|---|---|---|---|
| C1 | Tue 2 Sep, at start | Baseline counts. Then writer: delay 30 s, Schedule save, lock the phone at once, wait 60 s, unlock, open BP Reset. | New Apple Health row present without tapping Sync. Pending 0 afterwards. | |
| C2 | Tue 2 Sep, evening | With BP Reset in the background (not opened for at least an hour), take an Omron reading, let OMRON connect transfer it, wait two minutes, then open BP Reset. | Row present with the OMRON connect chip; rejected count unchanged. | |
| C3 | Wed 3 Sep, morning | Locked store. Writer: delay 90 s (its longest), Schedule save, lock the phone immediately and leave it locked for at least 10 minutes in total. Unlock, wait 30 s without opening anything, then open BP Reset. Whether iOS delivered the wake while locked (a deferred pass, protected data unavailable) or held it until unlock, the criterion is the same. | The reading arrives exactly once; pending 0 afterwards; no duplicate. | |
| C4 | Wed 3 Sep, evening | Reboot. After the reboot, unlock the phone but do not open BP Reset. Take an Omron reading (or open the writer, Schedule save with a 90 s delay, and go back to the home screen), wait two minutes, then open BP Reset. | Row present. The observer survived the reboot and background delivery relaunched the app before it was opened. | |
| C5 | Thu 4 Sep, 10:40 or later | One writer save (30 s delay, locked) and one Omron reading, then open BP Reset. Record final counts. Run the two queries below in the Supabase SQL editor. | Both rows present exactly once. Distinct source UUIDs equal row counts for every source. No duplicates or rejections in the ingest audit rows since the start. | |

Passive observations to note whenever they happen: the 8 am and 8 pm reminders arrive if enabled (never with any reading content); any rejection count change with its code; any time the Apple Health card reports readings arrived without Sync being tapped.

## End-of-soak queries (values never selected)

```sql
select source_system, count(*) as rows, count(distinct source_uuid) as distinct_uuids
from public.observation
where deleted_at is null
group by source_system
order by source_system;
```

```sql
select created_at, detail
from public.audit_event
where event_type = 'observation_ingested'
  and created_at >= '2026-09-02 00:39:00+00'
order by created_at desc;
```

Pass when `distinct_uuids = rows` on every line of the first query, and every `detail` in the second shows `duplicates: 0` and `rejected_count: 0` (a replay you provoked deliberately is the one allowed exception, and it must show duplicates rather than new rows).

## Results

| Checkpoint | Time | Apple Health rows before → after | Card before → after (pending / held / rejected / malformed) | Arrived without Sync | Notes |
|---|---|---|---|---|---|
| C1 | | | | | |
| C2 | | | | | |
| C3 | | | | | |
| C4 | | | | | |
| C5 | | | | | |

**Verdict:** pending.

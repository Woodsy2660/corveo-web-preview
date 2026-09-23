# Corveo BP Basics - implementation and review handoff

Package version 0.1 | Prepared 16 September 2026
Workstream: 04.05 - PROGRAM | BP BASICS
Status: proposed private prototype specification, not release authorisation
Canonical asset ID: unassigned. The filenames and local keys in this package do not allocate company content IDs.

## Scope and completeness

The mock-up covers the complete six-week index, six full chapter readers, website/app presentation, a fictional blood-pressure record, a graph/list/average view, manual entry, an Apple Health setup simulation, a fictional export, and the ten-title Learn catalogue.

The full programme text is included. The six Pulse and four In Focus independent article bodies are not included because those source bodies have not been supplied for this handoff. The existing/planned distinction is preserved in the content JSON. A library card does not imply that its article is written, reviewed or published.

The user requested reuse of previous fonts. A prior Corveo HTML framework explicitly names Spectral, Hanken Grotesk and IBM Plex Mono. This establishes an earlier typography precedent. It does not establish the exact CSS of the photographed app. The existing project's actual font declarations should prevail when available; otherwise that prior pair is a documented starting point, not a screenshot identification.

## What came from where

| Source | Used for | Limits |
|---|---|---|
| Owner's latest request | Full six-week Lovable mock-up; website/app; readings, timestamps, graphs, Apple Health | Does not authorise a production integration, public deployment or patient-data import |
| CORV-EDU-001 v0.7, 15 September 2026 | Six titles/order, key takeaways, Week 4 Appendix A and editorial allocation/navigation | Draft; G1/G2/G3/P5 not completed |
| Five-week draft response in this working chat | Full Weeks 1, 2, 3, 5 and 6 | Upstream draft, not signed off; this package is a rendering handoff, not a new evidence review |
| Latest supplied five-week generation prompt | Vocabulary, reader voice, byline, exact takeaways, Option A separation | Its regulatory assertions are not evidence of approval |
| Corveo_BP_Reset_Andrew_List.docx | Content fields and distinction between required chapter images and optional programme hero | Working checklist; no completion inferred; legacy name and conditional Learn scope superseded by later instructions |
| IMG_8880.png to IMG_8885.png | Observed index/library composition, typography roles, artwork shapes, navigation and visible summaries | Photographed previews, not pixel-perfect design tokens, current code or opened-article templates |
| Corveo-Content-Architecture-Framework.html, v1.0, 28 July 2026 | Only the explicitly declared font families/weights as an earlier design precedent | Not used to restore outdated copy, governance or product scope |
| Legacy June 2026 engineering brief and working product summary | Planned HealthKit/manual inputs, paired BP values, provenance, record/graph rationale | Dated/working sources; old class assertions, vendor claims and implementation status not adopted |
| Official Apple/Lovable sources listed below | Current web/native boundary, permission limitation, paired BP and import/deletion concepts, file-based prompting | Technical verification only; not a privacy, regulatory or clinical certification |

## Proposed component breakdown

Use shared components rather than independent website/app content copies:

- ProgramIndex / WeekCard
- ChapterReader / ArticleHeader / ArticleArtwork / KeyTakeaway
- EditorialLibrary / PulseCover / InFocusRow / MissingArticleReader
- AppNavigation / WebsiteNavigation / ReviewToolbar
- BloodPressureGraph / ReadingList / ReadingDetail
- DateAndTimeOfDayFilters / DescriptiveAverage
- ManualReadingForm / AppleHealthDemo / RecordExportPreview
- DraftNotice / ReviewHoldNotice / ReviewerNotes

The component names are suggestions, not actual existing code. The proposed routes in the master prompt are likewise not a recovered URL inventory.

## Suggested data separation

`ContentRepository` reads the six shared chapter records and the editorial catalogue. `ReadingRepository` holds fictional, local preview records. `HealthDataAdapter` is a mock boundary. None of these names claims to be the production Corveo API.

Content, clinical observations, user access and approval state are distinct concerns. Do not store patient records in the public editorial CMS. Do not turn this JSON presentation model into a Payload collection definition or a FHIR-conformance claim. A future mapper must use the actual approved Payload schema and the current selected health-data profile.

The native integration should be separately specified and tested. Preserve the original measurement, time/offset, source identifiers, import timestamp, device/source provenance and amendments. When metadata is unavailable, retain that absence rather than invent it. Do not make timestamps for ingestion stand in for the measurement time.

## Mock adapter contract (proposal only)

```ts
// This contract intentionally does not return a readPermissionGranted boolean.
type ImportState =
  | 'browser_demo'
  | 'permission_step_finished'
  | 'no_readings_returned'
  | 'readings_received'
  | 'transport_error';

interface DemoHealthAdapter {
  mode: 'demo';
  previewPermissionStep(): Promise<{
    requestFlowFinished: boolean;
    readAccess: 'unknown';
  }>;
  previewImport(scenario: string): Promise<{
    state: ImportState;
    sampleIds: string[];
    deletedSampleIds: string[];
    demoOnly: true;
  }>;
}
```

Native implementation notes, not work completed by this package:

HealthKit read access is requested inside an appropriately configured native application. Completing its authorisation flow does not tell an app whether the user granted all requested read types. Empty query results are not proof of denial, and write-authorisation status is not a read-status check. Use truthful UI states that distinguish an attempted permission step, returned samples and transport failures. [T1]

Systolic and diastolic samples are represented together in a blood-pressure correlation. Preserve that association; a nearby independent heart-rate sample must not silently become the pulse for the BP event. [T2]

Anchored queries can return new and deleted objects since an earlier anchor. The production design must cover initial import, incremental changes, exact re-delivery, deletion handling and failed uploads before advancing a durable cursor. No cadence or instant-background-delivery guarantee is made here. [T3]

The prototype does not contain a native entitlement, genuine permission sheet, iOS build, encrypted health backend, patient identity, audit service or live import. A PWA is not itself a HealthKit integration; a native wrapper needs an explicitly engineered native adapter. Lovable's documented output is web applications, not a generated React Native project. [T4]

## Fictional dataset

`04_FICTIONAL_READINGS.json` contains 148 complete paired observations across 42 calendar days, 5 August to 15 September 2026, using a frozen demo date. There are 39 dates with readings, deliberate missing sessions/dates, manual and Apple Health labels, and optional absent pulse values.

Every record is marked synthetic. The schedule and values demonstrate layouts and state handling, not recommendations, targets, expected physiology or a treatment response. No real patient information is present.

The default seven-calendar-day window is 9-15 September 2026 (inclusive, original measurement-local dates). It contains 26 records. Fixture arithmetic: systolic mean 135.3846153846154; diastolic mean 83.03846153846153 mmHg. A one-decimal display is 135.4 / 83.0, labelled as an arithmetic summary of those displayed fictional records. This is a test oracle, not clinical advice or a diagnostic averaging protocol.

The dataset includes separate test cases for an exact duplicate delivery, a distinct sample with matching values, an incomplete pair and transport/no-data states. Do not add test-only incomplete records to the baseline record and then report them as successfully imported complete pairs.

## Reading display rules

A chart is accompanied by an accessible list/table. Numeric measurements can appear in the record screens because they are the purpose of those screens; this does not override the prohibition on readable BP numbers in decorative chapter imagery. No clinical threshold, colour zone, status, warning or explanatory text is generated from a sample's value.

Date filters, time-of-day filters, source filters, counts, means and exports use the same active record selection. Preserve individual measurements, including distinct readings with equal values. No zero-filling, hidden favourable selection, or automatic removal of unusual measurements.

Time-of-day labels in the fixture are explicit demonstration tags. A production choice about automatic clock windows, travel timezone handling or clinician-requested schedules has not been approved. Exact measurement time remains visible even when a tag is shown.

The manual form validates structure and formats. Any range restriction or clinical sanity rule requires separate review; do not invent such thresholds in this mock-up. A raw imported record is not silently overwritten by a form edit or a descriptive calculation.

## Content and review holds

All six chapters remain drafts. G1, G2 and G3 are category labels, not completed approvals. No reviewer/date is invented. The byline is the owner's requested draft attribution.

Week 4 is the v0.7 source version, not the shorter example embedded in the later generation prompt. It is included to make all six layouts reviewable. Its card summary, standfirst and body contain unresolved blanket reassurance. Preserve the supplied source while making its review hold visible on the card and before/within the opened chapter. It must not be circulated as approved advice. The presence of context such as caffeine, discomfort or stress does not establish an explanation for an individual reading or symptom.

Week 3's locked takeaway is also source-preserved and visibly flagged for reliability wording. The phrase about a week of readings is not a quality guarantee. Week 6's absolute closing wording remains a draft statement, not a validated behaviour or health claim.

Week 2 carries the previously disclosed drafting clarification separating caffeine/exercise preparation from rest, silence and bladder-emptying instructions. Its exact technique descriptions still need G2 review. This handoff does not silently replace them with new clinical material.

No clinical references were reverified as part of this packaging task. The preceding response's source suggestions remain candidate references. There is no completed claim-to-reference verification register in this package. Native HealthKit technical verification must not be mistaken for G2 review of the articles.

## App and website implementation checks

Keep the programme index complete and ordinary navigation functional. Do not require six weeks to elapse to inspect Week 6. Any lock state is a separately marked design proposal. Read/bookmark/availability/clinical-approval states are independent.

Website and app share content objects. Presentation adaptations such as image crop, responsive header and nav layout are permitted; removing paragraphs for mobile or paraphrasing a locked takeaway is not.

The user's screenshot showing an obsolete conditional Learn footer is not evidence of a scope reversal. Use the latest supplied v0.7 direction that Learn appears in-app, without pretending its unsupplied articles are already written.

During article reading, do not show a sidebar card with the person's latest measurement. An editorial reference to a general concept must not become an assessment of visible personal values. Likewise, entering or importing a reading must not trigger a selected article or reassurance based on its value.

## Release and privacy dependencies (not performed)

A future production build needs the actual intended-purpose/release decision, clinical sign-off, claim-matched references, approved image licences, approved CMS model, native implementation, scoped consent, authenticated per-user data service, encryption, access rules, retention/deletion, auditability and a documented incident/support model.

Do not add trackers, ad pixels, session replay or analytics containing entered numbers to the prototype. Use no real records or credentials in Lovable chat. Preview sharing must be checked by the owner; an obscured URL, robots file or noindex tag is not access control.

This package neither installs Lovable nor creates a project, publishes a website, changes Payload/Vercel, updates another chat or synchronises an HQ register.

## Practical acceptance walkthrough

1. Open Website and App modes at phone and desktop widths. All six cards are visible through normal scrolling; the final card is not covered by navigation.
2. Open all six chapters. Confirm exact titles/order, complete paragraphs, images, byline draft status, takeaways and next-week pointers. Week 6 has no next-week field.
3. Compare website/app copies. Only layout differs. Check actual font loading; record whether existing project fonts or the earlier HTML precedent was used.
4. Open Learn. Confirm six Pulse and four In Focus titles, honest missing-body messages and no editorial-to-programme upsell module.
5. Open My Heart Record. Check the frozen demo date, 26 default-window records, means, units and timestamp/source labels. Filter by morning/evening, source and date; graph and list remain consistent.
6. Record a fictional manual entry and confirm its detail view and exact values. Null pulse stays absent. Nothing is transmitted to a server.
7. Try Apple Health no-data, duplicate, distinct-equal-values, incomplete-pair and failure scenarios. Confirm that no UI invents read permission status or claims genuine synchronisation.
8. Preview/export the selected record. Ensure every exported row belongs to the active selection and the output is labelled fictional; no clinical assessment or silent send occurs.
9. Inspect text enlargement, keyboard focus, touch areas, image alt handling, empty states and bottom-navigation clearance.
10. Record actual test results and remaining work. Do not mark unexecuted tests as passed, and do not equate UI acceptance with G1/G2/G3 or clinical approval.

## Technical sources checked for this handoff

[T1] Apple Developer, Authorizing access to health data and authorizationStatus(for:), consulted 16 September 2026.
`https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data`
`https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:)`

[T2] Apple Developer, bloodPressureDiastolic / bloodPressure correlation, consulted 16 September 2026.
`https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/bloodpressurediastolic`

[T3] Apple Developer, HKAnchoredObjectQuery, consulted 16 September 2026.
`https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery`

[T4] Lovable Documentation, FAQ: mobile app development and current stack, consulted 16 September 2026.
`https://docs.lovable.dev/introduction/faq`

[T5] Lovable Documentation, Dashboard overview and Design guidance; Lovable, Introducing Lovable File Uploads, consulted 16 September 2026.
`https://docs.lovable.dev/introduction/dashboard-overview`
`https://docs.lovable.dev/features/design-guidance`
`https://lovable.dev/blog/lovable-file-uploads`

These sources support technical platform facts, not the clinical article claims or regulatory classification.

## Material handoff summary

Workstream: 04.05 - PROGRAM | BP BASICS.
Asset/title and verified ID: Lovable prototype handoff v0.1; company asset ID unassigned.
Source/current version: v0.7 pathway; the five-week chat draft; latest source prompt; six screenshots; checklist; earlier typography precedent.
What changed: content packaged for two surfaces; proposed routes/components and imagery briefs; synthetic readings and mock-native boundary added; review holds preserved.
Decisions explicitly approved: owner requested this mock-up and all six weeks plus Apple Health/record/graph context. No production approval is inferred.
Proposals/unresolved: reader layout, image assets, exact current-app font, route/schema design, descriptive averaging method and complete independent Learn bodies.
Evidence checks: source/provenance packaging and current technical documentation checks completed; clinical evidence review pending.
Regulatory/intended-purpose issues: no legal classification conclusion; raw-data display and educational adjacency require actual release review.
Clinical review status: pending; no reviewer/date supplied for release.
Affected assets: six BPB chapters, ten catalogue records and proposed record screens.
Next action: owner uploads package/references to Lovable for a private build; developer reviews native/data dependencies separately.
HQ/register entry: not performed. An explicit record would be needed outside this package.

Additional primary source for T1: `https://developer.apple.com/documentation/healthkit/hkauthorizationstatus` (Apple documentation; consulted 16 September 2026). It distinguishes save/write authorisation from the intentionally undisclosed read-permission outcome.

Naming clarification: My Heart Record refers to the proposed Corveo BP-record area. It does not claim a connection to the Australian government My Health Record system.

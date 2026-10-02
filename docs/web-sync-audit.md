# Web Sync Audit

**Date**: 2 October 2026
**Purpose**: Divergence audit between SwiftUI native app and React web prototype
**Direction**: SwiftUI is source of truth; React is target

---

## 1. Screen Inventory

| Screen | Swift file | React file | Status |
|--------|------------|------------|--------|
| **Journey** | | | |
| Welcome | `JourneyViews.swift:WelcomeView` | `journey/Onboarding/Welcome.tsx` | match |
| Intro | `JourneyViews.swift:IntroView` | `journey/Onboarding/Intro.tsx` | drifted |
| Signup | `AuthViews.swift:SignupView` | `journey/Signup/Signup.tsx` | match |
| Consent | `JourneyViews.swift:ConsentView` | `journey/Consent/Consent.tsx` | match |
| Connect | `JourneyViews.swift:ConnectView` | `journey/HealthKitAuth/Connect.tsx` | drifted |
| Health Auth | `JourneyViews.swift:HealthAuthView` | `journey/HealthKitAuth/HealthAuth.tsx` | match |
| First Capture | `JourneyViews.swift:FirstCaptureView` | `journey/FirstCapture/FirstCapture.tsx` | match |
| Result | `JourneyViews.swift:ResultView` | `journey/FirstCapture/Result.tsx` | match |
| Cadence | `JourneyViews.swift:CadenceView` | `journey/FirstCapture/Cadence.tsx` | drifted |
| **Tabs** | | | |
| Record | `RecordViews.swift:RecordView` | `tabs/Record/Record.tsx` | drifted |
| Program | `ProgramViews.swift:ProgramView` | `tabs/Program/Program.tsx` | drifted |
| Learn | `LearnViews.swift:LearnView` | `tabs/Education/Education.tsx` | drifted |
| **Program content** | | | |
| Chapter reader | `EducationProgramViews.swift:EducationChapterReader` | `tabs/Program/Chapter.tsx` | drifted |
| Program browse | `ProgramViews.swift:ProgramBrowseView` | `tabs/Program/ProgramIndex.tsx` | match |
| Program detail | `ProgramViews.swift:ProgramDetailView` | `tabs/Program/ProgramDetail.tsx` | match |
| **Learn content** | | | |
| Pulse viewer | `EducationLearnViews.swift:EditorialPulseViewer` | `tabs/Education/PulseViewer.tsx` | drifted |
| In Focus reader | `EducationLearnViews.swift:EditorialInFocusReader` | `tabs/Education/InFocusArticle.tsx` | drifted |
| **Settings** | | | |
| Settings main | `SettingsViews.swift:SettingsView` | `settings/Settings.tsx` | drifted |
| Apple Health | `SettingsViews.swift:AppleHealthSettingsView` | `settings/AppleHealth.tsx` | match |
| About | `SettingsViews.swift:AboutView` | `settings/About.tsx` | match |
| Your Data | `SettingsViews.swift:YourDataView` | `settings/YourData.tsx` | match |
| Reminders | `SettingsViews.swift:RemindersView` | `settings/Reminder.tsx` | drifted |
| Account | `SettingsViews.swift:AccountView` | via AppleHealth.tsx | drifted |
| Validated Cuffs | `SettingsViews.swift:ValidatedCuffsView` | `settings/ValidatedCuffs.tsx` | match |
| Readings Arrive | n/a (via Connect) | `settings/ReadingsArrive.tsx` | react-only |
| **Other** | | | |
| Manual Entry | `RecordViews.swift:ManualEntryView` | `tabs/Record/ManualEntry.tsx` | match |
| Behind the Scenes | n/a | `behind/BehindTheScenes.tsx` | react-only |
| Sign In | `AuthViews.swift:SignInView` | via Signup.tsx | match |

---

## 2. Drifted Screen Details

### Intro (Journey step 1)
- **Swift**: Three cards with title+body pairs: "Why home readings matter", "How to measure well", "What this program is"
- **React**: Three highlight rows with icon+title+sub format
- **Action**: Sync React to use card format with full body text per Swift

### Connect (Journey step 3)
- **Swift**: Includes setup reads section with three Pulse articles when HealthKit chosen
- **React**: Has `setupReadsHeading`/`setupReadsIntro` but implementation differs
- **Action**: Verify setup reads rendering matches Swift behaviour

### Cadence (Journey step 5)
- **Swift**: Has reminder toggle and note about reminders
- **React**: Missing reminder toggle and cadence-specific copy
- **Action**: Add reminder toggle, sync cadence option copy

### Record tab
- **Swift**: Has time-of-day filtering on history, sync button, rejected readings display
- **React**: Has Day/Night filter on chart via Select, different sync UI
- **Action**: Verify filter behaviour matches; sync rejected readings display

### Program tab
- **Swift**: Uses `EducationProgramViews` with review hold markers, preview banner
- **React**: Has basic program display, needs review notice integration
- **Action**: Add review hold markers and preview banner (Phase 4)

### Learn tab
- **Swift**: Uses `EducationLearnViews` with editorial catalogue from JSON
- **React**: Uses same JSON but may have layout differences
- **Action**: Verify catalogue rendering matches Swift

### Chapter reader
- **Swift**: Full `EducationChapterReader` with sections, takeaway, cross-links, review notices
- **React**: Has `Chapter.tsx` but needs cross-link and review notice sync
- **Action**: Sync cross-links section, add review notices

### Pulse viewer
- **Swift**: Full-screen viewer with counter, body from pulse-articles.json
- **React**: Has viewer but verify body rendering and navigation matches
- **Action**: Verify counter format, swipe behaviour

### Settings main
- **Swift**: Profile section with program week, reading count, rhythm, consent
- **React**: Different structure with grouped menu
- **Action**: Sync profile section structure

### Reminders
- **Swift**: Full reminder settings with rhythm display, test reminder, denied note
- **React**: Simpler reminder screen
- **Action**: Add rhythm display and test reminder

---

## 3. Structural Divergence

### Swift-only screens
- **Review hold views** (`ReviewHoldViews.swift`): Preview banner, review hold markers, Week 4 interstitial, chapter holds notice, takeaway review note
- **Editorial education views** (`EducationProgramViews.swift`, `EducationLearnViews.swift`): Dedicated readers for JSON-based content

### React-only screens
- **Readings Arrive** (`settings/ReadingsArrive.tsx`): Separate settings page for changing how readings arrive (Swift handles inline in Connect)
- **Behind the Scenes** (`behind/BehindTheScenes.tsx`): Web-only presentation surface

### Navigation differences
- Swift uses `Router` with `AppRoute` enum and `NavigationStack`
- React uses react-router with path-based routing
- Tab bar visibility logic matches (tab destinations show bar, modal destinations hide it)

---

## 4. Design Token Mismatches

| Token | Swift (`Tokens.swift`) | React (`tokens.css`) | Action |
|-------|------------------------|----------------------|--------|
| text-tertiary | `0x808080` | `#666666` | **Mismatch** - React is bumped for WCAG AA |
| text-label | 12px | 14px | **Mismatch** - React bumped for 60+ readability |
| text-body-sm | 14px | 16px | **Mismatch** - React bumped for 60+ readability |

**Note**: The React bumps are documented accessibility improvements. The Swift version follows the Figma tokens exactly. Both are valid for their platform; the prototype should keep the bumped values for web readability.

### Colour tokens (matching)
- surface-action: `#000` / `0x000000` - match
- surface-color-1: `#3e4fb5` / `0x3e4fb5` - match
- surface-color-2: `#9e6850` / `0x9e6850` - match
- surface-color-3: `#1c7a8c` / `0x1c7a8c` - match
- chart-teal: `#00839b` / `0x00839b` - match
- page: `#f2ede9` / `0xf2ede9` - match
- card: `#fff` / `0xffffff` - match

### Spacing tokens (matching)
- All spacing values (3xs through 2xl) match between platforms

---

## 5. Content Sources

### SwiftUI app uses:
- `ios/BPReset/Resources/02_CONTENT_ALL_SIX_WEEKS.json` - six-week program content
- Pulse bodies loaded via `EducationContent.swift` which reads `pulse-articles.json` equivalent

### React app uses:
- `src/copy/02_CONTENT_ALL_SIX_WEEKS.json` - same content
- `src/copy/pulse-articles.json` - Pulse article bodies (CORV-EDU-002 v0.4)

### Verification needed:
- Confirm both JSON files are identical (byte-for-byte)
- `fictional-readings-v0.1.json` exists in `Lovable-Andrew/` but needs verification in React

---

## 6. Copy Drift

### Journey intro cards
- **Swift** (`Copy.swift`): Three cards with full paragraphs
- **React** (`journey.ts`): Three highlights with short titles/subs
- **Action**: Sync React to use Swift card copy

### Cadence options
- **Swift**: "Morning and evening", "Once a day", "A few times a week" with body text
- **React**: Same titles but verify body text matches

### Review notices (missing in React)
- `previewBanner`: "This content is in draft..."
- `week4Notice`: Week 4 interstitial text
- Review hold markers on chapters
- **Action**: Implement in Phase 4

---

## 7. Summary and Checkpoint

### Structural divergence found
1. **Review hold system** - Swift has complete implementation, React needs port
2. **Settings structure** - React has separate Readings Arrive page; Swift handles inline
3. **Behind the Scenes** - React-only, can remain

### Recommendation
Divergence is confined to:
- Copy alignment (card text, review notices)
- Layout adjustments (intro cards format)
- Review notice system (Phase 4)
- Token values are deliberately different for accessibility

**Proceed to Phase 2** - Port drifted screens starting with copy alignment.

---

## 8. Phase 5 — Access Options

The deployment is publicly reachable with no authentication. Options:

### Option 1: Vercel Deployment Protection
- **Requires**: Vercel Pro or Enterprise plan
- **Provides**: Password protection or Vercel Authentication (team SSO)
- **Implementation**: Configure in Vercel dashboard → Settings → Deployment Protection
- **Notes**: Strong protection, proper access control

### Option 2: Shared-Password Gate in App
- **Requires**: Code change
- **Provides**: Simple password prompt before app loads
- **Implementation**: Add a gate component that checks localStorage for auth state
- **Notes**: Weak protection (password in client bundle), stops casual discovery only

### Option 3: Public with Unmissable Preview Banner
- **Requires**: Nothing additional (current state + Phase 4)
- **Provides**: Clear visual indication of draft status
- **Implementation**: Already implemented via PreviewBanner component
- **Notes**: Not access control, just disclosure

### Current State
- `<meta name="robots" content="noindex, nofollow">` added to prevent indexing
- PreviewBanner visible on Program tab when content is unpublishable
- No authentication gate implemented

**Recommendation**: Report options to client; do not implement auth without explicit request.

---

## 9. Porting Completed

### Copy synced
- Intro screen: Changed from icon+title+subtitle highlights to three cards with full body text
- Cadence screen: Added reminder toggle, synced copy to match Swift

### Review notices added
- PreviewBanner on Program tab (shows when content is draft)
- ReviewHoldMarker on chapter rows (shows when chapter has holds)
- ChapterDraftNotice on chapter reader (shows for unpublishable chapters)
- TakeawayReviewNote next to takeaways (shows when chapter has review holds)

### HTML fixes
- Added `<meta name="robots" content="noindex, nofollow">`
- Viewport already correct (no user-scalable=no to remove)

### Content verified
- `src/copy/02_CONTENT_ALL_SIX_WEEKS.json` identical to `ios/BPReset/Resources/02_CONTENT_ALL_SIX_WEEKS.json`
- Hash verification test already exists in `education-content.test.ts`

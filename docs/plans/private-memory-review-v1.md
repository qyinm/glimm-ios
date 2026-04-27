# Plan: Private Memory Review v1

Status: Draft
Target milestone: v1.4
Working title: Remember, Not Just Capture

## Problem

glimm already has enough capture surface to start: photo capture, optional text, voice notes, location, local notifications, timeline, calendar, map, and export. The next product risk is not capture breadth. The next risk is that captured memories do not become more valuable over time.

Setlog owns the social, short-video, shared-day loop. glimm should not copy that lane. glimm should win as a private memory camera: the app that makes a quiet archive feel alive again after days and weeks of use.

## User Promise

After a user has recorded memories for at least two weeks, opening glimm should make them feel:

> I forgot this happened, but I am glad I kept it.

## Non-Goals

- No friend graph.
- No public feed.
- No likes, comments, reactions, or follower mechanics.
- No setlog-style split-screen social vlog export.
- No server dependency.
- No AI summarization in this milestone.

## Proposed Scope

### 1. Define the Review Selection Model

Add a typed review model in `ReviewOrganizer` before changing UI:

- `ReviewHome`
- `ReviewSection`
- `ReviewSectionReason`
- `ReviewNotificationCandidate`

The first v1.4 ranking thesis is:

- rediscovery beats recency
- exact calendar echoes beat generic lists
- memories with note, voice, or location context are more likely to feel meaningful
- sparse archives should still show one useful old memory instead of an empty state

Selection rules:

- hero: newest memory, for continuity with the current app
- on this day: exact month/day match from a previous year, excluding hero
- fallback memory: nearest older memory at least 7 days old, excluding hero
- recent week: compact supporting section only, never the main emotional hook
- voice memories: most recent memories with `audioData != nil`
- location memories: memories with non-empty `locationName`
- frequent places: existing place groups sorted by count, then recency

### 2. Turn Review into a Memory Home

Replace the current basic highlights-first Review tab with a more intentional review home:

- hero memory from recent captures
- "On this day" section using the exact/fallback rules above
- recent week strip
- memories with voice notes
- memories with location context
- most visited places

The screen should stay quiet and private. It should not feel like a social feed. `ReviewView` should render the `ReviewHome` value model and avoid embedding business rules in SwiftUI view bodies.

### 3. Add Typed Notification Routing First

Before adding review prompts, split notification scheduling and tap routing by kind:

- capture prompt
- review home prompt
- memory detail prompt

Notification identifiers must be namespaced by kind. Scheduling one kind must not erase the other kind. Taps must inspect notification `userInfo` and route to the correct destination instead of always opening the camera.

### 4. Add Review Notification Hooks

Add local, opt-in review prompts alongside capture prompts:

- "A memory from last week"
- "You saved a voice note here"
- "A place you have returned to"

These should be low-frequency and derived from local SwiftData content. They should reuse the existing local notification infrastructure where possible, but with a merged quiet-cadence budget so capture and review prompts do not stack.

Lock-screen copy must be generic by default. Do not include place names or routines in notification text unless the user explicitly enables richer review prompts later.

### 5. Upgrade Memory Detail into an Archive Page

The detail screen should make the memory easier to re-enter:

- keep the image primary
- show date, time, location, note, and audio cleanly
- surface nearby memories from the same day or place
- keep editing and delete actions available but secondary

Do not cram related memories into the current bottom gradient overlay. Choose a two-zone layout: image-first header plus scrollable archive content below. Related memories should live in the scrollable content area.

### 6. Keep Export and Local Ownership Visible

Settings already supports Photos export and ZIP backup. The review milestone should preserve the positioning that memories are owned by the user. Any new review feature must work offline and without external API calls.

## Existing Code To Reuse

- `glimm/Views/ReviewView.swift`
- `glimm/Services/ReviewOrganizer.swift`
- `glimm/Views/MemoryDetailView.swift`
- `glimm/Services/NotificationService.swift`
- `glimm/Services/NotificationScheduleBuilder.swift`
- `glimm/Views/CalendarView.swift`
- `glimm/Components/MemoryCard.swift`
- `glimm/Components/AudioNoteComposer.swift`
- `glimm/Components/ClusteredPlacesMapView.swift`

## Data Model Changes

Prefer no `Memory` model migration for v1.4.

For review prompt preferences, use `@AppStorage` first unless cross-device sync is explicitly required:

- `reviewPromptsEnabled: Bool`
- `reviewPromptFrequencyRaw: String?`

Adding fields to `Settings` is still a CloudKit-backed SwiftData schema evolution because `Settings` is in the shared `ModelContainer`. If this route is chosen, validate install-over-upgrade and iCloud sync behavior before release.

Avoid adding derived review data to `Memory`. Review sections should be computed from existing memories by `ReviewOrganizer`.

## UX Constraints

- Light mode only, matching current app direction.
- No nested cards inside cards.
- Review should feel calm, not gamified.
- Empty states must explain what will appear after more memories exist.
- All user-facing copy must be localized across supported `.lproj` files.

## Technical Constraints

- Local-first. No external backend or API.
- CloudKit-backed SwiftData remains the persistence layer.
- Notification scheduling must not spam the user.
- Capture and review notification identifiers must be namespaced.
- Notification tap routing must support capture, review home, and memory detail destinations.
- Scheduling review prompts must not call `removeAllPendingNotificationRequests()`.
- Review computations should be deterministic and testable.
- Keep business logic in services, not in SwiftUI view bodies.

## Test Plan

Add unit tests for:

- `ReviewHome` section selection and ordering
- review section selection
- "on this day" exact match and nearest-older fallback behavior
- voice-note memory grouping
- place-based review grouping
- review notification candidate generation
- disabled review prompts producing no notification candidates
- capture and review notification identifier coexistence
- notification tap routing by payload kind
- generic lock-screen copy for place-based review prompts
- localization key completeness across all supported `.lproj` files

Manual validation:

- empty archive
- 1 memory
- 7 days of memories
- 30+ memories with mixed notes, voice, and location
- notification permission denied
- location missing
- audio missing
- review prompt tapped from cold launch
- review prompt tapped while app is foregrounded
- capture prompts and review prompts scheduled at the same time window

## Success Criteria

- A user with 14 days of memories sees at least three meaningful review sections.
- A user with sparse data still sees a graceful review home, not an empty dashboard.
- Capture notifications and review notifications can coexist without exceeding a quiet cadence.
- No new external dependency is introduced.
- Existing `NotificationScheduleBuilderTests` and `ReviewOrganizerTests` continue to pass.

## Open Questions

- Should review prompts be offered only after the user has enough memories? Recommended: yes, offer after 7 saved memories or 7 days since first memory.
- Should nearby memories in detail be based on same day first, same place first, or both? Recommended: same day first, then same place.
- How much should the Review tab change visually in v1.4 versus staying close to current components?

## /autoplan Review Report

Base branch: `main`
UI scope: yes
DX scope: no, this is not a developer-facing feature.
Outside voice: Codex CLI only. Claude subagent unavailable in this session because subagent spawning was not explicitly authorized by the user-level request.

### Premises

1. The next product risk is review value, not capture breadth. Accepted.
2. glimm should not copy Setlog's social split-screen loop. Accepted.
3. The v1.4 milestone should preserve local-first, private archive positioning. Accepted.
4. Review notifications are valuable only if they are quiet, private, and correctly routed. Added during review.

### CEO Review

The strategy is directionally right. The weak part was that the original plan described inventory sections more than rediscovery logic. The revised plan now makes rediscovery the ranking thesis and demotes recent-week content to a supporting section.

NOT in scope:

- social graph
- AI summarization
- public sharing
- video compilation
- server-backed notification logic

What already exists:

- Timeline and card rendering: `HomeView`, `MemoryCard`
- Review tab shell: `ReviewView`
- Review grouping service: `ReviewOrganizer`
- Place browsing: `PlaceMemoryGroup`, `ClusteredPlacesMapView`
- Notification scheduling: `NotificationService`, `NotificationScheduleBuilder`
- Archive detail base: `MemoryDetailView`

### Design Review

Design score: 7/10 after revision.

Main fix: avoid trying to turn the existing full-screen black photo viewer into a dense archive page. The plan now chooses a two-zone memory detail layout: image-first header plus scrollable archive content.

Design risks:

- Review home can become a cluttered dashboard if every section has equal weight.
- Recent-week content can weaken the "rediscovery" promise if it dominates the screen.
- Place-based notification copy can feel creepy if lock-screen text reveals routines.

### Engineering Review

Engineering score: 7/10 after revision.

Architecture diagram:

```text
Memory / Settings
      |
      v
ReviewOrganizer
      |
      +--> ReviewHome
      |      +--> ReviewSection
      |      +--> ReviewSectionReason
      |
      +--> ReviewNotificationCandidate
                 |
                 v
NotificationScheduleBuilder / NotificationService
                 |
                 v
Typed notification payloads
                 |
                 v
AppDelegate -> MainTabView routing

ReviewView --------> renders ReviewHome
MemoryDetailView --> image header + archive content + related memories
```

Critical engineering findings:

- Current notification taps always open capture. Review prompts need typed routing before they ship.
- Current notification scheduling cancels all pending requests. Capture and review schedules need identifier namespaces and prefix-based cancellation.
- Adding fields to `Settings` is still a CloudKit schema evolution. Use `@AppStorage` for review prompt preferences unless sync is required.
- `ReviewOrganizer` must grow from `ReviewHighlights` into a stable `ReviewHome` value model before UI work starts.

Failure modes registry:

| Failure | Impact | Mitigation |
|---|---|---|
| Review notification opens camera | User taps a memory prompt and lands in capture | Add typed notification payload routing |
| Capture reschedule deletes review prompts | Review prompts silently stop working | Namespace identifiers and cancel by kind |
| Review home shows only recent memories | Product promise feels false | Use age/context ranking rules |
| Place prompt reveals routine on lock screen | Privacy trust damage | Generic copy by default |
| Related memories crammed into overlay | Detail screen becomes unreadable | Two-zone detail layout |
| Localization keys missing | Non-English builds show raw keys or fallback text | Add localization completeness check |

### Test Diagram

| Flow / codepath | Test type | Required coverage |
|---|---|---|
| `ReviewOrganizer.reviewHome` section ordering | Unit | 14-day mixed archive returns at least three sections |
| Exact "on this day" | Unit | Same month/day from previous year wins |
| Nearest older fallback | Unit | Older than 7 days, excludes hero |
| Voice section | Unit | Includes only memories with `audioData` |
| Place sections | Unit | Reuses coordinate bucket behavior |
| Review candidate generation | Unit | Emits candidates only when enabled and enough memories exist |
| Notification coexistence | Unit with scheduler abstraction | Capture and review identifiers both remain pending |
| Notification tap routing | Unit or integration seam | Capture opens capture, review opens review/detail |
| Sparse archive | UI/manual | 0, 1, 7 memories render gracefully |
| Localization | Script/test | New keys exist in en, ko, ja, fr, de |

### Decision Audit Trail

| # | Phase | Decision | Classification | Principle | Rationale | Rejected |
|---|---|---|---|---|---|---|
| 1 | CEO | Keep Private Memory Review as v1.4 milestone | Mechanical | Bias toward action | It directly strengthens glimm's non-social wedge | More capture features |
| 2 | CEO | Make rediscovery ranking explicit | Mechanical | Choose completeness | Sections need a reason to create memory value | Inventory-only review sections |
| 3 | Design | Use two-zone memory detail layout | Mechanical | Explicit over clever | Current overlay cannot hold archive content cleanly | Add related memories into gradient overlay |
| 4 | Eng | Add typed notification routing before review prompts | Mechanical | Choose completeness | Existing tap path opens camera for every notification | Ship review prompts on current route |
| 5 | Eng | Namespace notification identifiers and cancel by kind | Mechanical | Choose completeness | Current reschedule deletes all pending prompts | Keep `removeAllPendingNotificationRequests()` |
| 6 | Eng | Use `@AppStorage` for review prompt prefs first | Taste | Pragmatic | Avoid CloudKit schema evolution unless sync is required | Add `Settings` fields immediately |
| 7 | Eng | Exact on-this-day first, nearest older fallback second | Mechanical | Explicit over clever | Closes an open semantic question before implementation | Leave behavior open |

### Cross-Phase Themes

The repeated theme is specificity. The product idea is good, but it only becomes implementable when "private rediscovery" is converted into deterministic selection rules, typed notification behavior, and a calm UI hierarchy.

### Recommended Implementation Order

1. Add `ReviewHome` and `ReviewSection` models in `ReviewOrganizer`.
2. Add unit tests for section selection and fallback behavior.
3. Refactor `ReviewView` to render `ReviewHome`.
4. Add typed notification identifiers and routing without review prompts.
5. Add review notification candidate generation and tests.
6. Add review prompt settings using `@AppStorage`.
7. Update `MemoryDetailView` to two-zone archive layout.
8. Add localization keys across all supported languages.

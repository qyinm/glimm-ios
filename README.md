# glimm

> A quiet iPhone journal that interrupts you at random and asks one simple question: what does life look like right now?

glimm is a minimal, local-first iOS app for collecting real moments instead of curated ones. It uses local notifications to prompt capture throughout the day, then lets you save a photo with optional text, voice, and place context. Over time, those moments turn into a private timeline, a review surface, and a map of where your life happened.

## Why glimm exists

Most journaling apps ask users to remember to log. glimm does the opposite.

It nudges first, captures fast, and gets out of the way.

The product is built around a few constraints:

- low-friction capture
- on-device storage first
- no external API dependency
- iCloud sync when available
- lightweight review instead of heavy productivity mechanics

## Highlights

- In-app capture flow with single-camera and dual-camera support
- Capture review sheet with optional note, voice note, and location tag
- Voice notes up to 60 seconds
- Timeline grouped by day
- Review tab with highlights, place-based browsing, and clustered map view
- Calendar browser for navigating older memories
- Configurable local notification cadence
- Photos export and ZIP backup with metadata
- Multi-language support: English, Korean, Japanese, French, German

## Product Shape

### Capture

The main interaction starts from a local notification or the floating capture button in the tab bar. Users shoot first, then optionally enrich the memory before saving.

Each memory can include:

- a photo
- a short text note
- a recorded voice note
- an optional location name and coordinates

### Review

glimm is not only a capture app. It also helps users revisit what they have collected.

The app currently offers:

- a timeline view grouped by day
- review highlights for recent and older memories
- place grouping based on name plus rounded coordinates
- a clustered map surface for spatial browsing
- a calendar view for date-based lookup

### Notifications

Notification scheduling is local and configurable.

Users can choose:

- an active time window
- interval-based prompts
- a fixed daily count mode

The scheduler generates the next 7 days and preserves a minimum 30-minute gap between prompts.

## Tech Stack

- SwiftUI
- SwiftData
- CloudKit-backed SwiftData sync
- AVFoundation
- MapKit + CoreLocation
- UserNotifications

## Architecture Notes

### Persistence

The app uses SwiftData as the primary store. The shared model container is configured with `cloudKitDatabase: .automatic`, so memories and settings can sync through iCloud without introducing a custom backend.

Core models:

- [`glimm/Models/Memory.swift`](./glimm/Models/Memory.swift)
- [`glimm/Models/Settings.swift`](./glimm/Models/Settings.swift)

### Services

Domain logic is kept in small service-style units:

- camera orchestration: [`glimm/Services/DualCaptureService.swift`](./glimm/Services/DualCaptureService.swift)
- local notifications: [`glimm/Services/NotificationService.swift`](./glimm/Services/NotificationService.swift)
- notification schedule generation: [`glimm/Services/NotificationScheduleBuilder.swift`](./glimm/Services/NotificationScheduleBuilder.swift)
- export / backup: [`glimm/Services/ExportService.swift`](./glimm/Services/ExportService.swift)
- derived review grouping: [`glimm/Services/ReviewOrganizer.swift`](./glimm/Services/ReviewOrganizer.swift)
- location lookup: [`glimm/Services/LocationService.swift`](./glimm/Services/LocationService.swift)

### App Structure

```text
glimm/
  Components/    Reusable SwiftUI UI, media, and editor components
  Models/        SwiftData models and notification cadence types
  Services/      Camera, export, notification, review, and location logic
  Views/         User-facing screens and onboarding flow
  *.lproj/       Localized strings
glimmTests/      Unit tests
docs/            Release notes
```

## Requirements

- Xcode with iOS simulator support
- iOS 18 deployment target for the app target
- Apple Developer signing if you want to validate CloudKit behavior on device

## Getting Started

### Open in Xcode

1. Open [`glimm.xcodeproj`](./glimm.xcodeproj).
2. Select the `glimm` scheme.
3. Run on an iOS 18 simulator or an iPhone.

### Build and test from the command line

```bash
xcodebuild -project glimm.xcodeproj -scheme glimm -destination 'platform=iOS Simulator,OS=18.0,name=iPhone 16' test
```

Useful Xcode shortcuts:

- `Cmd + B` build
- `Cmd + R` run
- `Cmd + U` test

## Permissions

glimm can request access to:

- Camera, for capture
- Microphone, for optional voice notes
- Location, for optional place tagging
- Notifications, for prompt scheduling
- Photo Library Add Only, for export to Photos

## Export and Backup

The app supports two export paths:

- export memories into a dedicated Photos album
- create a ZIP backup containing images, optional audio files, and `metadata.json`

This keeps the app usable as a private archive even without any custom server infrastructure.

## Testing

The current test suite focuses on the logic that is easiest to regress and hardest to spot visually:

- notification schedule generation
- minimum-gap enforcement
- highlight/revisit review grouping
- place grouping for nearby jitter vs genuinely separate locations

Relevant test files:

- [`glimmTests/NotificationScheduleBuilderTests.swift`](./glimmTests/NotificationScheduleBuilderTests.swift)
- [`glimmTests/ReviewOrganizerTests.swift`](./glimmTests/ReviewOrganizerTests.swift)

## Contributor Notes

- The app is intentionally light-mode only.
- There is no external backend API in this repository.
- New user-facing copy should be added across the supported `.lproj` string files.
- Release history lives in [`docs/changelog`](./docs/changelog).

## License

This project is available under the [MIT License](./LICENSE).

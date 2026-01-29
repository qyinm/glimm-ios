# CLAUDE.md

This file provides guidance to Claude Code when working with the glimm iOS app.

## Project Overview

**glimm** is a minimal journal iOS app that prompts users with random notifications to capture photos of their current moment, creating an authentic archive of daily life.

## Tech Stack

- **Platform**: iOS 17+
- **UI**: SwiftUI
- **Data**: SwiftData + CloudKit
- **Notifications**: UNUserNotificationCenter (local)
- **Camera**: PhotosUI + AVFoundation

## Commands

```bash
# Xcode shortcuts
Cmd + R              # Run
Cmd + B              # Build
Cmd + U              # Run tests
Cmd + Shift + K      # Clean

# Command line
xcodebuild -scheme glimm -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Design System

| Element | Value |
|---------|-------|
| Theme | Light mode only |
| Background | `#FFFFFF` (white) |
| Text | `#000000` (black) |
| Glass effect | `.ultraThinMaterial` |
| Card radius | 24pt |
| Button radius | 16pt |
| Input radius | 12pt |

### Glass Effect in SwiftUI
```swift
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 24))
```

## File Locations

| Need | Location |
|------|----------|
| New view | `glimm/Views/` |
| Data model | `glimm/Models/` |
| Services | `glimm/Services/` |
| UI components | `glimm/Components/` |
| Assets | `glimm/Assets.xcassets/` |

## Key Patterns

### SwiftData Model
```swift
@Model
final class Memory {
    var id: UUID
    @Attribute(.externalStorage) var imageData: Data?
    var note: String?
    var capturedAt: Date
}
```

### Query Data
```swift
@Query(sort: \Memory.capturedAt, order: .reverse)
private var memories: [Memory]
```

### Save Data
```swift
@Environment(\.modelContext) private var modelContext

func save() {
    let memory = Memory(imageData: data, note: note)
    modelContext.insert(memory)
}
```

## Important Notes

- **Light mode only** - No dark mode support
- **Local-first** - All data stored via SwiftData
- **CloudKit sync** - Automatic via SwiftData container
- **No external API** - Everything runs on device

## Git Workflow

- Conventional Commits: `feat:`, `fix:`, `refactor:`, `chore:`
- Branch prefixes: `feature/`, `fix/`, `refactor/`
- **NEVER** include `Co-Authored-By`

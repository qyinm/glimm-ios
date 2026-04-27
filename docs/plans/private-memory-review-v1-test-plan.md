# Test Plan: Private Memory Review v1

Parent plan: `docs/plans/private-memory-review-v1.md`

## Unit Tests

### ReviewOrganizer

- `reviewHomeReturnsSparseArchiveFallback`
- `reviewHomePrefersExactOnThisDayMatch`
- `reviewHomeFallsBackToNearestOlderMemoryAfterSevenDays`
- `reviewHomeExcludesHeroFromRediscoverySections`
- `reviewHomeIncludesVoiceMemoriesOnlyWhenAudioExists`
- `reviewHomeIncludesLocationMemoriesOnlyWhenLocationNameExists`
- `reviewHomeSortsFrequentPlacesByCountThenRecency`
- `reviewHomeProducesStableSectionIDs`

### Notification Scheduling

- `captureAndReviewNotificationsCanCoexist`
- `cancelCaptureNotificationsDoesNotCancelReviewNotifications`
- `cancelReviewNotificationsDoesNotCancelCaptureNotifications`
- `reviewCandidatesAreEmptyWhenDisabled`
- `reviewCandidatesRequireEnoughMemories`
- `reviewCandidatesUseGenericPlaceCopyByDefault`

### Notification Routing

- `captureNotificationOpensCapture`
- `reviewHomeNotificationOpensReviewTab`
- `memoryDetailNotificationOpensRequestedMemory`
- `unknownNotificationFallsBackSafely`

### Localization

- `allReviewHomeKeysExistInSupportedLocales`
- `allReviewNotificationKeysExistInSupportedLocales`
- `allArchiveDetailKeysExistInSupportedLocales`

## Manual QA Matrix

| Dataset | Expected result |
|---|---|
| 0 memories | Review home shows calm empty state |
| 1 memory | Hero appears, rediscovery sections stay hidden |
| 7 memories across 7 days | Sparse review home appears without fake sections |
| 14+ memories with notes, voice, and locations | At least three meaningful review sections appear |
| Multiple exact month/day matches | Newest historical exact match wins |
| No exact month/day match | Nearest older memory older than 7 days appears |
| Notification permission denied | Settings and review UI do not imply prompts are active |
| Capture and review prompts scheduled | Both prompt kinds remain pending |
| Review prompt tapped from cold launch | App opens the intended review destination |
| Review prompt tapped in foreground | App opens the intended review destination |

## Build Verification

Run from repo root:

```bash
xcodebuild -project glimm.xcodeproj -scheme glimm -destination 'platform=iOS Simulator,OS=18.0,name=iPhone 16' test
```

If the local simulator runtime differs, use the installed iOS 18+ simulator destination from `xcrun simctl list devices available`.

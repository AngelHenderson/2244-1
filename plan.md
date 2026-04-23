# Implementation Plan

To adjust the milestone progression logic to correctly scale tier abbreviations between `aa` and `bc` due to the shorter 9-step `z` and `bc` tiers:

## Proposed Changes

### `LeaderboardClient.swift`
- Introduce a new helper function `milestoneStep(for:)` which will wrap `milestoneIndex(for:)` and apply the required mathematical offset:
  - Subtract 1 from the step for all milestones in the `aa`-`bb` range.
  - Subtract 2 from the step for all milestones in the `bd`-`bz` range.
- Use `milestoneStep(for:)` in place of `milestoneIndex(for:)` when constructing `.highValue(step:)` `Tile` objects (such as in `ProfileSheets.swift` and `LeaderboardView.swift` logic) to ensure the visual markers (colors) like `1al` correctly map to the shifted indices (e.g. `512` instead of `1024`).

### `AchievementStore.swift`
- We will audit `tileTiers`, `tileTierRewards`, and `journeyAchievements` to ensure their tier definitions are accurately synchronized with the new non-linear mapping. If `1al` and `873bz` need any visual representations updated or re-indexed inside `AchievementStore`, we will apply the exact same -1 and -2 offsets to the indices used to resolve their tile graphics or rewards.

Please approve this plan so I can begin execution.

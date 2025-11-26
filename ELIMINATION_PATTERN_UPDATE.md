# Block Elimination Pattern Update

## Summary
Updated the block elimination logic in GameEngine to follow a new pattern where specific milestone values eliminate lower-tier tiles from the board and spawn pool.

## New Elimination Pattern

| Milestone | Eliminates | Notes |
|-----------|------------|-------|
| 2048 (2K) | 2s | First elimination milestone |
| 4096 (4K) | 4s | |
| 8192 (8K) | - | **SKIP** - No elimination |
| 16384 (16K) | 8s | |
| 32768 (32K) | 16s | |
| 65536 (65K) | 32s | |
| 131072 (131K) | - | **SKIP** - No elimination |
| 262144 (262K) | 64s | |
| 524288 (524K) | 128s | |
| 1048576 (1M) | 256s | |
| 2097152 (2M) | - | **SKIP** - No elimination |
| 4194304 (4M) | 512s | |
| 8388608 (8M) | 1024s | |
| 16777216 (16M) | 2048s | |
| 33554432 (33M) | - | **SKIP** - No elimination |
| 67108864 (67M) | 4096s | Start of repeating pattern |
| 134217728 (134M) | 8192s | |

After 134M, the pattern repeats starting from the 67M logic.

## How It Works

1. **Immediate Elimination**: When a milestone tile is created (e.g., merging two 1024s to create 2048), the corresponding lower-value tiles are immediately removed from the board.

2. **Spawn Pool Update**: After elimination, those values will never spawn again, keeping the board focused on higher-value tiles.

3. **Board Refill**: After tiles are eliminated, the board is refilled with new tiles from the updated spawn pool (excluding eliminated values).

4. **Cumulative Effect**: Multiple eliminations accumulate - if you've reached both 2K and 4K milestones, both 2s and 4s are eliminated.

## Implementation Files Changed

1. **GameEngine.swift**:
   - Updated `milestoneExcludedValue()` to implement the new pattern with specific milestone mappings
   - Updated `reconstructEliminatedMilestones()` to handle the new milestone list
   - Updated `applyPendingEliminationsOnRestore()` to correctly restore elimination state
   - Updated `latestEliminatedValue()` to track the highest eliminated value

## Testing

All elimination tests pass:
- ✅ 2048 eliminates 2s
- ✅ 4096 eliminates 4s
- ✅ 8192 skips elimination
- ✅ 16K eliminates 8s
- ✅ 32K eliminates 16s
- ✅ 65K eliminates 32s
- ✅ 131K skips elimination
- ✅ Multiple eliminations accumulate correctly

## Gameplay Impact

This elimination pattern creates a natural progression where:
1. Early game focuses on small tiles (2, 4, 8)
2. Mid game sees elimination of smallest tiles as players reach 2K/4K
3. Late game becomes cleaner as more low-value tiles are eliminated
4. Skip milestones (8K, 131K, 2M, 33M) provide breathing room without eliminations

The pattern ensures the board doesn't become cluttered with low-value tiles in late game while maintaining strategic depth through the skip milestones.
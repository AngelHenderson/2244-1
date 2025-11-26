# Block Elimination Pattern - Final Implementation

## Summary
The block elimination system in 2244 follows a specific pattern where milestone tiles eliminate lower-tier tiles from the board and adjust the spawn pool.

## Pattern Before 67M
Uses the original specified pattern with specific eliminations and skips:

| Milestone | Eliminates | Notes |
|-----------|------------|-------|
| 2048 (2K) | 2s | |
| 4096 (4K) | 4s | |
| 8192 (8K) | - | **SKIP** |
| 16384 (16K) | 8s | |
| 32768 (32K) | 16s | |
| 65536 (65K) | 32s | |
| 131072 (131K) | - | **SKIP** |
| 262144 (262K) | 64s | |
| 524288 (524K) | 128s | |
| 1048576 (1M) | 256s | |
| 2097152 (2M) | - | **SKIP** |
| 4194304 (4M) | 512s | |
| 8388608 (8M) | 1024s | |
| 16777216 (16M) | 2048s | |
| 33554432 (33M) | - | **SKIP** |
| 67108864 (67M) | 4096s | |
| 134217728 (134M) | 8192s | |

## Pattern After 67M (Infinite Repetition)

After 134M, the pattern changes to a consistent formula that repeats forever:

### Elimination Rule
**Eliminated value = Milestone >> 14** (14 steps down)

### Skip Pattern
Every 3rd position relative to 67M is a **SKIP**:
- Position from 67M = log2(milestone) - 26
- If position % 3 = 2, then SKIP

### Examples

| Milestone | Power | Position from 67M | Eliminates | Calculation |
|-----------|-------|-------------------|------------|-------------|
| 268M | 2^28 | 2 | - | **SKIP** (2 % 3 = 2) |
| 536M | 2^29 | 3 | 32768 | 536M >> 14 = 32K |
| 1G | 2^30 | 4 | 65536 | 1G >> 14 = 65K |
| 2G | 2^31 | 5 | - | **SKIP** (5 % 3 = 2) |
| 4G | 2^32 | 6 | 262144 | 4G >> 14 = 262K |
| 8G | 2^33 | 7 | 524288 | 8G >> 14 = 524K |
| 16G | 2^34 | 8 | - | **SKIP** (8 % 3 = 2) |
| 32G | 2^35 | 9 | 2097152 | 32G >> 14 = 2M |
| 64G | 2^36 | 10 | 4194304 | 64G >> 14 = 4M |

This pattern continues infinitely for all larger milestones.

## Spawn Value Adjustment

### Before 67M
Minimum spawn value = (eliminated value × 2)

### After 67M
**Minimum spawn value = Milestone >> 7** (7 steps down)

### Examples
- After reaching 67M: Min spawn = 67M >> 7 = 524K
- After reaching 134M: Min spawn = 134M >> 7 = 1M
- After reaching 1G: Min spawn = 1G >> 7 = 8M

The game spawns 7 consecutive powers of 2 starting from the minimum spawn value.

## Implementation Details

1. **Immediate Elimination**: When a milestone tile is created, all tiles of the eliminated value instantly disappear from the board.

2. **Spawn Pool Update**: The eliminated values never spawn again, and the minimum spawn value adjusts based on the milestone reached.

3. **Board Refill**: After elimination, the board refills with tiles from the updated spawn pool.

4. **Skip Milestones**: Certain milestones don't eliminate anything, providing strategic breathing room in gameplay.

5. **Infinite Scaling**: The pattern continues forever, ensuring proper game balance even at extremely high values.

## Key Formulas

For milestones ≥ 268M:
- **Skip Check**: `(log2(milestone) - 26) % 3 == 2`
- **Eliminated Value**: `milestone >> 14` (if not skip)
- **Min Spawn Value**: `highest_milestone >> 7`

This system ensures the game remains playable and balanced as players reach increasingly high milestone values.
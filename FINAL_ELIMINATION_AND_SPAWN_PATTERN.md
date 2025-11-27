# Final Elimination and Spawn Pattern for 2244

## Elimination Pattern

### For Milestones < 67M
- Uses single-value elimination
- Example: 2K eliminates only 2s, 4K eliminates only 4s

### For Milestones >= 67M
- Uses **threshold-based elimination**
- Eliminates ALL tiles below (milestone >> 14)
- Examples:
  - 67M eliminates everything below 4K
  - 134M eliminates everything below 8K
  - 4T (4a) eliminates everything below 268M
  - 9c eliminates everything below (9c >> 14)

### Skip Milestones
Certain milestones don't eliminate anything:
- Position from 67M = log2(milestone) - 26
- If position % 3 = 2, then SKIP
- Examples: 268M, 2G, 16G (positions 2, 5, 8 from 67M)

## Spawn Pattern

### For Milestones < 67M
- Standard progressive spawning based on eliminated values
- Minimum spawn = (eliminated value × 2)

### For Milestones >= 67M
- **Spawn Range**: From (milestone >> 7) to (milestone >> 1)
- This means:
  - **Minimum spawn**: 7 steps down from your highest tile
  - **Maximum spawn**: 1 step down from your highest tile
- The game randomly selects from 7 candidates within this range

### Examples

#### At 67M:
- Elimination threshold: 4K (all tiles < 4K are removed)
- Spawn range: 524K to 33M
- Spawn candidates: 524K, 1M, 2M, 4M, 8M, 16M, 33M

#### At 4T (4a):
- Elimination threshold: 268M (all tiles < 268M are removed)
- Spawn range: 31B to 2T
- Spawn candidates: 31B, 62B, 125B, 250B, 500B, 1T, 2T

#### At 9c:
- Elimination threshold: 9c >> 14
- Spawn range: 70b to 4c
- Spawn candidates: 70b, 140b, 281b, 562b, 1c, 2c, 4c

## Why This System Works

1. **Clean Board**: Threshold elimination keeps the board clear of irrelevant low-value tiles
2. **Relevant Spawns**: New tiles spawn close to your current progress (1-7 steps below)
3. **Consistent Challenge**: The game remains challenging even at extreme values
4. **No Clutter**: You won't see ancient tiles like 33M when you're playing at 4a or 9c levels

## Key Points

- When you reach a high milestone like 4a or 9c:
  - Old tiles (33M, 67M, etc.) are automatically eliminated
  - New spawns are relevant to your current level (like 4c spawning when you have 9c)
- The system scales infinitely while maintaining playability
### 2244 Tile Color Palette (from reference screenshot)

Approximate sRGB hex values sampled by eye from the provided image. Names are descriptive for reference.

- Blue (3v, 3v tiles): `#2FA7E4`
- Orange (7v tiles): `#F49A3E`
- Pink (14v tiles): `#F16597`
- Lime (1v tiles): `#D4E04A`
- Deep Blue (452u tiles): `#154F7F`
- Coral (226u tiles): `#F05B59`

Notes:
- Lime uses dark text; all other buckets use white text for contrast.
- Palette is implemented in `GameUI/Theme.swift` via exponent-based buckets.
- Colors repeat every 25 exponent levels: tiles with values differing by a factor of 2^25 share the same color (e.g., 2 and 67,108,864).
- Feel free to tweak these hexes with more accurate samples as assets arrive.



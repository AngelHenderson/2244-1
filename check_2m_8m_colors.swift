#!/usr/bin/env swift

// Check what colors 2M and 8M have vs their repetitions

let palette25 = [
    "#2FA7E4", // 0: Azure
    "#F49A3E", // 1: Orange
    "#F16597", // 2: Hot Pink
    "#BA6597", // 3: Pinned/16
    "#9E3A46", // 4: Muted Red
    "#9674FF", // 5: Purple
    "#03524B", // 6: Dark Teal
    "#FF0039", // 7: Red
    "#FF6F96", // 8: Pink
    "#07F901", // 9: Bright Green
    "#FF3B7B", // 10: Vivid Pink
    "#55B9FF", // 11: Blue
    "#FFFFEB", // 12: Cream
    "#8849D1", // 13: Purple
    "#00FFE5", // 14: Cyan
    "#FFD300", // 15: Yellow
    "#F05B59", // 16: Coral Red
    "#55DFFE", // 17: Light Cyan
    "#39B54A", // 18: Green
    "#E91E63", // 19: Magenta
    "#673AB7", // 20: Deep Purple
    "#F44336", // 21: Red
    "#1565C0", // 22: Dark Blue
    "#EF6C00", // 23: Orange
    "#C0CA33"  // 24: Lime
]

print("Color comparison:")
print("=================")
print()
print("2M (2^21):")
print("  Palette index: 20")
print("  Base color: \(palette25[20]) - Deep Purple")
print()
print("70a (2^46):")
print("  Palette index: 20 (same as 2M)")
print("  Current: 15% darker Deep Purple")
print("  Should be: Same Deep Purple as 2M (no darkening)")
print()
print("---")
print()
print("8M (2^23):")
print("  Palette index: 22")
print("  Base color: \(palette25[22]) - Dark Blue")
print()
print("281a (2^48):")
print("  Palette index: 22 (same as 8M)")
print("  Current: 15% darker Dark Blue")
print("  Should be: Same Dark Blue as 8M (no darkening)")
print()
print("The issue: We're darkening them when they should have the EXACT SAME color!")
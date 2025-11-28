#!/usr/bin/env swift

// Compare palette25 with overridesByRemainder to find conflicts

// Original palette25 entries
let palette25 = [
    (0, "2FA7E4", "azure"),
    (1, "F49A3E", "orange"),
    (2, "F16597", "hot pink"),
    (3, "BA6597", "pinned for 16"),
    (4, "9E3A46", "Muted Red"),
    (5, "9674FF", "Purple"),
    (6, "03524B", "Dark Teal"),
    (7, "FF0039", "Red"),
    (8, "FF6F96", "Pink"),
    (9, "07F901", "Bright Green"),
    (10, "FF3B7B", "Vivid Pink"),
    (11, "55B9FF", "Blue"),
    (12, "FFFFEB", "Cream"),
    (13, "8849D1", "Purple"),
    (14, "00FFE5", "Cyan"),
    (15, "FFD300", "Yellow"),
    (16, "F05B59", "Coral Red"),
    (17, "55DFFE", "Light Cyan/Blue"),
    (18, "39B54A", "Green"),
    (19, "E91E63", "Magenta"),
    (20, "673AB7", "Deep Purple"),
    (21, "F44336", "Red"),
    (22, "1565C0", "Dark Blue"),
    (23, "EF6C00", "Orange"),
    (24, "C0CA33", "Lime")
]

// overridesByRemainder entries (converted remainder to 0-based index)
let overrides = [
    (5, "9674FF", "64 -> Purple"),      // remainder 6 -> index 5
    (6, "03524B", "128 -> Dark teal"),  // remainder 7 -> index 6
    (7, "FF0039", "256 -> Red"),        // remainder 8 -> index 7
    (8, "FF6F96", "512 -> Pink"),       // remainder 9 -> index 8
    (9, "07F901", "1024 -> Bright green"), // remainder 10 -> index 9
    (10, "FF3B7B", "2048 -> Vivid pink"), // remainder 11 -> index 10
    (11, "55B9FF", "4096 -> Blue"),     // remainder 12 -> index 11
    (12, "FFFFEB", "8192 -> Cream"),    // remainder 13 -> index 12
    (13, "8849D1", "16K -> Purple"),    // remainder 14 -> index 13
    (14, "00FFE5", "32K -> Cyan"),      // remainder 15 -> index 14
    (15, "FFD300", "64K -> Yellow"),    // remainder 16 -> index 15
    (16, "F05B59", "131K -> Coral red"), // remainder 17 -> index 16
    (17, "55DFFE", "262K -> Light Cyan"), // remainder 18 -> index 17
    (18, "39B54A", "524K -> Green"),    // remainder 19 -> index 18
    (19, "E91E63", "1M -> Magenta"),    // remainder 20 -> index 19
    (20, "673AB7", "2M -> Deep Purple"), // remainder 21 -> index 20
    (21, "F44336", "4M -> Red"),        // remainder 22 -> index 21
    (22, "1565C0", "8M -> Dark Blue"),  // remainder 23 -> index 22
    (23, "EF6C00", "16M -> Orange"),    // remainder 24 -> index 23
    (24, "C0CA33", "33M -> Lime"),      // remainder 0 -> index 24
    (4, "9E3A46", "32 -> Muted Red")    // remainder 5 -> index 4
]

print("Checking for conflicts between palette25 and overridesByRemainder:")
print("===================================================================")

for override in overrides {
    let paletteEntry = palette25[override.0]

    if paletteEntry.1 == override.1 {
        print("✓ Index \(override.0): SAME color (\(override.1)) - \(override.2)")
    } else {
        print("✗ Index \(override.0): DIFFERENT!")
        print("  Palette25: \(paletteEntry.1) (\(paletteEntry.2))")
        print("  Override:  \(override.1) (\(override.2))")
    }
}
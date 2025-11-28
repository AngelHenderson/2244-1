#!/usr/bin/env swift

// Show what colors the c-tier values will have after the fix

let palette25 = [
    (0, "2FA7E4", "Azure"),          // Index 0: 2^1 = 2
    (1, "F49A3E", "Orange"),         // Index 1: 2^2 = 4
    (2, "F16597", "Hot Pink"),       // Index 2: 2^3 = 8
    (3, "BA6597", "Pinned/16"),      // Index 3: 2^4 = 16
    (4, "9E3A46", "Muted Red"),      // Index 4: 2^5 = 32
    (5, "9674FF", "Purple"),         // Index 5: 2^6 = 64
    (6, "03524B", "Dark Teal"),      // Index 6: 2^7 = 128
    (7, "FF0039", "Red"),            // Index 7: 2^8 = 256
    (8, "FF6F96", "Pink"),           // Index 8: 2^9 = 512
    (9, "07F901", "Bright Green"),   // Index 9: 2^10 = 1024
    (10, "FF3B7B", "Vivid Pink"),    // Index 10: 2^11 = 2048
    (11, "55B9FF", "Blue"),          // Index 11: 2^12 = 4096
    (12, "FFFFEB", "Cream"),         // Index 12: 2^13 = 8192
    (13, "8849D1", "Purple"),        // Index 13: 2^14 = 16K
    (14, "00FFE5", "Cyan"),          // Index 14: 2^15 = 32K
    (15, "FFD300", "Yellow"),        // Index 15: 2^16 = 64K
    (16, "F05B59", "Coral Red"),     // Index 16: 2^17 = 131K
    (17, "55DFFE", "Light Cyan"),    // Index 17: 2^18 = 262K
    (18, "39B54A", "Green"),         // Index 18: 2^19 = 524K
    (19, "E91E63", "Magenta"),       // Index 19: 2^20 = 1M
    (20, "673AB7", "Deep Purple"),   // Index 20: 2^21 = 2M
    (21, "F44336", "Red"),           // Index 21: 2^22 = 4M
    (22, "1565C0", "Dark Blue"),     // Index 22: 2^23 = 8M
    (23, "EF6C00", "Orange"),        // Index 23: 2^24 = 16M
    (24, "C0CA33", "Lime"),          // Index 24: 2^25 = 33M
]

print("C-tier values and their colors (after fix):")
print("===========================================")

let cValues = [
    ("1c", 60, 9),   // 2^60, index 9
    ("2c", 61, 10),  // 2^61, index 10
    ("4c", 62, 11),  // 2^62, index 11
    ("9c", 63, 12),  // 2^63, index 12 (should be 8c but game shows 9c)
    ("18c", 64, 13), // 2^64, index 13
    ("36c", 65, 14), // 2^65, index 14
]

for (label, step, index) in cValues {
    let color = palette25[index]
    print("\(label): #\(color.1) - \(color.2)")
}

print("\nMatching values in first 25:")
print("=============================")
for (label, step, index) in cValues {
    let matchingValue = 1 << (index + 1)
    let color = palette25[index]
    print("\(label) matches \(matchingValue): #\(color.1) - \(color.2)")
}

print("\nExpected appearance:")
print("====================")
print("4c: Blue (#55B9FF) - same as 4096")
print("9c: Cream (#FFFFEB) - same as 8192")
print("18c: Purple (#8849D1) - same as 16K")
print("36c: Cyan (#00FFE5) - same as 32K")
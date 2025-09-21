// EliminationRules.swift
import Foundation

// Single source of truth for milestone elimination rules.
// When you create the key (left), remove all tiles of the mapped value (right).
// Pattern: eliminate the tier 9 doublings below the milestone (value >> 9).
public enum EliminationRules {
    public static let map: [Int: Int] = [
        // Milestone -> Value to Remove (exactly as specified)
        2_048: 2,                    // 2048 -> 2 removed
        4_096: 4,                    // 4096 -> 4 removed
        16_384: 8,                   // 16K -> 8 removed
        32_768: 16,                  // 32K -> 16 removed
        65_536: 32,                  // 65K -> 32 removed
        262_144: 64,                 // 262K -> 64 removed
        524_288: 128,                // 524K -> 128 removed
        1_048_576: 256,              // 1M -> 256 removed
        4_194_304: 512,              // 4M -> 512 removed
        8_388_608: 1_024,            // 8M -> 1024 removed
        16_777_216: 2_048,           // 16M -> 2048 removed
        67_108_864: 4_096,           // 67M -> 4096 removed
        134_217_728: 8_192,          // 134M -> 8192 removed
        268_435_456: 16_384,         // 268M -> 16K removed
        536_870_912: 32_768,         // 536M -> 32K removed
        1_073_741_824: 65_536,       // 1B -> 65K removed
        // Continue the pattern...
        2_147_483_648: 131_072,      // 2B -> 131K removed
        4_294_967_296: 262_144,      // 4B -> 262K removed
        8_589_934_592: 524_288,      // 8B -> 524K removed
        17_179_869_184: 1_048_576,   // 17B -> 1M removed
        34_359_738_368: 2_097_152,   // 34B -> 2M removed
        68_719_476_736: 4_194_304,   // 69B -> 4M removed
        137_438_953_472: 8_388_608,  // 137B -> 8M removed
        274_877_906_944: 16_777_216, // 275B -> 16M removed
    ]
}

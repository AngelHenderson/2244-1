// EliminationRules.swift
import Foundation

// Single source of truth for milestone elimination rules.
// When you create the key (left), remove all tiles of the mapped value (right).
// Pattern: eliminate the tier 9 doublings below the milestone (value >> 9).
public enum EliminationRules {
    public static let map: [Int: Int] = [
        1_024: 2,
        2_048: 4,
        4_096: 8,
        8_192: 16,
        16_384: 32,
        32_768: 64,
        65_536: 128,
        131_072: 256,
        262_144: 512,
        524_288: 1_024,
        1_048_576: 2_048,
        2_097_152: 4_096,
        4_194_304: 8_192,
        8_388_608: 16_384,
        16_777_216: 32_768
    ]
}

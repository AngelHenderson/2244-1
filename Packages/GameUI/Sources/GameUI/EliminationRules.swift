// EliminationRules.swift
import Foundation

// Single source of truth for milestone elimination rules.
// When you create the key (left), remove all tiles of the mapped value (right).
public enum EliminationRules {
    public static let map: [Int: Int] = [
        1_024: 2,
        2_048: 4,
        4_096: 8,
        16_384: 16,
        32_768: 32,
        65_536: 64,
        262_144: 128,
        524_288: 256,
        1_048_576: 512,
        4_194_304: 1_024,
        8_388_608: 2_048,
        16_777_216: 4_096
    ]
}

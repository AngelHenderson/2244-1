#!/usr/bin/env swift
import Foundation

// Simple test to verify the 14-step pattern
func testPattern() {
    print("Testing 14-step elimination pattern after 67M:")
    
    // After 67M, elimination should be 14 steps down
    let testCases: [(milestone: Int, desc: String, expectedElimination: Int?)] = [
        (67108864, "67M", 4096),      // 67M special case
        (134217728, "134M", 8192),    // 134M special case
        (268435456, "268M", nil),     // 268M skips (position 2)
        (536870912, "536M", 32768),   // 536M >> 14 = 32768
        (1073741824, "1G", 65536),    // 1G >> 14 = 65536
        (2147483648, "2G", nil),      // 2G skips (position 5)
        (4294967296, "4G", 262144),   // 4G >> 14 = 262144
    ]
    
    for (milestone, desc, expected) in testCases {
        let position = Int(log2(Double(milestone))) - 26
        let shouldSkip = position % 3 == 2
        
        if milestone < 268435456 {
            // Special cases
            print("  \(desc): special case - eliminates \(expected ?? 0)")
        } else if shouldSkip {
            let actual = expected == nil
            print("  \(desc): position \(position) - \(actual ? "✅" : "❌") skips")
        } else {
            let eliminated = milestone >> 14
            let matches = eliminated == expected
            print("  \(desc): position \(position) - \(matches ? "✅" : "❌") eliminates \(eliminated)")
        }
    }
}

testPattern()

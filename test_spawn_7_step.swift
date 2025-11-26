#!/usr/bin/env swift
import Foundation

// Test that spawn values are 7 steps down from milestones after 67M
func testSpawnPattern() {
    print("\nTesting 7-step spawn pattern after 67M:")
    
    let milestones = [
        (67108864, "67M"),
        (134217728, "134M"),
        (268435456, "268M"),
        (536870912, "536M"),
        (1073741824, "1G")
    ]
    
    for (milestone, desc) in milestones {
        let minSpawn = milestone >> 7  // 7 steps down
        print("  \(desc): minimum spawn value = \(minSpawn) (milestone >> 7)")
    }
    
    print("\nExamples:")
    print("  67M (67,108,864) >> 7 = 524,288")
    print("  This means after reaching 67M, tiles spawn starting from 524K")
    print("  The 7 spawning tiles would be: 524K, 1M, 2M, 4M, 8M, 16M, 32M")
}

testSpawnPattern()

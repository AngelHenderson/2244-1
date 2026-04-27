import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift"
var content = try! String(contentsOfFile: path)

let insertFunc = """
    /// Computes the true mathematical step (index - 1, plus tier scaling rules for aa-bz).
    /// Use this strictly for step-based color assignments to accurately represent missing tiers.
    static func milestoneStep(for milestone: String) -> Int {
        var step = milestoneIndex(for: milestone)
        // Adjust for "0" at the start of allMilestones
        if step > 0 { step -= 1 }
        
        let normalized = normalizeMilestone(milestone).lowercased()
        if let match = normalized.range(of: "[a-z]+", options: .regularExpression) {
            let letters = String(normalized[match])
            if letters.count == 2 {
                if letters >= "aa" && letters <= "bb" {
                    step -= 1
                } else if letters >= "bd" && letters <= "bz" {
                    step -= 2
                }
            }
        }
        return step
    }

    static func milestoneIndex(for milestone: String) -> Int {
"""

content = content.replacingOccurrences(of: "    static func milestoneIndex(for milestone: String) -> Int {", with: insertFunc)

try! content.write(toFile: path, atomically: true, encoding: .utf8)
print("Updated LeaderboardClient.swift")

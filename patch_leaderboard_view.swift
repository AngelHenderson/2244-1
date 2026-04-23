import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/LeaderboardView.swift"
var content = try! String(contentsOfFile: path)

let oldColorFunc = """
    private func tileColor(for milestone: String) -> Color {
        // Infinity tiles use light cyan/turquoise (matches the infinity tile in-game)
        if milestone.contains("∞") {
            return Color(red: 0.6, green: 0.9, blue: 0.9)
        }
        let idx = MockLeaderboardData.milestoneIndex(for: milestone)
        guard idx > 0 else { return Color(red: 0.4, green: 0.3, blue: 0.5) }
        if let theme = currentTheme {
            return theme.colorForStep(idx - 1)
        }
        return Theme.colorForStep(idx - 1)
    }

    /// Returns the game tile text color for a milestone string, using the current theme
    private func tileTextColor(for milestone: String) -> Color {
        // Infinity tiles use dark gray/blue text on light cyan background
        if milestone.contains("∞") {
            return Color(red: 0.4, green: 0.5, blue: 0.5)
        }
        let idx = MockLeaderboardData.milestoneIndex(for: milestone)
        guard idx > 0 else { return .white }
        if let theme = currentTheme {
            return theme.textColorForStep(idx - 1)
        }
        return Theme.textColorForStep(idx - 1)
    }
"""

let newColorFunc = """
    private func tileColor(for milestone: String) -> Color {
        // Infinity tiles use light cyan/turquoise (matches the infinity tile in-game)
        if milestone.contains("∞") {
            return Color(red: 0.6, green: 0.9, blue: 0.9)
        }
        let step = MockLeaderboardData.milestoneStep(for: milestone)
        if let theme = currentTheme {
            return theme.colorForStep(step)
        }
        return Theme.colorForStep(step)
    }

    /// Returns the game tile text color for a milestone string, using the current theme
    private func tileTextColor(for milestone: String) -> Color {
        // Infinity tiles use dark gray/blue text on light cyan background
        if milestone.contains("∞") {
            return Color(red: 0.4, green: 0.5, blue: 0.5)
        }
        let step = MockLeaderboardData.milestoneStep(for: milestone)
        if let theme = currentTheme {
            return theme.textColorForStep(step)
        }
        return Theme.textColorForStep(step)
    }
"""

if content.contains("private func tileColor(for milestone: String) -> Color {") {
    content = content.replacingOccurrences(of: oldColorFunc, with: newColorFunc)
    try! content.write(toFile: path, atomically: true, encoding: .utf8)
    print("Updated LeaderboardView.swift")
} else {
    print("Could not find the function block in LeaderboardView.swift")
}

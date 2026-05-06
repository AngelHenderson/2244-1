import Foundation

let path = "/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift"
var content = try! String(contentsOfFile: path)

content = content.replacingOccurrences(of: "        var entries: [LeaderboardEntry] = []", with: """
        var entries: [LeaderboardEntry] = []
        print("DEBUG: playerData count = \\(playerData.count)")
""")

try! content.write(toFile: path, atomically: true, encoding: .utf8)

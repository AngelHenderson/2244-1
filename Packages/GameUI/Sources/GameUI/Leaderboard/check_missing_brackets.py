
import sys
import re

content = open("/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift").read()

# Extract seeds
seeds_match = re.search(r"private static let countryPlayerSeeds: \[String: Int\] = \[(.*?)\]", content, re.DOTALL)
seeds = re.findall(r'"([^"]+)"\s*:', seeds_match.group(1)) if seeds_match else []

# Extract extendedBrackets cases
brackets_match = re.search(r"static func extendedBrackets\(for countryCode: String\) -> \[\(milestone: String, startRank: Int\)\] \{(.*?)default:", content, re.DOTALL)
bracket_cases = re.findall(r'case\s+"([^"]+)"', brackets_match.group(1)) if brackets_match else []

print("Missing countries in extendedBrackets:", [s for s in seeds if s not in bracket_cases])

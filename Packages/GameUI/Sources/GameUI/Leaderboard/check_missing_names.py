
import sys
import re

content = open("/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift").read()

# Extract baseCountryPlayerCounts keys
counts_match = re.search(r"public static let baseCountryPlayerCounts: \[String: Int\] = \[(.*?)\]", content, re.DOTALL)
codes = re.findall(r'"([^"]+)"\s*:', counts_match.group(1))

# Extract names cases
names_match = re.search(r"static func names\(for countryCode: String\) -> \[String\] \{(.*?)default:", content, re.DOTALL)
names_cases = re.findall(r'case\s+"([^"]+)"', names_match.group(1)) if names_match else []

print("Missing countries in names switch:", [s for s in codes if s not in names_cases])

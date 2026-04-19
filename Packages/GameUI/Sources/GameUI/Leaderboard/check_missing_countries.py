
import sys
import re

content = open("/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift").read()

# Extract seeds using regex
seeds_match = re.search(r"private static let countryPlayerSeeds: \[String: Int\] = \[(.*?)\]", content, re.DOTALL)
if seeds_match:
    seeds_text = seeds_match.group(1)
    seeds = re.findall(r'"([^"]+)"\s*:', seeds_text)
else:
    seeds = []

# Extract top150 cases using regex
top150_match = re.search(r"static func top150Milestones\(for countryCode: String\) -> \[String\] \{(.*?)default:", content, re.DOTALL)
if top150_match:
    top150_text = top150_match.group(1)
    cases = re.findall(r'case\s+"([^"]+)"', top150_text)
else:
    cases = []

print("Seeds count:", len(seeds))
print("Cases count:", len(cases))

missing = [s for s in seeds if s not in cases]
print("Missing countries in top150Milestones:", missing)

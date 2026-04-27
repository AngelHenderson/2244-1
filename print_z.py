import re

content = open('/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift').read()
match = re.search(r'static let allMilestones:\s*\[String\] = \[(.*?)\]', content, re.DOTALL)
if match:
    arr_str = match.group(1)
    items = re.findall(r'"([^"]+)"', arr_str)
    print("Items around 289 to 300:")
    for i in range(288, 302):
        print(f"{i}: {items[i]}")

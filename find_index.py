import re

content = open('/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift').read()
match = re.search(r'static let allMilestones:\s*\[String\] = \[(.*?)\]', content, re.DOTALL)
if match:
    arr_str = match.group(1)
    items = re.findall(r'"([^"]+)"', arr_str)
    try:
        idx = items.index("1al")
        print("Index of 1al:", idx)
    except:
        print("1al not found")
    try:
        idx = items.index("873bz")
        print("Index of 873bz:", idx)
    except:
        print("873bz not found")

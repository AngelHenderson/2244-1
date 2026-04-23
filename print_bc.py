import re

content = open('/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift').read()
match = re.search(r'static let allMilestones:\s*\[String\] = \[(.*?)\]', content, re.DOTALL)
if match:
    arr_str = match.group(1)
    items = re.findall(r'"([^"]+)"', arr_str)
    
    for i, item in enumerate(items):
        if item.endswith("bb") and not item.endswith("abb"):
            print(i, item)
        if item.endswith("bc"):
            print(i, item)
        if item.endswith("bd"):
            print(i, item)


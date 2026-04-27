import re

content = open('/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift').read()
match = re.search(r'static let allMilestones:\s*\[String\] = \[(.*?)\]', content, re.DOTALL)
if match:
    arr_str = match.group(1)
    items = re.findall(r'"([^"]+)"', arr_str)
    z_items = [i for i in items if i.endswith("z") and not i.endswith("bz") and not i.endswith("az")]
    print("z items:", z_items)

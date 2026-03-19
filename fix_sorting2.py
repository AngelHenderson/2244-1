with open("Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift", "r") as f:
    lines = f.readlines()

count = 0
new_lines = []
for i, line in enumerate(lines):
    if line == "        // Insert user at their calculated rank\n":
        # Check if nonInfinityEntries was used recently
        is_country_entries = False
        for j in range(max(0, len(new_lines) - 25), len(new_lines)):
            if "nonInfinityEntries" in new_lines[j]:
                is_country_entries = True
                break
        
        if is_country_entries:
            sort_logic = """        // Sort progressed players by milestone index to maintain correct order
        nonInfinityEntries.sort {
            if $0.milestoneIdx != $1.milestoneIdx {
                return $0.milestoneIdx > $1.milestoneIdx // Higher index = better milestone
            }
            // Tiebreaker: stable sort based on id
            return $0.id < $1.id
        }

        // Insert user at their calculated rank\n"""
            new_lines.append(sort_logic)
            count += 1
            continue
            
    new_lines.append(line)

print(f"Replaced {count} occurrences")

if count > 0:
    with open("Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift", "w") as f:
        f.writelines(new_lines)

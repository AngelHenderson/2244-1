import sys

with open("Packages/GameApp/Sources/GameApp/ParityModels+OneUp.swift", "r") as f:
    content = f.read()

start_idx = content.find('case "milestone":')
time_idx = content.find('case "time":')
end_idx = content.find('default:\n            return ""\n        }\n    }')

if start_idx == -1 or time_idx == -1 or end_idx == -1:
    print("Could not find blocks")
    sys.exit(1)

# Extract milestone block
# It includes the indentation for the next block
milestone_block = content[start_idx:time_idx]

# Create time block
time_block = milestone_block.replace('case "milestone":', 'case "time":')
time_block = time_block.replace('milestone?', 'time?')

# Create streak block
streak_block = milestone_block.replace('case "milestone":', 'case "streak":')
streak_block = streak_block.replace('milestone?', 'streak?')
streak_block = streak_block.replace(r'\(lower)', r'\(lower) days')
streak_block = streak_block.replace(r'\(higher)', r'\(higher) days')

# Create hof block
hof_block = milestone_block.replace('case "milestone":', 'case "hof":')
hof_block = hof_block.replace('milestone?', 'record?')
hof_block = hof_block.replace(r'\(lower)', r'\(lower) infinities')
hof_block = hof_block.replace(r'\(higher)', r'\(higher) infinities')

# Concatenate everything
new_content = content[:start_idx] + milestone_block + time_block + streak_block + hof_block + content[end_idx:]

with open("Packages/GameApp/Sources/GameApp/ParityModels+OneUp.swift", "w") as f:
    f.write(new_content)

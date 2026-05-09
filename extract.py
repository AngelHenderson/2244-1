import sys

def extract_between(file_path, start_str, end_str):
    with open(file_path, 'r') as f:
        content = f.read()
    
    start_idx = content.find(start_str)
    if start_idx == -1: return ""
    
    end_idx = content.find(end_str, start_idx)
    if end_idx == -1: return ""
    
    return content[start_idx:end_idx]

f = 'Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift'
print(extract_between(f, "    static func seededRandom", "    // Calculate players changing name or avatar per day"))
print(extract_between(f, "    // Calculate players changing name or avatar per day", "    public static let baseCountryPlayerCounts"))
print(extract_between(f, "    // Avatar IDs from AvatarCatalog", "    // Check if a name is a realistic first name"))

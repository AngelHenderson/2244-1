#!/usr/bin/env python3
"""
Regenerate daily_claims_365.json from DailyClaimsStore.swift cycle array.
Parses the Swift source to extract the cycle, then generates all 365 entries.
"""
import re, json, sys

SWIFT_FILE = "Packages/GameCore/Sources/GameCore/Services/DailyClaimsStore.swift"
JSON_FILE = "2244/game2244/JSON/daily_claims_365.json"

REWARD_FIELDS = ["gems", "spins", "hammers", "magnets", "swaps", "boost2x", "boost3x", "boost4x"]

def parse_cycle(swift_path):
    with open(swift_path) as f:
        content = f.read()
    
    # Find the cycle array
    match = re.search(r'static let cycle[^=]*=\s*\[(.*?)\n    \]', content, re.DOTALL)
    if not match:
        print("ERROR: Could not find cycle array in Swift file")
        sys.exit(1)
    
    cycle_text = match.group(1)
    
    # Parse each AchievementDef.Rewards(...) entry
    entries = []
    for line_match in re.finditer(r'AchievementDef\.Rewards\((.*?)\)', cycle_text):
        params_str = line_match.group(1).strip()
        rewards = {}
        if params_str:
            for param in params_str.split(','):
                param = param.strip()
                if ':' in param:
                    key, val = param.split(':', 1)
                    key = key.strip()
                    val = val.strip()
                    if key in REWARD_FIELDS:
                        rewards[key] = int(val)
        entries.append(rewards)
    
    print(f"Parsed {len(entries)} cycle entries from Swift")
    return entries

def generate_json(cycle):
    total_days = 365
    result = []
    
    for day in range(1, total_days + 1):
        index = (day - 1) % len(cycle)
        rewards = cycle[index]
        
        day_str = f"{day:03d}"
        
        # Day 365 is the yearly award
        if day == 365:
            title = f"Daily Claim \u2014 Day {day}"
            description = "Claim your Year 1 yearly award!"
        else:
            title = f"Daily Claim \u2014 Day {day}"
            description = f"Claim your Day {day} daily reward."
        
        entry = {
            "id": f"daily_claim_day_{day_str}",
            "gcIdentifier": f"daily_claim_day_{day_str}",
            "title": title,
            "description": description,
            "category": "DailyClaim",
            "rewards": rewards if rewards else {},
            "hidden": False,
            "conditionExpr": "",
            "conditions": [
                {
                    "field": "daily_claim_available",
                    "op": "==",
                    "value": 1
                },
                {
                    "field": "claim_day_index",
                    "op": "==",
                    "value": day
                }
            ]
        }
        result.append(entry)
    
    return result

def main():
    cycle = parse_cycle(SWIFT_FILE)
    entries = generate_json(cycle)
    
    with open(JSON_FILE, 'w') as f:
        json.dump(entries, f, indent=2, ensure_ascii=False)
    
    print(f"Written {len(entries)} entries to {JSON_FILE}")
    
    # Verify key entries
    print(f"\nDay 1 rewards: {entries[0]['rewards']}")
    print(f"Day 7 rewards: {entries[6]['rewards']}")
    print(f"Day 337 rewards: {entries[336]['rewards']}")
    print(f"Day 364 rewards: {entries[363]['rewards']}")
    print(f"Day 365 rewards: {entries[364]['rewards']}")
    print(f"Day 365 description: {entries[364]['description']}")

if __name__ == "__main__":
    main()

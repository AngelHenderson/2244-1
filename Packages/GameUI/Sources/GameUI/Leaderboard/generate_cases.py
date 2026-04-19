
import sys
import re

content = open("/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift").read()

# Extract baseCountryPlayerCounts keys
counts_match = re.search(r"public static let baseCountryPlayerCounts: \[String: Int\] = \[(.*?)\]", content, re.DOTALL)
counts_text = counts_match.group(1)
codes = re.findall(r'"([^"]+)"\s*:', counts_text)
codes.append("US") # US is handled separately but good to check

# List all defined PlayerMilestones and ExtendedRankBrackets
milestone_arrays = re.findall(r"static let (.*?)PlayerMilestones", content)
bracket_arrays = re.findall(r"static let (.*?)ExtendedRankBrackets", content)

# Map codes to their likely array names
def to_camel_case(code):
    mapping = {
        "US": "us", "GB": "uk", "CA": "canada", "AU": "australia", "DE": "germany",
        "FR": "france", "JP": "japan", "IN": "india", "BR": "brazil", "MX": "mexico",
        "AF": "afghanistan", "AL": "albania", "DZ": "algeria", "CN": "china", "KR": "southKorea",
        "IT": "italy", "ES": "spain", "NL": "netherlands", "CH": "switzerland", "NO": "norway",
        "DK": "denmark", "FI": "finland", "PL": "poland", "BE": "belgium", "SE": "sweden",
        "AT": "austria", "IE": "ireland", "PT": "portugal", "GR": "greece", "CZ": "czechia",
        "RO": "romania", "MY": "malaysia", "NZ": "newZealand", "HU": "hungary", "TH": "thailand",
        "AE": "uae", "PH": "philippines", "AD": "andorra", "ID": "indonesia", "ZA": "southAfrica",
        "KE": "kenya", "FJ": "fiji", "VN": "vietnam", "CW": "curacao", "VE": "venezuela",
        "AZ": "azerbaijan", "KZ": "kazakhstan", "TJ": "tajikistan", "NU": "niue", "KG": "kyrgyzstan",
        "IS": "iceland", "SK": "slovakia", "UZ": "uzbekistan", "PK": "pakistan", "UA": "ukraine",
        "MG": "madagascar", "IQ": "iraq"
    }
    return mapping.get(code, code.lower())

print("--- top150Milestones Cases ---")
for code in sorted(codes):
    name = to_camel_case(code)
    if name in milestone_arrays:
        print(f'case "{code}": return LeaderboardClient.{name}PlayerMilestones')
    else:
        print(f'// MISSING MILESTONE ARRAY FOR {code} ({name})')

print("\n--- extendedBrackets Cases ---")
for code in sorted(codes):
    name = to_camel_case(code)
    if name in bracket_arrays:
        print(f'case "{code}": return LeaderboardClient.{name}ExtendedRankBrackets')
    else:
        print(f'// MISSING BRACKET ARRAY FOR {code} ({name})')

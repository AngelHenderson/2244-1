import sys

file_path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"

with open(file_path, "r") as f:
    content = f.read()

old_offset_logic = """            let timeOffset = Double.random(in: -43200...0) // Spread posts throughout the last 12 hours
            let itemDate = now.addingTimeInterval(timeOffset)
            
            var comments: [SocialFeedComment] = []
            
            // Generate top-level base comments
            let ageFactor = abs(timeOffset) / 43200.0"""

new_offset_logic = """            let startOfDay = Calendar.current.startOfDay(for: now)
            let timeOffset = Double.random(in: 0...86400) // Spread posts throughout the entire day
            let itemDate = startOfDay.addingTimeInterval(timeOffset)
            
            var comments: [SocialFeedComment] = []
            
            // Generate top-level base comments
            let ageInSeconds = max(0, now.timeIntervalSince(itemDate))
            let ageFactor = min(1.0, ageInSeconds / 43200.0)"""

content = content.replace(old_offset_logic, new_offset_logic)

old_base_offset_logic = """                let baseOffset: Double
                if tone == "competitive" {
                    let randomDelay = Double.random(in: 1800...3600)
                    baseOffset = min(timeOffset + randomDelay, 0)
                } else {
                    // Non-competitive comments mostly arrive in the first 30 minutes
                    let randomDelay: Double
                    if Double.random(in: 0...1) < 0.85 {
                        randomDelay = Double.random(in: 30...1800)
                    } else {
                        randomDelay = Double.random(in: 1800...86400)
                    }
                    baseOffset = min(timeOffset + randomDelay, 0)
                }
                let baseCreatedAt = now.addingTimeInterval(baseOffset)"""

new_base_offset_logic = """                let baseOffset: Double
                if tone == "competitive" {
                    baseOffset = Double.random(in: 1800...3600)
                } else {
                    // Non-competitive comments mostly arrive in the first 30 minutes
                    if Double.random(in: 0...1) < 0.85 {
                        baseOffset = Double.random(in: 30...1800)
                    } else {
                        baseOffset = Double.random(in: 1800...86400)
                    }
                }
                let baseCreatedAt = itemDate.addingTimeInterval(baseOffset)"""

content = content.replace(old_base_offset_logic, new_base_offset_logic)

with open(file_path, "w") as f:
    f.write(content)

print("Successfully updated time offset logic.")

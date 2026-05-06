import Foundation

// Copying some logic from LeaderboardClient
let str = "1al"

func milestoneStep(for milestone: String) -> Int {
    var step = 100 // placeholder for milestoneIndex
    
    let normalized = milestone.lowercased()
    if let match = normalized.range(of: "[a-z]+", options: .regularExpression) {
        let letters = String(normalized[match])
        if letters.count == 2 {
            if letters >= "aa" && letters <= "bb" {
                step -= 1
            } else if letters >= "bd" && letters <= "bz" {
                step -= 2
            }
        }
    }
    return step
}

print(milestoneStep(for: "1aa"))
print(milestoneStep(for: "1bd"))

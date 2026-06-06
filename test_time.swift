import Foundation
func extractTime(from text: String) -> (Int, Int)? {
    let pattern = try? NSRegularExpression(pattern: "(\\d{1,2}):(\\d{2})")
    let matches = pattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
    
    var bestTime: (mins: Int, secs: Int)? = nil
    var bestTotal = Int.max
    
    for match in matches {
        if let mRange = Range(match.range(at: 1), in: text),
           let sRange = Range(match.range(at: 2), in: text),
           let mins = Int(text[mRange]),
           let secs = Int(text[sRange]) {
            let total = mins * 60 + secs
            if total < bestTotal {
                bestTotal = total
                bestTime = (mins, secs)
            }
        }
    }
    return bestTime
}
print(extractTime(from: "Cleared the clock challenge at 7:54. Clean run."))

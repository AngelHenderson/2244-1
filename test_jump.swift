import Foundation

func formatTileAtStep(_ step: Int) -> String {
    let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
    if step <= 25 {
        return "\(step + 1)\(alphabet[step])"
    } else {
        var n = step
        var label = ""
        while n > 0 {
            label = String(alphabet[n % 26]) + label
            n /= 26
        }
        return "\(step + 1)\(label)"
    }
}

let allMilestones = (0...816).map { formatTileAtStep($0) }
if let idx1 = allMilestones.firstIndex(of: "1af"), let idx2 = allMilestones.firstIndex(of: "40aj") {
    print("1af is at \(idx1), 40aj is at \(idx2). Difference: \(idx2 - idx1)")
} else {
    print("Could not find 1af or 40aj")
}

if let idx3 = allMilestones.firstIndex(of: "709an"), let idx4 = allMilestones.firstIndex(of: "799as") {
    print("709an is at \(idx3), 799as is at \(idx4). Difference: \(idx4 - idx3)")
} else {
    print("Could not find 709an or 799as")
}

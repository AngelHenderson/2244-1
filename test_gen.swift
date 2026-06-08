import Foundation

func formatTileAtStep(_ step: Int) -> String {
    let exponent = step + 1
    let powerOf10 = Double(exponent) * log10(2.0)
    let intPower = Int(floor(powerOf10))
    let mantissa = pow(10.0, powerOf10 - Double(intPower))
    
    if intPower < 3 { return String(Int(mantissa)) }
    if intPower < 6 { return "\\(Int(mantissa))K" }
    if intPower < 9 { return "\\(Int(mantissa))M" }
    if intPower < 12 { return "\\(Int(mantissa))B" }
    
    let suffixOrdinal = (intPower - 12) / 3 + 1
    let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
    
    var n = suffixOrdinal
    var label = ""
    while n > 0 {
        label = String(alphabet[(n - 1) % 26]) + label
        n = (n - 1) / 26
    }
    
    return "\\(Int(mantissa))\\(label)"
}

let allMilestones = (0...816).map { formatTileAtStep($0) }
if let idx1 = allMilestones.firstIndex(of: "709an"), let idx2 = allMilestones.firstIndex(of: "799as") {
    print("709an is at \\(idx1), 799as is at \\(idx2). Difference: \\(idx2 - idx1)")
} else {
    print("Could not find 709an or 799as. Let's find index 500 to 600:")
    for i in 120...140 {
        print("\\(i): \\(allMilestones[i])")
    }
}

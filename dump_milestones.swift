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
    
    let tierBase = 12 + (suffixOrdinal - 1) * 3
    let adjustedMantissa = mantissa * pow(10.0, Double(intPower - tierBase))
    
    return "\\(Int(adjustedMantissa))\\(label)"
}

let allMilestones = (0...816).map { formatTileAtStep($0) }
var output = ""
for (idx, m) in allMilestones.enumerated() {
    output += "\\(idx): \\(m)\\n"
}
try! output.write(toFile: "/Users/angelhendersonjr/Development/2244/milestones.txt", atomically: true, encoding: .utf8)

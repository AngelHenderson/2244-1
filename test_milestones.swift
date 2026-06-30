import Foundation

func formatTileAtStep(_ step: Int) -> String {
    if step < 0 || step >= 817 { return "∞" }
    let exponent = step + 1
    if exponent <= 62 {
        let value = 1 << exponent
        return "\(value)" // simplified
    }
    let powerOf10 = Double(exponent) * log10(2.0)
    let intPower = Int(floor(powerOf10))
    let mantissa = pow(10.0, powerOf10 - Double(intPower))
    
    if intPower < 3 { return String(Int(mantissa)) }
    if intPower < 6 { return "\(Int(mantissa))K" }
    if intPower < 9 { return "\(Int(mantissa))M" }
    if intPower < 12 { return "\(Int(mantissa))B" }
    
    let suffixOrdinal = (intPower - 12) / 3 + 1
    
    // suffix generation logic (simplified a, b, c, d, e, f = 6)
    let alphabet = "abcdefghijklmnopqrstuvwxyz"
    let suffix: String
    if suffixOrdinal <= 26 {
        let idx = alphabet.index(alphabet.startIndex, offsetBy: suffixOrdinal - 1)
        suffix = String(alphabet[idx])
    } else {
        suffix = "z"
    }
    
    let tierBase = 12 + (suffixOrdinal - 1) * 3
    let adjustedMantissa = mantissa * pow(10.0, Double(intPower - tierBase))
    
    return "\(Int(adjustedMantissa))\(suffix)"
}

for step in 80...120 {
    print("Step \(step): \(formatTileAtStep(step))")
}

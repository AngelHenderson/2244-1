import Foundation
let val = 7.3 * pow(10.0, 106)
let step = Int(max(0, round(log2(val)) - 1))
print("val: \(val), step: \(step)")

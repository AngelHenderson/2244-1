import Foundation

let palette = [
    "2", "4", "8", "16", "32", "64", "128", "256", "512", "1024", 
    "2048", "4096", "8192", "16K", "32K", "65K", "131K", "262K", "524K", "1M"
]

func colorForStep(_ step: Int) -> String {
    let exponent = step + 1
    let idx = (max(1, exponent) - 1) % 25
    return idx < palette.count ? palette[idx] : "Other"
}

print("Step 408:", colorForStep(408))
print("Step 409:", colorForStep(409))
print("Step 816:", colorForStep(816))
print("Step 817:", colorForStep(817))
print("Step 818:", colorForStep(818))

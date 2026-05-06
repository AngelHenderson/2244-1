import Foundation

let codes: [String]
if #available(iOS 16.0, macOS 13.0, *) {
    codes = Locale.Region.isoRegions.compactMap { $0.identifier }
} else {
    codes = Locale.isoRegionCodes
}
let excludedCodes: Set<String> = [
    "EU", "EZ", "UN", "QO", "ZZ",
    "AC", "CP", "DG", "EA", "IC", "TA",
    "BV", "HM", "TF", "GS", "UM", "AQ",
    "EH", "SJ", "XG"
]
let validCodes = codes.filter { !excludedCodes.contains($0) && $0.count == 2 }
print("Valid codes count: \\(validCodes.count)")

import Foundation

let start = Date()
for _ in 0..<100 {
    var codes: [String] = []
    if #available(iOS 16.0, macOS 13.0, *) {
        codes = Locale.Region.isoRegions.compactMap { $0.identifier }
    } else {
        codes = Locale.isoRegionCodes
    }
}
let end = Date()
print("Time taken: \(end.timeIntervalSince(start))")

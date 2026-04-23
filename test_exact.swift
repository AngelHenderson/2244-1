import Foundation

for i in 1...1023 {
    let val = pow(2.0, Double(i))
    let logVal = log2(val)
    if logVal != Double(i) {
        print("Mismatch at \(i): log2(\(val)) = \(logVal)")
    }
}
print("Done exact test.")

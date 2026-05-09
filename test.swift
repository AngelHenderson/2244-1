import Foundation

// Copying some simplified logic of TileStepLabelFormatter
func excelLetters(for index: Int) -> String {
    var i = index
    var result = ""
    while i > 0 {
        let rem = (i - 1) % 26
        let scalar = UnicodeScalar(65 + rem)!
        result = String(scalar) + result
        i = (i - 1) / 26
    }
    return result
}

print(excelLetters(for: 1)) // A
print(excelLetters(for: 45)) // AS


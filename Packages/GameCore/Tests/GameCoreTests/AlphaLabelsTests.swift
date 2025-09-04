import Testing
@testable import GameCore

@Suite("AlphaLabels")
struct AlphaLabelsTests {
    
    @Test("Basic label generation")
    func basicLabels() throws {
        #expect(try AlphaLabels.label(for: 1) == "A")
        #expect(try AlphaLabels.label(for: 2) == "B")
        #expect(try AlphaLabels.label(for: 3) == "C")
        #expect(try AlphaLabels.label(for: 26) == "Z")
        #expect(try AlphaLabels.label(for: 27) == "AA")
        #expect(try AlphaLabels.label(for: 28) == "AB")
        #expect(try AlphaLabels.label(for: 52) == "AZ")
        #expect(try AlphaLabels.label(for: 53) == "BA")
        #expect(try AlphaLabels.label(for: 702) == "ZZ")
        #expect(try AlphaLabels.label(for: 703) == "AAA")
    }
    
    @Test("Index of label")
    func indexOfLabel() throws {
        #expect(try AlphaLabels.index(of: "A") == 1)
        #expect(try AlphaLabels.index(of: "B") == 2)
        #expect(try AlphaLabels.index(of: "C") == 3)
        #expect(try AlphaLabels.index(of: "Z") == 26)
        #expect(try AlphaLabels.index(of: "AA") == 27)
        #expect(try AlphaLabels.index(of: "AB") == 28)
        #expect(try AlphaLabels.index(of: "AZ") == 52)
        #expect(try AlphaLabels.index(of: "BA") == 53)
        #expect(try AlphaLabels.index(of: "ZZ") == 702)
        #expect(try AlphaLabels.index(of: "AAA") == 703)
    }
    
    @Test("Next label")
    func nextLabel() throws {
        #expect(try AlphaLabels.next(after: "A") == "B")
        #expect(try AlphaLabels.next(after: "B") == "C")
        #expect(try AlphaLabels.next(after: "Y") == "Z")
        #expect(try AlphaLabels.next(after: "Z") == "AA")
        #expect(try AlphaLabels.next(after: "AA") == "AB")
        #expect(try AlphaLabels.next(after: "AZ") == "BA")
        #expect(try AlphaLabels.next(after: "ZZ") == "AAA")
        #expect(try AlphaLabels.next(after: "AAZ") == "ABA")
        #expect(try AlphaLabels.next(after: "AZZ") == "BAA")
    }
    
    @Test("Generate from C")
    func generateFromC() throws {
        let labels = try AlphaLabels.generate(from: "C", count: 10)
        #expect(labels == ["C", "D", "E", "F", "G", "H", "I", "J", "K", "L"])
        
        let fromZ = try AlphaLabels.generate(from: "Z", count: 5)
        #expect(fromZ == ["Z", "AA", "AB", "AC", "AD"])
    }
    
    @Test("Case insensitive")
    func caseInsensitive() throws {
        #expect(try AlphaLabels.index(of: "a") == 1)
        #expect(try AlphaLabels.index(of: "z") == 26)
        #expect(try AlphaLabels.index(of: "aa") == 27)
        #expect(try AlphaLabels.index(of: "aA") == 27)
        #expect(try AlphaLabels.index(of: "Aa") == 27)
        #expect(try AlphaLabels.index(of: "AA") == 27)
    }
    
    @Test("Validation")
    func validation() {
        #expect(AlphaLabels.isValid("A") == true)
        #expect(AlphaLabels.isValid("Z") == true)
        #expect(AlphaLabels.isValid("AA") == true)
        #expect(AlphaLabels.isValid("ZZZ") == true)
        
        #expect(AlphaLabels.isValid("") == false)
        #expect(AlphaLabels.isValid("1") == false)
        #expect(AlphaLabels.isValid("A1") == false)
        #expect(AlphaLabels.isValid("@") == false)
        #expect(AlphaLabels.isValid("A@") == false)
    }
    
    @Test("Error cases")
    func errorCases() throws {
        #expect(throws: AlphaLabelError.nonPositiveIndex(0)) {
            try AlphaLabels.label(for: 0)
        }
        
        #expect(throws: AlphaLabelError.nonPositiveIndex(-1)) {
            try AlphaLabels.label(for: -1)
        }
        
        #expect(throws: AlphaLabelError.invalidLabel("123")) {
            try AlphaLabels.index(of: "123")
        }
        
        #expect(throws: AlphaLabelError.invalidLabel("")) {
            try AlphaLabels.index(of: "")
        }
    }
    
    @Test("Sequence generation")
    func sequenceGeneration() throws {
        let sequence = try AlphaLabels.sequence(from: "C")
        let first10 = Array(sequence.prefix(10))
        #expect(first10 == ["C", "D", "E", "F", "G", "H", "I", "J", "K", "L"])
        
        let sequenceFromY = try AlphaLabels.sequence(from: "Y")
        let first5 = Array(sequenceFromY.prefix(5))
        #expect(first5 == ["Y", "Z", "AA", "AB", "AC"])
    }
    
    @Test("Round trip conversion")
    func roundTripConversion() throws {
        let testCases = ["A", "Z", "AA", "AZ", "BA", "ZZ", "AAA", "ZZZ"]
        
        for original in testCases {
            let index = try AlphaLabels.index(of: original)
            let converted = try AlphaLabels.label(for: index)
            #expect(converted == original)
        }
        
        for i in 1...1000 {
            let label = try AlphaLabels.label(for: i)
            let index = try AlphaLabels.index(of: label)
            #expect(index == i)
        }
    }
    
    @Test("Boundary cases")
    func boundaryCases() throws {
        #expect(try AlphaLabels.generate(from: "A", count: 0) == [])
        
        let largeIndex = 18278
        let largeLabel = try AlphaLabels.label(for: largeIndex)
        #expect(try AlphaLabels.index(of: largeLabel) == largeIndex)
        
        #expect(try AlphaLabels.label(for: 1) == "A")
        #expect(try AlphaLabels.label(for: 26) == "Z")
        #expect(try AlphaLabels.label(for: 27) == "AA")
        #expect(try AlphaLabels.label(for: 702) == "ZZ")
        #expect(try AlphaLabels.label(for: 703) == "AAA")
        #expect(try AlphaLabels.label(for: 18278) == "ZZZ")
        #expect(try AlphaLabels.label(for: 18279) == "AAAA")
    }
}
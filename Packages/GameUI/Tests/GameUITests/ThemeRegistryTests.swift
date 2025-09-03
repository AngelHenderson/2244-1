import Testing
import SwiftUI
@testable import GameUI

struct ThemeRegistryTests {
    @Test
    @MainActor
    func testLookupByIdReturnsDescriptor() {
        let registry = ThemeRegistry.Default
        let classic = registry.descriptor(for: "classic")
        #expect(classic.id == "classic")
        #expect(classic.name == "Classic")
        #expect(classic.tileShape == .rounded)

        let classicSquare = registry.descriptor(for: "classic-square")
        #expect(classicSquare.id == "classic-square")
        #expect(classicSquare.tileShape == .square)
    }

    @Test
    @MainActor
    func testFallbackToDefaultWhenIdUnknownOrNil() {
        let registry = ThemeRegistry.Default
        let fallback1 = registry.descriptor(for: nil)
        let fallback2 = registry.descriptor(for: "does-not-exist")
        #expect(fallback1.id == registry.defaultDescriptor.id)
        #expect(fallback2.id == registry.defaultDescriptor.id)
    }
}



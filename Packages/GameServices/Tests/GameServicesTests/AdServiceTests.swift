import Testing
@testable import GameCore

struct AdServiceTests {
    @Test
    @MainActor
    func testDummyAdService() async {
        let service = DummyAdService()
        
        await service.showBanner()
        #expect(service.isBannerVisible)
        
        await service.hideBanner()
        #expect(!service.isBannerVisible)
    }
}

import Testing
@testable import GameServices

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
import Testing
@testable import GameCore
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

    @Test
    @MainActor
    func liveAdServiceRespectsAdFreeEntitlement() async {
        let service = LiveAdService()
        service.setAdFree(true)

        await service.showBanner()
        #expect(!service.isBannerVisible)

        let didShowInterstitial = await service.showInterstitial()
        #expect(!didShowInterstitial)

        var rewardGranted = false
        let didReward = await service.showRewarded {
            rewardGranted = true
        }
        #expect(!didReward)
        #expect(!rewardGranted)
    }
}

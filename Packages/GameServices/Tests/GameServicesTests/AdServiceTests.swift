import Foundation
import Testing
@testable import GameCore
@testable import GameServices

struct AdServiceTests {
    @Test
    func adMobIDsResolveDebugFallbackForPackageTests() {
        let ids = AdMobIDs.resolved(from: Bundle(for: AdServiceTestMarker.self))

        #expect(ids == .debug)
        #expect(ids.appID == "ca-app-pub-3940256099942544~1458002511")
        #expect(ids.banner == "ca-app-pub-3940256099942544/6300978111")
        #expect(ids.interstitial == "ca-app-pub-3940256099942544/1033173712")
        #expect(ids.rewarded == "ca-app-pub-3940256099942544/5224354917")
        #expect(ids.rewardedInterstitial == "ca-app-pub-3940256099942544/5354046379")
    }

    @Test
    func adConfigurationUsesCurrentAdMobIDs() {
        let test = AdConfiguration.test
        let production = AdConfiguration.production

        #expect(test.bannerId == AdMobIDs.debug.banner)
        #expect(test.interstitialId == AdMobIDs.debug.interstitial)
        #expect(test.rewardedId == AdMobIDs.debug.rewarded)
        #expect(test.rewardedInterstitialId == AdMobIDs.debug.rewardedInterstitial)

        #expect(production.bannerId == AdMobIDs.production.banner)
        #expect(production.interstitialId == AdMobIDs.production.interstitial)
        #expect(production.rewardedId == AdMobIDs.production.rewarded)
        #expect(production.rewardedInterstitialId == AdMobIDs.production.rewardedInterstitial)
    }

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
    func dummyAdServiceGrantsRewardedCallbacks() async {
        let service = DummyAdService()
        var rewardedCount = 0

        let didReward = await service.showRewarded {
            rewardedCount += 1
        }
        let didRewardInterstitial = await service.showRewardedInterstitial {
            rewardedCount += 1
        }

        #expect(didReward)
        #expect(didRewardInterstitial)
        #expect(rewardedCount == 2)
    }

    @Test
    @MainActor
    func dummyAdServiceRespectsAdFreeEntitlement() async {
        let service = DummyAdService()
        service.setAdFree(true)

        await service.showBanner()
        #expect(!service.isBannerVisible)

        let didShowInterstitial = await service.showInterstitial()
        #expect(!didShowInterstitial)

        var rewardGranted = false
        let didReward = await service.showRewarded {
            rewardGranted = true
        }
        let didRewardInterstitial = await service.showRewardedInterstitial {
            rewardGranted = true
        }

        #expect(!didReward)
        #expect(!didRewardInterstitial)
        #expect(!rewardGranted)
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
        let didRewardInterstitial = await service.showRewardedInterstitial {
            rewardGranted = true
        }
        #expect(!didReward)
        #expect(!didRewardInterstitial)
        #expect(!rewardGranted)
    }
}

private final class AdServiceTestMarker {}

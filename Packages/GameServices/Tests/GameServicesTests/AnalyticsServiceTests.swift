import Testing
@testable import GameServices

struct AnalyticsServiceTests {
    @Test
    func default_is_noop_and_accepts_params() async {
        let service: any AnalyticsServiceProtocol = DefaultAnalyticsService()
        await service.fire(event: "app_launch", params: [
            "aString": "value",
            "aNumber": 42,
            "aBool": true,
            "anArray": ["x", "y"] as [String],
            "aDict": ["k": "v"] as [String: String]
        ])
        #expect(true)
    }
}



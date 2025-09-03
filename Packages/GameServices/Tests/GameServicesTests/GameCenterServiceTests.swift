import Testing
@testable import GameServices

struct GameCenterServiceTests {
    @Test
    func authenticate_returns_true() async {
        let service: any GameCenterServiceProtocol = DefaultGameCenterService()
        let result = await service.authenticate()
        #expect(result == true)
    }
    
    @Test
    func submit_stores_last_submission() async throws {
        let service = DefaultGameCenterService()
        try await service.submit(score: 12345, leaderboard: "main")
        let last = await service.lastSubmitted
        #expect(last?.score == 12345)
        #expect(last?.leaderboard == "main")
    }
}





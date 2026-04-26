import Testing
@testable import GameCore

struct GameCenterServiceTests {
    @Test
    func leaderboard_ids_match_app_store_connect_contract() {
        #expect(GameCenterLeaderboardID.global == "com.game2244.global")
        #expect(GameCenterLeaderboardID.hallOfFame == "com.game2244.halloffame")
    }
    
    @Test
    func submit_stores_last_submission_before_gamekit_delivery() async {
        let service = DefaultGameCenterService()
        do {
            try await service.submit(score: 12345, leaderboard: GameCenterLeaderboardID.global)
        } catch {
            // Unit tests should not require a signed-in Game Center account.
        }
        let last = await service.lastSubmitted
        #expect(last?.score == 12345)
        #expect(last?.leaderboard == GameCenterLeaderboardID.global)
    }
}



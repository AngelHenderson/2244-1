import Foundation
import Testing
@testable import GameServices

struct RemoteConfigServiceTests {
    @Test
    func testDecodingRemoteConfig_withISO8601Dates() throws {
        let json = #"""
        {
          "banner": {
            "text": "Limited time bonus!",
            "start": "2024-01-01T00:00:00Z",
            "end": "2024-01-07T23:59:59Z"
          },
          "scoringComboWindowMs": 900,
          "adsCooldownSec": 45,
          "rewardContinueMoves": 2,
          "spawnWeightsJSON": "{\"2\":70,\"4\":30}"
        }
        """#.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let cfg = try decoder.decode(RemoteConfig.self, from: json)
        #expect(cfg.banner?.text == "Limited time bonus!")
        #expect(cfg.scoringComboWindowMs == 900)
        #expect(cfg.adsCooldownSec == 45)
        #expect(cfg.rewardContinueMoves == 2)
        #expect(cfg.spawnWeightsJSON == "{\"2\":70,\"4\":30}")
        
        // Spot-check date decoding
        let iso = ISO8601DateFormatter()
        #expect(cfg.banner?.start == iso.date(from: "2024-01-01T00:00:00Z"))
        #expect(cfg.banner?.end == iso.date(from: "2024-01-07T23:59:59Z"))
    }
    
    @Test
    func testDecodingRemoteConfig_partial() throws {
        let json = #"""
        {
          "banner": { "text": "Hello" }
        }
        """#.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let cfg = try decoder.decode(RemoteConfig.self, from: json)
        #expect(cfg.banner?.text == "Hello")
        #expect(cfg.banner?.start == nil)
        #expect(cfg.banner?.end == nil)
        #expect(cfg.scoringComboWindowMs == nil)
        #expect(cfg.adsCooldownSec == nil)
        #expect(cfg.rewardContinueMoves == nil)
        #expect(cfg.spawnWeightsJSON == nil)
    }
    
    @Test
    func testDefaultRemoteConfigService_returnsFallback() async {
        let service = DefaultRemoteConfigService()
        let cfg = await service.fetch()
        #expect(cfg == DefaultRemoteConfigService.fallback)
    }
}



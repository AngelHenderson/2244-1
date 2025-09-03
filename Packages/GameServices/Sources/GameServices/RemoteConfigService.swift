import Foundation

public struct Banner: Codable, Sendable, Equatable {
    public let text: String
    public let start: Date?
    public let end: Date?
    
    public init(text: String, start: Date? = nil, end: Date? = nil) {
        self.text = text
        self.start = start
        self.end = end
    }
}

public struct RemoteConfig: Codable, Sendable, Equatable {
    public let banner: Banner?
    public let scoringComboWindowMs: Int?
    public let adsCooldownSec: Int?
    public let rewardContinueMoves: Int?
    public let spawnWeightsJSON: String?
    
    public init(
        banner: Banner? = nil,
        scoringComboWindowMs: Int? = nil,
        adsCooldownSec: Int? = nil,
        rewardContinueMoves: Int? = nil,
        spawnWeightsJSON: String? = nil
    ) {
        self.banner = banner
        self.scoringComboWindowMs = scoringComboWindowMs
        self.adsCooldownSec = adsCooldownSec
        self.rewardContinueMoves = rewardContinueMoves
        self.spawnWeightsJSON = spawnWeightsJSON
    }
}

public protocol RemoteConfigServiceProtocol: Sendable {
    func fetch() async -> RemoteConfig
}

public struct DefaultRemoteConfigService: RemoteConfigServiceProtocol, Sendable {
    public static let fallback: RemoteConfig = RemoteConfig(
        banner: Banner(text: "Get 3 free moves!"),
        scoringComboWindowMs: 800,
        adsCooldownSec: 60,
        rewardContinueMoves: 3,
        spawnWeightsJSON: "{\"2\":60,\"4\":40}"
    )
    
    public init() {}
    
    public func fetch() async -> RemoteConfig {
        Self.fallback
    }
}



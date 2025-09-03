import Foundation

public protocol AudioServiceProtocol: Sendable {
    func setMusicEnabled(_ enabled: Bool)
    func setSfxEnabled(_ enabled: Bool)
    func playMusic(loop: Bool)
    func stopMusic()
    func playSfx(name: String)
}

public struct DefaultAudioService: AudioServiceProtocol, Sendable {
    private let suiteName: String?
    private let musicKey: String
    private let sfxKey: String
    
    public init(
        suiteName: String? = nil,
        musicKey: String = "musicEnabled",
        sfxKey: String = "sfxEnabled"
    ) {
        self.suiteName = suiteName
        self.musicKey = musicKey
        self.sfxKey = sfxKey
    }
    
    private var userDefaults: UserDefaults {
        if let suiteName, let ud = UserDefaults(suiteName: suiteName) {
            return ud
        }
        return .standard
    }
    
    public func setMusicEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: musicKey)
    }
    
    public func setSfxEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: sfxKey)
    }
    
    public func playMusic(loop: Bool) {
        // no-op (intentionally)
    }
    
    public func stopMusic() {
        // no-op (intentionally)
    }
    
    public func playSfx(name: String) {
        // no-op (intentionally)
    }
}



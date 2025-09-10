import Foundation
import AVFoundation

public protocol AudioServiceProtocol: Sendable {
    func setMusicEnabled(_ enabled: Bool) async
    func setSfxEnabled(_ enabled: Bool) async
    func playMusic(loop: Bool) async
    func playMusic(named fileName: String, loop: Bool) async
    func stopMusic() async
    func playSfx(name: String) async
    func setCurrentMusicTheme(_ theme: String) async
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
    
    public func setMusicEnabled(_ enabled: Bool) async {
        userDefaults.set(enabled, forKey: musicKey)
    }
    
    public func setSfxEnabled(_ enabled: Bool) async {
        userDefaults.set(enabled, forKey: sfxKey)
    }
    
    public func playMusic(loop: Bool) async {
        // no-op (intentionally)
    }
    
    public func playMusic(named fileName: String, loop: Bool) async {
        // no-op (intentionally)
    }
    
    public func stopMusic() async {
        // no-op (intentionally)
    }
    
    public func playSfx(name: String) async {
        // no-op (intentionally)
    }
    
    public func setCurrentMusicTheme(_ theme: String) async {
        userDefaults.set(theme, forKey: "currentMusicTheme")
    }
}

public actor LiveAudioService: AudioServiceProtocol {
    private var musicPlayer: AVAudioPlayer?
    private var sfxPlayers: [AVAudioPlayer] = []
    private var currentMusicTheme: String = ""
    private var pianoTapIndex: Int = 0
    
    private let userDefaults = UserDefaults.standard
    private let musicKey = "musicEnabled"
    private let sfxKey = "sfxEnabled"
    
    public init() {
        Task { @MainActor in
            // Configure audio session on main actor (iOS only)
            #if os(iOS)
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to configure audio session: \(error)")
            }
            #endif
        }
    }
    
    public func setMusicEnabled(_ enabled: Bool) async {
        userDefaults.set(enabled, forKey: musicKey)
        if !enabled {
            await stopMusic()
        }
    }
    
    public func setSfxEnabled(_ enabled: Bool) async {
        userDefaults.set(enabled, forKey: sfxKey)
    }
    
    public func playMusic(loop: Bool) async {
        guard userDefaults.bool(forKey: musicKey) else { return }
        // Default background music
        await playMusic(named: "background", loop: loop)
    }
    
    public func playMusic(named fileName: String, loop: Bool) async {
        guard userDefaults.bool(forKey: musicKey) else { return }
        
        await stopMusic()
        
        // Try different path combinations
        var url: URL?
        
        // For piano files, look in Audio/Pianos subdirectory
        if fileName.hasPrefix("piano_") {
            url = Bundle.main.url(forResource: fileName, withExtension: "mp3", subdirectory: "Audio/Pianos")
            print("🎵 Looking for piano file: \(fileName) in Audio/Pianos, found: \(url != nil)")
        }
        
        // Fallback to root bundle
        if url == nil {
            url = Bundle.main.url(forResource: fileName, withExtension: "mp3") ?? 
                  Bundle.main.url(forResource: fileName, withExtension: "wav")
        }
        
        guard let audioUrl = url else {
            print("❌ Audio file not found: \(fileName)")
            return
        }
        
        do {
            print("🎵 Playing music: \(fileName) from \(audioUrl)")
            musicPlayer = try AVAudioPlayer(contentsOf: audioUrl)
            musicPlayer?.numberOfLoops = loop ? -1 : 0
            musicPlayer?.volume = 0.6
            musicPlayer?.play()
            print("✅ Music started playing: \(fileName)")
        } catch {
            print("❌ Failed to play music: \(error)")
        }
    }
    
    public func stopMusic() async {
        musicPlayer?.stop()
        musicPlayer = nil
    }
    
    public func playSfx(name: String) async {
        guard userDefaults.bool(forKey: sfxKey) else { return }
        
        // Handle piano-specific sounds
        if currentMusicTheme == "piano" && (name == "tap" || name == "select" || name == "drag") {
            await playPianoTapSound()
            return
        }
        
        // Try different path combinations for SFX
        var url: URL?
        
        // For piano files, look in Audio/Pianos subdirectory
        if name.hasPrefix("piano_") {
            url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "Audio/Pianos")
        }
        
        // Fallback to root bundle
        if url == nil {
            url = Bundle.main.url(forResource: name, withExtension: "mp3") ?? 
                  Bundle.main.url(forResource: name, withExtension: "wav")
        }
        
        guard let audioUrl = url else {
            print("SFX file not found: \(name)")
            return
        }
        
        do {
            print("🔊 Playing SFX: \(name) from \(audioUrl)")
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.volume = 0.8
            player.play()
            print("✅ SFX started playing: \(name)")
            
            // Keep reference to prevent deallocation
            sfxPlayers.append(player)
            
            // Remove completed players
            Task {
                try? await Task.sleep(for: .seconds(player.duration + 0.1))
                await removeSfxPlayer(player)
            }
        } catch {
            print("Failed to play SFX: \(error)")
        }
    }
    
    public func setCurrentMusicTheme(_ theme: String) async {
        currentMusicTheme = theme
        userDefaults.set(theme, forKey: "currentMusicTheme")
    }
    
    private func playPianoTapSound() async {
        let pianoSounds = ["piano_tap_1", "piano_tap_2", "piano_tap_3"]
        let soundName = pianoSounds[pianoTapIndex]
        pianoTapIndex = (pianoTapIndex + 1) % pianoSounds.count
        
        // Try different path combinations for piano tap sounds
        var url: URL?
        
        // Look in Audio/Pianos subdirectory first
        url = Bundle.main.url(forResource: soundName, withExtension: "mp3", subdirectory: "Audio/Pianos")
        
        // Fallback to root bundle
        if url == nil {
            url = Bundle.main.url(forResource: soundName, withExtension: "mp3") ?? 
                  Bundle.main.url(forResource: soundName, withExtension: "wav")
        }
        
        guard let audioUrl = url else {
            print("Piano tap sound not found: \(soundName)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.volume = 0.7
            player.play()
            
            sfxPlayers.append(player)
            
            Task {
                try? await Task.sleep(for: .seconds(player.duration + 0.1))
                await removeSfxPlayer(player)
            }
        } catch {
            print("Failed to play piano tap sound: \(error)")
        }
    }
    
    private func removeSfxPlayer(_ player: AVAudioPlayer) async {
        sfxPlayers.removeAll { $0 === player }
    }
}



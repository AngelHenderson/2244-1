import Foundation
import AVFoundation
import SwiftUI
import GameCore

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

// Storage adapter to avoid @AppStorage inside @Observable
@MainActor
final class AudioSettingsStorage: ObservableObject {
    @AppStorage("musicEnabled") var musicEnabled: Bool = true
    @AppStorage("sfxEnabled") var sfxEnabled: Bool = true
    @AppStorage("currentMusicTheme") var currentMusicTheme: String = ""
}

public actor LiveAudioService: AudioServiceProtocol {
    private var musicPlayer: AVAudioPlayer?
    private var sfxPlayers: [AVAudioPlayer] = []
    private var instrumentTapIndex: Int = 0
    private let storage = AudioSettingsStorage()

    /// Maps theme IDs to their audio configuration
    /// Note: Files are at bundle root level (synchronized groups flatten directory structure)
    private struct InstrumentConfig {
        let filePrefix: String
        let tapSoundCount: Int

        static let configs: [String: InstrumentConfig] = [
            "piano": InstrumentConfig(filePrefix: "piano_tap_", tapSoundCount: 3),
            "xylophone": InstrumentConfig(filePrefix: "xylophone_tap_", tapSoundCount: 3),
            "guitar": InstrumentConfig(filePrefix: "guitar_tap_", tapSoundCount: 3),
            "kalimba": InstrumentConfig(filePrefix: "kalimba_tap_", tapSoundCount: 3),
            "muted-nylon": InstrumentConfig(filePrefix: "muted_nylon_tap_", tapSoundCount: 3),
            "drum": InstrumentConfig(filePrefix: "drum_tap_", tapSoundCount: 3)
        ]

        static let defaultConfig = InstrumentConfig(filePrefix: "piano_tap_", tapSoundCount: 3)
    }
    
    public init() {
        Task { @MainActor in
            print("🎵 Initialized LiveAudioService with theme: '\(storage.currentMusicTheme)'")
            
            // Configure audio session (iOS only)
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
        await MainActor.run { storage.musicEnabled = enabled }
        if !enabled {
            await stopMusic()
        }
    }
    
    public func setSfxEnabled(_ enabled: Bool) async {
        await MainActor.run { storage.sfxEnabled = enabled }
    }
    
    public func playMusic(loop: Bool) async {
        let enabled = await MainActor.run { storage.musicEnabled }
        guard enabled else { return }
        // Default background music
        await playMusic(named: "background", loop: loop)
    }
    
    public func playMusic(named fileName: String, loop: Bool) async {
        let enabled = await MainActor.run { storage.musicEnabled }
        guard enabled else { return }

        await stopMusic()

        // Look for audio file at bundle root (synchronized groups flatten directory structure)
        let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") ??
                  Bundle.main.url(forResource: fileName, withExtension: "wav")

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
        let (sfxEnabled, currentTheme) = await MainActor.run { 
            (storage.sfxEnabled, storage.currentMusicTheme) 
        }
        
        guard sfxEnabled else { 
            print("🔇 SFX disabled, not playing: \(name)")
            return 
        }
        
        print("🔊 Playing SFX: \(name), current theme: '\(currentTheme)'")

        // Handle merge and chain sounds - play instrument-specific tap sounds
        if name == "merge" || name == "chain" {
            print("🎶 Playing \(name) sound for instrument: \(currentTheme)")
            await playInstrumentTapSound(theme: currentTheme)
            return
        }

        // Handle magnet electric sound
        if name == "electric" || name == "magnet" {
            print("⚡ Playing electric/magnet sound for instrument: \(currentTheme)")
            await playElectricSound(theme: currentTheme)
            return
        }

        // Handle tap/select/drag sounds - play instrument-specific sounds
        if name == "tap" || name == "select" || name == "drag" {
            print("🎹 Playing instrument sound for: \(name), theme: \(currentTheme)")
            await playInstrumentTapSound(theme: currentTheme)
            return
        }
        
        // Look for SFX at bundle root (synchronized groups flatten directory structure)
        let url = Bundle.main.url(forResource: name, withExtension: "mp3") ??
                  Bundle.main.url(forResource: name, withExtension: "wav")

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
        print("🎵 Setting music theme to: '\(theme)'")
        await MainActor.run { storage.currentMusicTheme = theme }
        let newTheme = await MainActor.run { storage.currentMusicTheme }
        print("🎵 Music theme set successfully: '\(newTheme)'")
    }
    
    private func playElectricSound(theme: String) async {
        // Normalize empty theme to piano
        let effectiveTheme = theme.isEmpty ? "piano" : theme

        // Get config for current theme, fall back to piano
        let config = InstrumentConfig.configs[effectiveTheme] ?? InstrumentConfig.defaultConfig

        // Play rapid succession of notes to simulate electric/buzzing effect
        let soundCount = config.tapSoundCount

        for index in 1...soundCount {
            let soundName = "\(config.filePrefix)\(index)"

            // Try instrument-specific sound first, fall back to piano
            // All files are at bundle root (synchronized groups flatten directory structure)
            var url = Bundle.main.url(forResource: soundName, withExtension: "mp3")

            // Fall back to piano sounds if instrument sound not found
            if url == nil {
                let pianoSoundName = "piano_tap_\(index)"
                url = Bundle.main.url(forResource: pianoSoundName, withExtension: "mp3") ??
                      Bundle.main.url(forResource: pianoSoundName, withExtension: "wav")
            }

            guard let audioUrl = url else { continue }

            do {
                let player = try AVAudioPlayer(contentsOf: audioUrl)
                player.volume = 0.5  // Slightly quieter for layered effect
                player.play()
                sfxPlayers.append(player)

                Task {
                    try? await Task.sleep(for: .seconds(player.duration + 0.1))
                    await removeSfxPlayer(player)
                }
            } catch {
                print("❌ Failed to play electric sound: \(error)")
            }

            // Small delay between notes for electric effect
            if index < soundCount {
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func playInstrumentTapSound(theme: String) async {
        // Normalize empty theme to piano
        let effectiveTheme = theme.isEmpty ? "piano" : theme

        // Get config for current theme, fall back to piano
        let config = InstrumentConfig.configs[effectiveTheme] ?? InstrumentConfig.defaultConfig

        // Cycle through available tap sounds
        let soundIndex = (instrumentTapIndex % config.tapSoundCount) + 1
        instrumentTapIndex = (instrumentTapIndex + 1) % config.tapSoundCount

        let soundName = "\(config.filePrefix)\(soundIndex)"
        print("🎹 Attempting to play \(effectiveTheme) sound: \(soundName) (index: \(soundIndex))")

        // All files are at bundle root (synchronized groups flatten directory structure)
        // Try instrument-specific sound first
        var url = Bundle.main.url(forResource: soundName, withExtension: "mp3")

        // Fall back to piano sounds if not found
        if url == nil {
            let pianoSoundName = "piano_tap_\(soundIndex)"
            url = Bundle.main.url(forResource: pianoSoundName, withExtension: "mp3") ??
                  Bundle.main.url(forResource: pianoSoundName, withExtension: "wav")
            if effectiveTheme != "piano" {
                print("🎹 Falling back to piano sound: \(url != nil ? "found" : "not found")")
            }
        }

        guard let audioUrl = url else {
            print("❌ Tap sound not found for \(effectiveTheme): \(soundName)")
            return
        }

        do {
            print("🎹 Playing \(effectiveTheme) sound: \(soundName) from \(audioUrl)")
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.volume = 0.7
            player.play()
            print("✅ \(effectiveTheme.capitalized) sound started playing: \(soundName)")

            sfxPlayers.append(player)

            Task {
                try? await Task.sleep(for: .seconds(player.duration + 0.1))
                await removeSfxPlayer(player)
            }
        } catch {
            print("❌ Failed to play \(effectiveTheme) tap sound: \(error)")
        }
    }
    
    private func removeSfxPlayer(_ player: AVAudioPlayer) async {
        sfxPlayers.removeAll { $0 === player }
    }
}



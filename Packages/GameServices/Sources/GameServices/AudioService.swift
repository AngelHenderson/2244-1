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

    public func playMergeSfx(tileCount: Int) async {
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
    @AppStorage("currentMusicTheme") var currentMusicTheme: String = "piano"
}

public actor LiveAudioService: AudioServiceProtocol {
    private var musicPlayer: AVAudioPlayer?
    private var sfxPlayers: [AVAudioPlayer] = []
    private var instrumentTapIndex: Int = 0
    private let storage = AudioSettingsStorage()
    private let maxConcurrentSfx = 8  // Limit concurrent sound effects
    private var lastHammerPlayTime: Date?  // Debounce hammer sound
    private var lastElectricPlayTime: Date?  // Debounce electric sound

    /// Maps theme IDs to their audio configuration
    /// Note: Files are at bundle root level (synchronized groups flatten directory structure)
    private struct InstrumentConfig {
        let filePrefix: String
        let tapSoundCount: Int      // Number of separate files OR notes in single file
        let notesInSingleFile: Int  // If > 1, plays portions of one file instead of loading multiple files

        init(filePrefix: String, tapSoundCount: Int, notesInSingleFile: Int = 0) {
            self.filePrefix = filePrefix
            self.tapSoundCount = tapSoundCount
            self.notesInSingleFile = notesInSingleFile
        }

        static let configs: [String: InstrumentConfig] = [
            "piano": InstrumentConfig(filePrefix: "piano_tap_", tapSoundCount: 3),
            "xylophone": InstrumentConfig(filePrefix: "xylophone_tap_", tapSoundCount: 2),  // Alternates 1, 2
            "guitar": InstrumentConfig(filePrefix: "guitar_tap_", tapSoundCount: 20, notesInSingleFile: 20),  // 20 notes in one file
            "kalimba": InstrumentConfig(filePrefix: "kalimba_tap_", tapSoundCount: 12, notesInSingleFile: 12),  // 12 notes in one file
            "muted-nylon": InstrumentConfig(filePrefix: "muted_nylon_tap_", tapSoundCount: 1),
            "drum": InstrumentConfig(filePrefix: "drum_tap_", tapSoundCount: 6, notesInSingleFile: 6)  // 6 notes in one file
        ]

        static let defaultConfig = InstrumentConfig(filePrefix: "piano_tap_", tapSoundCount: 3)
    }
    
    public init() {
        Task { @MainActor in
            print("🎵 Initialized LiveAudioService with theme: '\(storage.currentMusicTheme)'")

            // Configure audio session (iOS only)
            #if os(iOS)
            do {
                let session = AVAudioSession.sharedInstance()
                // Use .playback with mixWithOthers to play sounds alongside other apps (YouTube, etc.)
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true, options: [])
                print("🎵 Audio session configured successfully")
            } catch {
                print("❌ Failed to configure audio session: \(error)")
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

        // Handle merge sound - play single instrument tap sound
        if name == "merge" {
            print("🎶 Playing merge sound for instrument: \(currentTheme)")
            await playInstrumentTapSound(theme: currentTheme)
            return
        }

        // Handle chain sound - play subtle tick while building chain
        // (instrument notes only play on merge via playMergeSfx)
        if name == "chain" {
            await playChainTickSound()
            return
        }

        // Handle magnet electric sound
        if name == "electric" || name == "magnet" {
            print("⚡ Playing electric/magnet sound for instrument: \(currentTheme)")
            await playElectricSound(theme: currentTheme)
            return
        }

        // Handle hammer sound (axe smashing)
        if name == "hammer" {
            print("🪓 Playing hammer/axe smash sound")
            await playHammerSound()
            return
        }

        // Handle tick sound (wheel spinner)
        if name == "tick" {
            await playTickSound()
            return
        }

        // Handle cheer sound (year milestones)
        if name == "cheer" {
            await playCheerSound()
            return
        }

        // Handle select sound - play subtle tick (not instrument tap, to avoid extra notes)
        if name == "select" {
            await playChainTickSound()
            return
        }

        // Handle tap/drag sounds - play instrument-specific sounds
        if name == "tap" || name == "drag" {
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

    public func playMergeSfx(tileCount: Int) async {
        let (sfxEnabled, currentTheme) = await MainActor.run {
            (storage.sfxEnabled, storage.currentMusicTheme)
        }

        guard sfxEnabled else {
            print("🔇 SFX disabled, not playing merge sounds")
            return
        }

        print("🎶 Playing \(tileCount) merge notes for instrument: \(currentTheme)")

        // Play notes in sequence based on tile count
        let notesToPlay = max(1, min(tileCount, 6))  // Cap at 6 notes
        let delayBetweenNotes: Double = 0.08  // 80ms between notes for quick arpeggio

        for i in 0..<notesToPlay {
            await playInstrumentTapSound(theme: currentTheme)
            if i < notesToPlay - 1 {
                try? await Task.sleep(for: .seconds(delayBetweenNotes))
            }
        }
    }

    private func playElectricSound(theme: String) async {
        // Debounce - don't play if played within last 0.5 seconds
        if let lastPlay = lastElectricPlayTime, Date().timeIntervalSince(lastPlay) < 0.5 {
            print("🔇 Electric sound debounced")
            return
        }
        lastElectricPlayTime = Date()

        // Clean up before adding new sounds
        cleanupAndPrepareForNewSound()

        // Play the electric zap sound file
        let url = Bundle.main.url(forResource: "electric_zap", withExtension: "mp3") ??
                  Bundle.main.url(forResource: "electric_zap", withExtension: "wav")

        guard let audioUrl = url else {
            print("❌ Electric zap sound not found in bundle")
            // List available resources for debugging
            if let resourcePath = Bundle.main.resourcePath {
                print("📁 Bundle path: \(resourcePath)")
            }
            return
        }

        do {
            print("⚡ Creating player for electric sound: \(audioUrl)")
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.volume = 0.7
            player.prepareToPlay()
            let success = player.play()
            print("⚡ Electric sound play result: \(success)")
            sfxPlayers.append(player)

            Task {
                try? await Task.sleep(for: .seconds(player.duration + 0.1))
                await removeSfxPlayer(player)
            }
        } catch {
            print("❌ Failed to play electric sound: \(error)")
        }
    }

    private func playHammerSound() async {
        // Debounce - don't play if played within last 0.5 seconds
        if let lastPlay = lastHammerPlayTime, Date().timeIntervalSince(lastPlay) < 0.5 {
            print("🔇 Hammer sound debounced")
            return
        }
        lastHammerPlayTime = Date()

        // Clean up before adding new sounds
        cleanupAndPrepareForNewSound()

        // Play the axe chop sound file
        let url = Bundle.main.url(forResource: "axe_chop", withExtension: "mp3") ??
                  Bundle.main.url(forResource: "axe_chop", withExtension: "wav")

        guard let audioUrl = url else {
            print("❌ Axe chop sound not found in bundle")
            // List available resources for debugging
            if let resourcePath = Bundle.main.resourcePath {
                print("📁 Bundle path: \(resourcePath)")
            }
            return
        }

        do {
            print("🪓 Creating player for hammer sound: \(audioUrl)")
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.volume = 0.8
            player.prepareToPlay()
            let success = player.play()
            print("🪓 Hammer sound play result: \(success)")
            sfxPlayers.append(player)

            Task {
                try? await Task.sleep(for: .seconds(player.duration + 0.1))
                await removeSfxPlayer(player)
            }
        } catch {
            print("❌ Failed to play hammer sound: \(error)")
        }
    }

    private func playChainTickSound() async {
        // Clean up before adding new sound
        cleanupAndPrepareForNewSound()

        // Use a subtle tick sound for chain building feedback
        let url = Bundle.main.url(forResource: "chain_tick", withExtension: "mp3") ??
                  Bundle.main.url(forResource: "chain_tick", withExtension: "wav") ??
                  Bundle.main.url(forResource: "tick", withExtension: "mp3") ??
                  Bundle.main.url(forResource: "tick", withExtension: "wav")

        guard let audioUrl = url else {
            print("❌ Chain tick sound not found")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.volume = 0.3  // Subtle volume for chain feedback
            player.play()
            sfxPlayers.append(player)

            Task {
                try? await Task.sleep(for: .seconds(player.duration + 0.1))
                await removeSfxPlayer(player)
            }
        } catch {
            print("❌ Failed to play chain tick sound: \(error)")
        }
    }

    private func playTickSound() async {
        // Clean up before adding new sound
        cleanupAndPrepareForNewSound()

        // Use dedicated tick sound for wheel spinner
        let url = Bundle.main.url(forResource: "tick", withExtension: "mp3") ??
                  Bundle.main.url(forResource: "tick", withExtension: "wav")

        guard let audioUrl = url else {
            print("❌ Tick sound not found")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.volume = 0.5
            player.play()
            sfxPlayers.append(player)

            Task {
                try? await Task.sleep(for: .seconds(player.duration + 0.1))
                await removeSfxPlayer(player)
            }
        } catch {
            print("❌ Failed to play tick sound: \(error)")
        }
    }

    private func playCheerSound() async {
        // Clean up before adding new sound
        cleanupAndPrepareForNewSound()

        // Play cheering/applause sound for year milestones
        let url = Bundle.main.url(forResource: "cheer", withExtension: "mp3") ??
                  Bundle.main.url(forResource: "cheer", withExtension: "wav") ??
                  Bundle.main.url(forResource: "applause", withExtension: "mp3") ??
                  Bundle.main.url(forResource: "applause", withExtension: "wav")

        guard let audioUrl = url else {
            print("❌ Cheer/applause sound not found")
            return
        }

        do {
            print("🎉 Playing cheer sound from \(audioUrl)")
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.volume = 0.8
            player.play()
            sfxPlayers.append(player)

            Task {
                try? await Task.sleep(for: .seconds(player.duration + 0.1))
                await removeSfxPlayer(player)
            }
        } catch {
            print("❌ Failed to play cheer sound: \(error)")
        }
    }

    private func playInstrumentTapSound(theme: String) async {
        // Clean up before adding new sound
        cleanupAndPrepareForNewSound()

        // Normalize empty theme to piano
        let effectiveTheme = theme.isEmpty ? "piano" : theme

        // Get config for current theme, fall back to piano
        let config = InstrumentConfig.configs[effectiveTheme] ?? InstrumentConfig.defaultConfig

        // Cycle through available tap sounds (0-indexed for note position calculation)
        let noteIndex = instrumentTapIndex % config.tapSoundCount
        instrumentTapIndex = (instrumentTapIndex + 1) % config.tapSoundCount

        // Handle single file with multiple notes (drum, kalimba)
        if config.notesInSingleFile > 0 {
            await playNoteFromSingleFile(theme: effectiveTheme, config: config, noteIndex: noteIndex)
            return
        }

        // Multiple separate files (piano, xylophone, guitar, muted-nylon)
        let soundIndex = noteIndex + 1  // Files are 1-indexed
        let soundName = "\(config.filePrefix)\(soundIndex)"
        print("🎹 Attempting to play \(effectiveTheme) sound: \(soundName) (index: \(soundIndex))")

        // All files are at bundle root (synchronized groups flatten directory structure)
        var url = Bundle.main.url(forResource: soundName, withExtension: "mp3")

        // Fall back to piano sounds if not found
        if url == nil {
            let pianoSoundName = "piano_tap_\((noteIndex % 3) + 1)"
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

    /// Play a specific note from a single audio file containing multiple notes
    private func playNoteFromSingleFile(theme: String, config: InstrumentConfig, noteIndex: Int) async {
        let soundName = "\(config.filePrefix)1"  // Always load file with suffix 1
        print("🎹 Looking for single-file sound: \(soundName).mp3 for theme: \(theme)")

        var url = Bundle.main.url(forResource: soundName, withExtension: "mp3") ??
                  Bundle.main.url(forResource: soundName, withExtension: "wav")

        // Fall back to piano if instrument file not found
        let usingFallback = (url == nil)
        if usingFallback {
            print("⚠️ Single-file sound not found: \(soundName), falling back to piano")
            let pianoSoundName = "piano_tap_\((noteIndex % 3) + 1)"
            url = Bundle.main.url(forResource: pianoSoundName, withExtension: "mp3") ??
                  Bundle.main.url(forResource: pianoSoundName, withExtension: "wav")
        }

        guard let audioUrl = url else {
            print("❌ No sound found for \(theme) or piano fallback")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.volume = 0.7

            // Only do note slicing if this is the original instrument file (not piano fallback)
            if !usingFallback && config.notesInSingleFile > 1 {
                let noteDuration = player.duration / Double(config.notesInSingleFile)
                let startTime = Double(noteIndex) * noteDuration
                player.currentTime = startTime
                print("🎹 Playing \(theme) note \(noteIndex + 1)/\(config.notesInSingleFile) from \(startTime)s")
                player.play()
                sfxPlayers.append(player)

                // Stop after one note's duration
                Task {
                    try? await Task.sleep(for: .seconds(noteDuration))
                    player.stop()
                    await removeSfxPlayer(player)
                }
            } else {
                // Piano fallback - play full sound
                print("🎹 Playing piano fallback sound")
                player.play()
                sfxPlayers.append(player)

                Task {
                    try? await Task.sleep(for: .seconds(player.duration + 0.1))
                    await removeSfxPlayer(player)
                }
            }
        } catch {
            print("❌ Failed to play \(theme) note: \(error)")
        }
    }
    
    private func removeSfxPlayer(_ player: AVAudioPlayer) async {
        sfxPlayers.removeAll { $0 === player }
    }

    /// Clean up finished players and ensure we don't exceed the limit
    private func cleanupAndPrepareForNewSound() {
        // Remove players that have finished playing
        sfxPlayers.removeAll { !$0.isPlaying }

        // If still too many, remove oldest ones
        while sfxPlayers.count >= maxConcurrentSfx {
            if let oldest = sfxPlayers.first {
                oldest.stop()
                sfxPlayers.removeFirst()
            }
        }

        // Always ensure audio session is active before playing
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .playback to ensure sounds play even when other apps (YouTube) are playing
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            print("⚠️ Failed to reactivate audio session: \(error)")
        }
        #endif
    }
}



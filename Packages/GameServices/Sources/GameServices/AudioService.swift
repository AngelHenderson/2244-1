import Foundation
import AVFoundation
import AudioToolbox
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
        print("⚠️🔇 DefaultAudioService.playSfx called (NO-OP) for: \(name) — LiveAudioService NOT injected!")
    }

    public func playMergeSfx(tileCount: Int) async {
        print("⚠️🔇 DefaultAudioService.playMergeSfx called (NO-OP) for tileCount: \(tileCount) — LiveAudioService NOT injected!")
    }

    public func stopTickSound() async {
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

/// Delegate to handle audio player interruptions and completion
private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate, Sendable {
    private let onInterruption: @Sendable () -> Void
    private let onFinished: @Sendable () -> Void
    
    init(onInterruption: @escaping @Sendable () -> Void, onFinished: @escaping @Sendable () -> Void) {
        self.onInterruption = onInterruption
        self.onFinished = onFinished
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinished()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Audio decode error: \(error?.localizedDescription ?? "unknown")")
        onInterruption()
    }
}

public actor LiveAudioService: AudioServiceProtocol {
    private var musicPlayer: AVAudioPlayer?
    private var musicPlayerDelegate: AudioPlayerDelegate?
    
    // Pool of SFX players keyed by local URL path to prevent AVFoundation object exhaustion
    private var sfxPlayerPool: [String: [AVAudioPlayer]] = [:]
    private var tickPlayers: [AVAudioPlayer] = []
    
    // Circuit breaker: track URLs that fail to instantiate so we stop retrying
    private var failedURLs: [String: (count: Int, lastAttempt: Date)] = [:]
    private let maxFailuresBeforeCircuitBreak = 3
    private let circuitBreakerCooldown: TimeInterval = 30  // Try again after 30 seconds
    
    // Log throttling: avoid spamming the same SFX log line
    private var lastSfxLogTime: [String: Date] = [:]
    private let sfxLogThrottleInterval: TimeInterval = 5
    
    private var instrumentTapIndex: Int = 0
    private let storage = AudioSettingsStorage()
    private let maxConcurrentIdenticalSfx = 4  // Limit concurrent IDENTICAL sound effects
    private var lastHammerPlayTime: Date?  // Debounce hammer sound
    private var lastElectricPlayTime: Date?  // Debounce electric sound
    private var currentMusicFileName: String?  // Track current music for restart
    private var currentMusicLoop: Bool = true  // Track loop setting for restart
    private var lastSessionCheck: Date = Date()

    // Actor-local cached copies of settings — avoids `await MainActor.run` on every audio call
    // Updated ONLY when settings change via setSfxEnabled / setMusicEnabled / setCurrentMusicTheme
    private var _cachedSfxEnabled: Bool = true
    private var _cachedMusicEnabled: Bool = true
    private var _cachedTheme: String = "piano"

    // SystemSoundID fallback: when AVAudioPlayer is broken (common in Simulator),
    // we fall back to AudioToolbox which uses a completely different CoreAudio path.
    private var _avPlayerBroken: Bool = false
    private var _systemSoundCache: [String: SystemSoundID] = [:]
    private var _recoveryTask: Task<Void, Never>? = nil

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
        // Configure audio session synchronously first (before any async work)
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            // Aggressive init: deactivate first to clear any stale state from previous launches
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            print("🎵 Audio session configured successfully in init")
        } catch {
            print("❌ Failed to configure audio session in init: \(error)")
        }
        #endif
        
        // Seed actor-local caches from storage on init
        // Read directly from UserDefaults to avoid actor isolation issues
        let defaults = UserDefaults.standard
        _cachedSfxEnabled = defaults.object(forKey: "sfxEnabled") as? Bool ?? true
        _cachedMusicEnabled = defaults.object(forKey: "musicEnabled") as? Bool ?? true
        _cachedTheme = defaults.string(forKey: "currentMusicTheme") ?? "piano"
        print("🎵 Initialized LiveAudioService — sfx=\(_cachedSfxEnabled), music=\(_cachedMusicEnabled), theme='\(_cachedTheme)'")
        
        // Schedule a startup probe to verify audio actually works
        Task { [weak self] in
            // Small delay to let the app finish launching
            try? await Task.sleep(for: .milliseconds(500))
            await self?.runStartupAudioProbe()
        }
    }

    /// Called from init Task to push MainActor-read values into actor state
    private func syncCachedSettings(sfx: Bool, music: Bool, theme: String) {
        _cachedSfxEnabled = sfx
        _cachedMusicEnabled = music
        _cachedTheme = theme
    }

    /// Test whether the audio subsystem can actually instantiate and play a sound.
    /// If it can't (common after simulator rebuild), mark AVAudioPlayer as broken
    /// and activate SystemSoundID fallback + start periodic recovery attempts.
    private func runStartupAudioProbe() {
        #if os(iOS)
        let probeURL = Bundle.main.url(forResource: "piano_tap_1", withExtension: "mp3")
            ?? Bundle.main.url(forResource: "piano_tap_1", withExtension: "wav")
        
        guard let url = probeURL else {
            print("🎵 Startup probe: no probe sound found (skipping)")
            return
        }
        
        do {
            let probe = try AVAudioPlayer(contentsOf: url)
            probe.volume = 0
            probe.prepareToPlay()
            if probe.play() {
                probe.stop()
                _avPlayerBroken = false
                print("✅ Startup audio probe: PASSED — AVAudioPlayer working")
            } else {
                print("⚠️ Startup audio probe: play() returned false — switching to SystemSoundID fallback")
                markAVPlayerBroken()
            }
        } catch {
            print("⚠️ Startup audio probe: init failed (\(error.localizedDescription)) — switching to SystemSoundID fallback")
            markAVPlayerBroken()
        }
        #endif
    }

    /// Mark AVAudioPlayer as broken and start periodic recovery attempts.
    private func markAVPlayerBroken() {
        _avPlayerBroken = true
        // Run aggressive recovery once in case it helps
        aggressiveAudioRecovery()
        // Start a background timer to periodically re-test AVAudioPlayer
        startRecoveryTimer()
    }

    /// Periodically attempt to recover AVAudioPlayer (every 10 seconds).
    /// If recovery succeeds, we switch back from SystemSoundID to AVAudioPlayer.
    private func startRecoveryTimer() {
        _recoveryTask?.cancel()
        _recoveryTask = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                attempt += 1
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                
                let recovered = await self.attemptAVPlayerRecovery(attempt: attempt)
                if recovered {
                    break
                }
            }
        }
    }

    /// Try to recover AVAudioPlayer. Returns true if recovered.
    private func attemptAVPlayerRecovery(attempt: Int) -> Bool {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            return false
        }
        
        guard let url = Bundle.main.url(forResource: "piano_tap_1", withExtension: "mp3")
                ?? Bundle.main.url(forResource: "piano_tap_1", withExtension: "wav") else {
            return false
        }
        
        do {
            let probe = try AVAudioPlayer(contentsOf: url)
            probe.volume = 0
            probe.prepareToPlay()
            if probe.play() {
                probe.stop()
                _avPlayerBroken = false
                // Nuke stale pool so fresh players are created
                sfxPlayerPool.removeAll()
                failedURLs.removeAll()
                print("✅ AVAudioPlayer recovery attempt #\(attempt): SUCCEEDED — switching back from SystemSoundID")
                return true
            }
        } catch {}
        
        if attempt <= 3 {
            print("🔄 AVAudioPlayer recovery attempt #\(attempt): still broken, using SystemSoundID fallback")
        }
        return false
        #else
        return true
        #endif
    }

    // MARK: - SystemSoundID Fallback

    /// Play a sound via AudioToolbox's SystemSoundID. This bypasses AVAudioPlayer's
    /// broken audio pipeline and uses a completely different CoreAudio code path.
    private func playViaSystemSound(url: URL) {
        let key = url.path
        
        if let existingID = _systemSoundCache[key] {
            AudioServicesPlaySystemSound(existingID)
            return
        }
        
        // Register a new SystemSoundID
        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        if status == kAudioServicesNoError {
            _systemSoundCache[key] = soundID
            AudioServicesPlaySystemSound(soundID)
        } else {
            print("❌ SystemSoundID fallback failed for \(url.lastPathComponent): OSStatus \(status)")
        }
    }

    /// Try to play via AVAudioPlayer first; if broken, use SystemSoundID fallback.
    /// Returns true if sound was played (via either path).
    @discardableResult
    private func playSound(url: URL, volume: Float = 0.7) -> Bool {
        // If AVAudioPlayer is known-broken, skip straight to fallback
        if _avPlayerBroken {
            playViaSystemSound(url: url)
            return true
        }
        
        // Try AVAudioPlayer
        if let player = getPooledPlayer(for: url) {
            player.volume = volume
            if player.play() {
                return true
            }
            // play() failed — try session recovery + one retry
            ensureAudioSessionActive()
            if player.play() {
                return true
            }
            // AVAudioPlayer is dead — mark broken and use fallback
            print("⚠️ AVAudioPlayer.play() failed twice — switching to SystemSoundID fallback")
            _avPlayerBroken = true
            startRecoveryTimer()
        }
        
        // Fallback
        playViaSystemSound(url: url)
        return true
    }
    
    /// Nuclear recovery: deactivate session, nuke stale player pool, reactivate.
    /// This handles the iOS Simulator bug where the virtual audio hardware disappears between builds.
    private func aggressiveAudioRecovery() {
        #if os(iOS)
        print("🔄 Running aggressive audio recovery...")
        
        let session = AVAudioSession.sharedInstance()
        
        // 1. Stop all current players (they were created against a dead audio device)
        for (_, players) in sfxPlayerPool {
            for player in players {
                player.stop()
            }
        }
        sfxPlayerPool.removeAll()
        for player in tickPlayers {
            player.stop()
        }
        tickPlayers.removeAll()
        musicPlayer?.stop()
        musicPlayer = nil
        musicPlayerDelegate = nil
        
        // 2. Clear circuit breaker state so sounds can be retried
        failedURLs.removeAll()
        
        // 3. Full session teardown + rebuild
        do {
            // Deactivate with notification — this forces the system to re-scan audio devices
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            
            // Re-set category from scratch
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            
            // Reactivate
            try session.setActive(true, options: [])
            
            print("✅ Aggressive audio recovery completed successfully")
        } catch {
            print("❌ Aggressive audio recovery failed: \(error)")
            
            // Last resort: try one more time after a brief delay
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                do {
                    try session.setActive(false, options: [.notifyOthersOnDeactivation])
                    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                    try session.setActive(true, options: [])
                    print("✅ Delayed audio recovery succeeded")
                } catch {
                    print("❌ Delayed audio recovery also failed: \(error). Simulator restart may be needed.")
                }
            }
        }
        #endif
    }

    private struct PlayerWrapper: @unchecked Sendable {
        let player: AVAudioPlayer
        func stop() {
            player.stop()
        }
    }

    private func removeTickPlayer(_ player: AVAudioPlayer) async {
        tickPlayers.removeAll { $0 === player }
    }

    /// We no longer destroy players in this method; we reuse them.
    private func cleanupAndPrepareForNewSound() {
        // Obsolete in pooling architecture, but kept blank so calls still resolve
    }

    /// Lightweight periodic check - runs every few seconds during active gameplay
    private func periodicAudioSessionCheck() {
        let now = Date()
        // Only check every 3 seconds to avoid overhead
        guard now.timeIntervalSince(lastSessionCheck) > 3.0 else { return }
        lastSessionCheck = now
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        
        // Check if session category was changed (another app took over)
        if session.category != .playback {
            print("⚠️ Audio session category changed, restoring...")
            aggressiveAudioRecovery()
        }
        
        // Check if music should be playing but stopped
        if let player = musicPlayer, !player.isPlaying, currentMusicFileName != nil {
            print("⚠️ Music stopped unexpectedly, recovering...")
            ensureAudioSessionActive()
            player.prepareToPlay()
            if !player.play() {
                // Full restart needed
                aggressiveAudioRecovery()
                Task {
                    if let fileName = self.currentMusicFileName {
                        await self.playMusic(named: fileName, loop: self.currentMusicLoop)
                    }
                }
            }
        }
        #endif
    }
    
    /// Reactivate audio session after interruption
    private func ensureAudioSessionActive() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        
        do {
            // Always re-set the category to ensure proper configuration
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            print("⚠️ Simple reactivation failed, trying aggressive recovery...")
            aggressiveAudioRecovery()
        }
        #endif
    }

    public func setMusicEnabled(_ enabled: Bool) async {
        await MainActor.run { storage.musicEnabled = enabled }
        _cachedMusicEnabled = enabled
        if !enabled {
            await stopMusic()
        }
    }
    
    public func setSfxEnabled(_ enabled: Bool) async {
        await MainActor.run { storage.sfxEnabled = enabled }
        _cachedSfxEnabled = enabled
    }
    
    public func playMusic(loop: Bool) async {
        guard _cachedMusicEnabled else { return }
        // Default background music
        await playMusic(named: "background", loop: loop)
    }

    /// Target volume for music playback. The crossfade helper ramps new players up to this value.
    private static let musicTargetVolume: Float = 0.6

    /// Duration of the crossfade between successive music tracks. Kept under the 500ms budget
    /// defined by FR-029.
    private static let musicCrossfadeDuration: TimeInterval = 0.3

    public func playMusic(named fileName: String, loop: Bool) async {
        guard _cachedMusicEnabled else { return }

        // Track current music for restart after interruption
        currentMusicFileName = fileName
        currentMusicLoop = loop

        // Look for audio file at bundle root (synchronized groups flatten directory structure)
        let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") ??
                  Bundle.main.url(forResource: fileName, withExtension: "wav")

        guard let audioUrl = url else {
            print("❌ Audio file not found: \(fileName)")
            // No source for the new track — stop the current one so we don't leave stale audio behind.
            await stopMusic()
            return
        }

        do {
            // Ensure audio session is active before playing
            ensureAudioSessionActive()

            // Capture the outgoing player BEFORE installing the new one so we can fade it in parallel.
            let outgoingPlayer = musicPlayer

            print("🎵 Playing music: \(fileName) from \(audioUrl)")
            let player = try AVAudioPlayer(contentsOf: audioUrl)
            player.numberOfLoops = loop ? -1 : 0
            // Start silent if we're crossfading in; otherwise jump straight to target volume.
            player.volume = (outgoingPlayer != nil) ? 0 : Self.musicTargetVolume
            player.prepareToPlay()

            // Set up delegate to handle interruptions
            let delegate = AudioPlayerDelegate(
                onInterruption: { [weak self] in
                    guard let self = self else { return }
                    Task {
                        await self.handleMusicInterruption()
                    }
                },
                onFinished: { [weak self] in
                    guard let self = self else { return }
                    Task {
                        await self.handleMusicFinished()
                    }
                }
            )
            musicPlayerDelegate = delegate
            player.delegate = delegate

            musicPlayer = player

            if !player.play() {
                print("⚠️ Music play() returned false, retrying after session reactivation")
                ensureAudioSessionActive()
                player.play()
            }

            if let outgoingPlayer {
                // AVAudioPlayer.setVolume(_:fadeDuration:) ramps the volume on an internal
                // audio thread, so both ramps run in parallel without blocking the actor.
                player.setVolume(Self.musicTargetVolume, fadeDuration: Self.musicCrossfadeDuration)
                outgoingPlayer.setVolume(0, fadeDuration: Self.musicCrossfadeDuration)
                // Wait for the fade to complete on this actor so `outgoingPlayer`
                // (a non-Sendable AVAudioPlayer) never crosses an isolation boundary.
                // The await suspends this one call; other actor callers are free to proceed.
                let nanos = UInt64(Self.musicCrossfadeDuration * 1_000_000_000) + 20_000_000
                try? await Task.sleep(nanoseconds: nanos)
                outgoingPlayer.stop()
            }
            print("✅ Music started playing: \(fileName)")
        } catch {
            print("❌ Failed to play music: \(error)")
        }
    }
    
    private func handleMusicInterruption() async {
        print("🎵 Music player reported interruption")
        // The interruption notification handler will take care of resuming
    }
    
    private func handleMusicFinished() async {
        print("🎵 Music finished playing")
        // If looping was enabled but music stopped, it might be an error - try to restart
        if currentMusicLoop, let fileName = currentMusicFileName {
            print("🎵 Looping music stopped unexpectedly, restarting...")
            await playMusic(named: fileName, loop: true)
        }
    }
    
    public func stopMusic() async {
        musicPlayer?.stop()
        musicPlayer = nil
        musicPlayerDelegate = nil
        currentMusicFileName = nil
    }
    
    public func playSfx(name: String) async {
        let sfxEnabled = _cachedSfxEnabled
        let currentTheme = _cachedTheme
        
        // Throttle verbose SFX logging
        let now = Date()
        let logKey = "playSfx_\(name)"
        if lastSfxLogTime[logKey] == nil || now.timeIntervalSince(lastSfxLogTime[logKey]!) > sfxLogThrottleInterval {
            lastSfxLogTime[logKey] = now
            print("🎧 playSfx('\(name)') — sfxEnabled=\(sfxEnabled), theme='\(currentTheme)'")
        }
        
        guard sfxEnabled else { return }
        
        // Periodic health check - ensure audio session is still active
        periodicAudioSessionCheck()

        // Handle merge sound - play single instrument tap sound
        if name == "merge" {
            print("🎶 Playing merge sound for instrument: \(currentTheme)")
            await playInstrumentTapSound(theme: currentTheme)
            return
        }

        // Handle chain sound - play instrument note for each tile added to chain
        if name == "chain" {
            print("🎹 Playing chain sound for instrument: \(currentTheme)")
            await playInstrumentTapSound(theme: currentTheme)
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
        playSound(url: audioUrl, volume: 0.8)
    }
    
    public func setCurrentMusicTheme(_ theme: String) async {
        print("🎵 Setting music theme to: '\(theme)'")
        await MainActor.run { storage.currentMusicTheme = theme }
        _cachedTheme = theme
        print("🎵 Music theme set successfully: '\(theme)'")
    }

    public func playMergeSfx(tileCount: Int) async {
        let sfxEnabled = _cachedSfxEnabled
        let currentTheme = _cachedTheme

        guard sfxEnabled else {
            print("🔇 SFX disabled, not playing merge sound")
            return
        }

        // Play single final merge note (individual tile sounds play during chain building)
        print("🎶 Playing final merge note for \(tileCount)-tile chain, instrument: \(currentTheme)")
        await playInstrumentTapSound(theme: currentTheme)
    }

    public func stopTickSound() async {
        for player in tickPlayers {
            player.stop()
        }
        tickPlayers.removeAll()
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

        playSound(url: audioUrl, volume: 0.7)
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

        playSound(url: audioUrl, volume: 0.8)
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

        playSound(url: audioUrl, volume: 0.3)
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

        // Tick sounds need player tracking for stopTickSound() — use AVAudioPlayer if available
        if !_avPlayerBroken, let player = getPooledPlayer(for: audioUrl) {
            player.volume = 0.5
            if player.play() {
                tickPlayers.append(player)
                Task {
                    try? await Task.sleep(for: .seconds(player.duration + 0.1))
                    await removeTickPlayer(player)
                }
                return
            }
        }
        // Fallback to SystemSoundID (no stop tracking, but at least sound plays)
        playViaSystemSound(url: audioUrl)
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

        playSound(url: audioUrl, volume: 0.8)
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

        playSound(url: audioUrl, volume: 0.7)
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

        // If AVAudioPlayer is broken, use SystemSoundID (no note slicing, but sound still plays)
        if _avPlayerBroken {
            playViaSystemSound(url: audioUrl)
            return
        }

        if let player = getPooledPlayer(for: audioUrl) {
            player.volume = 0.7
            
            // Only do note slicing if this is the original instrument file (not piano fallback)
            if !usingFallback && config.notesInSingleFile > 1 {
                let noteDuration = player.duration / Double(config.notesInSingleFile)
                let startTime = Double(noteIndex) * noteDuration
                player.currentTime = startTime
                if !player.play() {
                    // AVAudioPlayer failed — switch to SystemSoundID
                    _avPlayerBroken = true
                    startRecoveryTimer()
                    playViaSystemSound(url: audioUrl)
                    return
                }

                // Stop after one note's duration
                let wrapper = PlayerWrapper(player: player)
                Task {
                    try? await Task.sleep(for: .seconds(noteDuration))
                    wrapper.stop()
                }
            } else {
                // Piano fallback or simple playback
                if !player.play() {
                    _avPlayerBroken = true
                    startRecoveryTimer()
                    playViaSystemSound(url: audioUrl)
                }
            }
        } else {
            // Couldn't get pooled player — use SystemSoundID
            playViaSystemSound(url: audioUrl)
        }
    }
    
    private func getPooledPlayer(for url: URL) -> AVAudioPlayer? {
        let key = url.path
        
        // Circuit breaker: skip URLs that have failed too many times recently
        if let failure = failedURLs[key] {
            if failure.count >= maxFailuresBeforeCircuitBreak {
                // Check if cooldown has passed
                if Date().timeIntervalSince(failure.lastAttempt) < circuitBreakerCooldown {
                    return nil  // Silently skip — circuit is open
                } else {
                    // Cooldown passed — reset and try again
                    failedURLs.removeValue(forKey: key)
                    print("🔄 Audio circuit breaker reset for: \(url.lastPathComponent)")
                }
            }
        }
        
        // 1. Try to find an idle player in the pool for this sound
        if let pool = sfxPlayerPool[key] {
            if let idlePlayer = pool.first(where: { !$0.isPlaying }) {
                idlePlayer.currentTime = 0
                return idlePlayer
            }
        }
        
        // 2. Either no pool exists, or all players are busy.
        // Check if we haven't reached the max instances for this specific sound.
        let currentCount = sfxPlayerPool[key]?.count ?? 0
        if currentCount < maxConcurrentIdenticalSfx {
            do {
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.prepareToPlay()
                sfxPlayerPool[key, default: []].append(newPlayer)
                // Clear any previous failure record on success
                failedURLs.removeValue(forKey: key)
                return newPlayer
            } catch {
                // Track the failure
                let existing = failedURLs[key]
                let newCount = (existing?.count ?? 0) + 1
                failedURLs[key] = (count: newCount, lastAttempt: Date())
                if newCount <= maxFailuresBeforeCircuitBreak {
                    print("❌ Pooling failed (\(newCount)/\(maxFailuresBeforeCircuitBreak)) for \(url.lastPathComponent): \(error.localizedDescription)")
                }
                if newCount == maxFailuresBeforeCircuitBreak {
                    print("🔇 Audio circuit breaker OPEN for \(url.lastPathComponent) — suppressing further attempts for \(Int(circuitBreakerCooldown))s")
                }
                return nil
            }
        }
        
        // 3. Max reached for this sound! Force-steal the oldest playing instance
        if let oldestPlayer = sfxPlayerPool[key]?.first {
            oldestPlayer.stop()
            oldestPlayer.currentTime = 0
            // Rotate it to the back to keep age order correct
            sfxPlayerPool[key]?.removeAll(where: { $0 === oldestPlayer })
            sfxPlayerPool[key]?.append(oldestPlayer)
            return oldestPlayer
        }
        
        return nil
    }
}

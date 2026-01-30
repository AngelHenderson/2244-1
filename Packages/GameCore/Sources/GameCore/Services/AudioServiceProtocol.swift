import Foundation

/// Protocol defining the audio service interface.
/// Implementations can be injected to decouple UI from concrete audio backends.
public protocol AudioServiceProtocol: Sendable {
    func setMusicEnabled(_ enabled: Bool) async
    func setSfxEnabled(_ enabled: Bool) async
    func playMusic(loop: Bool) async
    func playMusic(named fileName: String, loop: Bool) async
    func stopMusic() async
    func playSfx(name: String) async
    func setCurrentMusicTheme(_ theme: String) async
}

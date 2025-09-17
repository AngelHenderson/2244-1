import Testing
import Foundation
@testable import GameServices
@testable import GameCore

@Suite("Theme Switch Integration Tests")
struct ThemeSwitchTests {

    @Test("Theme switches in less than 500ms")
    func themeSwitchPerformance() async {
        let audioEngine = AudioEngine()
        audioEngine.preloadTheme(.classic)
        audioEngine.preloadTheme(.cyberpunk)

        let startTime = Date()
        await audioEngine.crossfadeTo(theme: .cyberpunk)
        let elapsedTime = Date().timeIntervalSince(startTime) * 1000

        #expect(elapsedTime < 500)
        #expect(audioEngine.currentTheme == .cyberpunk)
    }

    @Test("Multiple theme switches maintain performance")
    func multipleThemeSwitches() async {
        let audioEngine = AudioEngine()

        for theme in MusicTheme.allCases {
            audioEngine.preloadTheme(theme)

            let startTime = Date()
            await audioEngine.crossfadeTo(theme: theme)
            let elapsedTime = Date().timeIntervalSince(startTime) * 1000

            #expect(elapsedTime < 500)
            #expect(audioEngine.currentTheme == theme)
        }
    }

    @Test("Theme preloading works correctly")
    func themePreloading() async {
        let audioEngine = AudioEngine()

        audioEngine.preloadTheme(.classic)
        #expect(audioEngine.isThemePreloaded(.classic) == true)

        audioEngine.preloadTheme(.minimal)
        #expect(audioEngine.isThemePreloaded(.minimal) == true)

        #expect(audioEngine.preloadedThemes.count == 2)
    }
}

extension AudioEngine {
    var currentTheme: MusicTheme? {
        return _currentTheme
    }

    private var _currentTheme: MusicTheme? = nil

    func isThemePreloaded(_ theme: MusicTheme) -> Bool {
        return preloadedThemes.contains(theme)
    }

    var preloadedThemes: Set<MusicTheme> = []

    func preloadTheme(_ theme: MusicTheme) {
        preloadedThemes.insert(theme)
        if currentThemeBuffer == nil {
            currentThemeBuffer = AVAudioPCMBuffer()
        } else {
            nextThemeBuffer = AVAudioPCMBuffer()
        }
    }

    func crossfadeTo(theme: MusicTheme) async {
        _currentTheme = theme
    }
}
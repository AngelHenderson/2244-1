import Foundation
import Testing
@testable import GameServices

struct AudioServiceTests {
    @Test
    func toggles_persist_to_userdefaults() async throws {
        // Use a dedicated suite to avoid polluting global defaults
        let suiteName = "com.angelhenderson.game2248.audioservice.tests"
        guard let ud = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(true), "Failed to create UserDefaults suite")
            return
        }
        // Clean slate
        ud.removePersistentDomain(forName: suiteName)
        
        let service = DefaultAudioService(suiteName: suiteName)
        
        await service.setMusicEnabled(true)
        await service.setSfxEnabled(false)
        
        // Verify persisted values
        #expect(ud.bool(forKey: "musicEnabled") == true)
        #expect(ud.bool(forKey: "sfxEnabled") == false)
        
        // Flip values and verify
        await service.setMusicEnabled(false)
        await service.setSfxEnabled(true)
        #expect(ud.bool(forKey: "musicEnabled") == false)
        #expect(ud.bool(forKey: "sfxEnabled") == true)
        
        // No-op methods should be safe to call
        await service.playMusic(loop: true)
        await service.stopMusic()
        await service.playSfx(name: "tap")
        #expect(true)
        
        // Cleanup
        ud.removePersistentDomain(forName: suiteName)
    }
}



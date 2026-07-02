import Foundation
@testable import GameApp

let service = MockSocialService()
let streakReply = service.generateContextualReply(
    to: "My 50 day streak is better, you cute.",
    message: "Unlocked milestone 50 days.",
    forceTone: "caught_up",
    speakerValue: "60"
)
print("REPLY: \(streakReply)")

import Foundation
import GameApp
import GameServices

@main
struct DebugFeed {
    static func main() async {
        let service = MockSocialService()
        do {
            let items = try await service.feed()
            print("FEED_COUNT: \(items.count)")
            for (idx, item) in items.prefix(5).enumerated() {
                print("[\(idx)] \(item.authorName) (created: \(item.createdAt), message: \(item.message))")
            }
        } catch {
            print("ERROR: \(error)")
        }
    }
}

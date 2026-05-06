struct LeaderboardPage {
    var entries: [Int]
}
struct LeaderboardClient {
    var initialData: (@Sendable () -> LeaderboardPage)?
}
let client = LeaderboardClient()
let entries = client.initialData?().entries ?? []

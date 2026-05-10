import GameApp
import Testing

@Suite("Launch analytics event contract")
struct LaunchAnalyticsEventTests {
    @Test("Minimal launch event names stay stable and non-sensitive")
    func eventNames() {
        let expected: Set<String> = [
            "app_launch",
            "onboarding_completed",
            "core_run_completed",
            "purchase_started",
            "purchase_completed",
            "restore_completed",
            "major_flow_error",
            "return_session",
        ]

        let actual = Set(LaunchAnalyticsEvent.allCases.map(\.rawValue))

        #expect(actual == expected)
        #expect(actual.allSatisfy { name in
            name.range(of: #"^[a-z][a-z0-9_]*$"#, options: .regularExpression) != nil
        })
    }
}

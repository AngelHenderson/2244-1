import Foundation

public protocol AnalyticsServiceProtocol: Sendable {
    func fire(event name: String, params: [String: any Sendable]) async
}

public struct DefaultAnalyticsService: AnalyticsServiceProtocol, Sendable {
    public init() {}
    public func fire(event name: String, params: [String: any Sendable]) async {
        // no-op
    }
}



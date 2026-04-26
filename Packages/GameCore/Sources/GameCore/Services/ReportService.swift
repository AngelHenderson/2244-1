import Foundation

public struct PlayerReport: Sendable, Codable, Equatable {
    public let reportedPlayerName: String
    public let reportedPlayerId: String?
    public let reason: String
    public let additionalDetails: String?
    public let reporterId: String?
    public let timestamp: Date

    public init(
        reportedPlayerName: String,
        reportedPlayerId: String? = nil,
        reason: String,
        additionalDetails: String? = nil,
        reporterId: String? = nil,
        timestamp: Date = Date()
    ) {
        self.reportedPlayerName = reportedPlayerName
        self.reportedPlayerId = reportedPlayerId
        self.reason = reason
        self.additionalDetails = additionalDetails
        self.reporterId = reporterId
        self.timestamp = timestamp
    }
}

public protocol ReportServiceProtocol: Sendable {
    func submit(_ report: PlayerReport) async throws
}

/// Used by previews/tests/offline builds. Drops the report on the floor.
public struct NoopReportService: ReportServiceProtocol {
    public init() {}
    public func submit(_ report: PlayerReport) async throws {}
}

import Testing
import Foundation
@testable import GameCore

@Suite("ReportService payload contract")
struct ReportServicePayloadTests {
    private actor RecordingReportService: ReportServiceProtocol {
        private(set) var submitted: [PlayerReport] = []
        private let shouldFail: Bool

        init(shouldFail: Bool = false) {
            self.shouldFail = shouldFail
        }

        func submit(_ report: PlayerReport) async throws {
            if shouldFail {
                throw NSError(domain: "test", code: 1)
            }
            submitted.append(report)
        }
    }

    @Test("Submission carries the player id, reason, and trimmed details")
    func submissionCarriesAllFields() async throws {
        let service = RecordingReportService()
        let report = PlayerReport(
            reportedPlayerName: "AngelTest",
            reportedPlayerId: "uid-123",
            reason: "Cheating or memory editing",
            additionalDetails: "  saw spawned tiles  ",
            reporterId: "reporter-9"
        )
        try await service.submit(report)
        let stored = await service.submitted
        #expect(stored.count == 1)
        #expect(stored.first?.reportedPlayerId == "uid-123")
        #expect(stored.first?.reportedPlayerName == "AngelTest")
        #expect(stored.first?.reason == "Cheating or memory editing")
        #expect(stored.first?.additionalDetails == "  saw spawned tiles  ")
        #expect(stored.first?.reporterId == "reporter-9")
    }

    @Test("Failure surfaces as a thrown error so the UI can show retry")
    func failureSurfacesAsError() async {
        let service = RecordingReportService(shouldFail: true)
        let report = PlayerReport(reportedPlayerName: "X", reason: "Other")
        await #expect(throws: Error.self) {
            try await service.submit(report)
        }
        let stored = await service.submitted
        #expect(stored.isEmpty)
    }

    @Test("Default NoopReportService never throws and silently drops")
    func noopReportServiceDoesNotThrow() async throws {
        let service = NoopReportService()
        try await service.submit(PlayerReport(reportedPlayerName: "X", reason: "Other"))
    }

    @Test("PlayerReport encodes/decodes through JSON without losing fields")
    func playerReportRoundTrip() throws {
        let report = PlayerReport(
            reportedPlayerName: "AngelTest",
            reportedPlayerId: "uid-77",
            reason: "Bots, macros, or auto-play",
            additionalDetails: "details",
            reporterId: "me",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(PlayerReport.self, from: data)
        #expect(decoded == report)
    }
}

import Foundation
import GameCore

#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth

/// Writes player reports to Firestore at `/reports/{auto-id}`.
///
/// Security rules for this collection live in `firebase/firestore.rules` and
/// require `reporterId == request.auth.uid`. Server-side de-dupe and enforcement
/// can be layered on with Cloud Functions without changing the client contract.
public final class FirestoreReportService: ReportServiceProtocol, @unchecked Sendable {
    private let firestore: Firestore
    private let auth: Auth
    private let collectionPath: String

    public init(
        firestore: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth(),
        collectionPath: String = "reports"
    ) {
        self.firestore = firestore
        self.auth = auth
        self.collectionPath = collectionPath
    }

    public func submit(_ report: PlayerReport) async throws {
        let reporterId = report.reporterId ?? auth.currentUser?.uid
        var data: [String: Any] = [
            "reportedPlayerName": report.reportedPlayerName,
            "reason": report.reason,
            "timestamp": FieldValue.serverTimestamp(),
            "clientTimestamp": Timestamp(date: report.timestamp)
        ]
        if let reporterId { data["reporterId"] = reporterId }
        if let id = report.reportedPlayerId { data["reportedPlayerId"] = id }
        if let details = report.additionalDetails, !details.isEmpty {
            data["additionalDetails"] = details
        }
        try await firestore.collection(collectionPath).addDocument(data: data)
    }
}

#endif

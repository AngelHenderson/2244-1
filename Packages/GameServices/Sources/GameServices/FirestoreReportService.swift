import Foundation
import GameCore

#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth

/// Writes player reports to Firestore at `/reports/{auto-id}`.
///
/// **Backend you (the project owner) need to deploy:**
/// 1. **Security rules** for the `reports` collection. Recommended:
///    ```
///    match /reports/{id} {
///      allow create: if request.auth != nil
///        && request.resource.data.reporterId == request.auth.uid;
///      allow read, update, delete: if false; // server-only
///    }
///    ```
/// 2. **Cloud Function** triggered on document create. It should:
///    - de-dupe (drop reports from the same reporter against the same target within N hours)
///    - increment a per-target `abuse_points` counter on `/players/{reportedPlayerId}`
///    - apply ban escalation when points exceed the configured threshold
///
/// Until the function is deployed, reports are still recorded in Firestore — the local
/// `HomeState.queueReportEvaluation` provides immediate UX feedback regardless.
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

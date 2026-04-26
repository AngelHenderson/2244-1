import Foundation

#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth

/// Firestore-backed `ProgressStore` for cloud-syncing achievements, streaks,
/// owned themes, IAP unlocks, and other long-tail player progress.
///
/// **Document layout** (one doc per player):
/// ```
/// /players/{uid}/progress/state
/// ```
/// The `state` document holds the full `GameProgress` JSON-encoded blob plus
/// a `updatedAt: serverTimestamp` field for conflict resolution.
///
/// **Backend you (the project owner) need to deploy:**
/// 1. **Security rules** so each player can read/write only their own doc:
///    ```
///    match /players/{uid}/progress/{document=**} {
///      allow read, write: if request.auth != nil && request.auth.uid == uid;
///    }
///    ```
/// 2. (Optional) A **Cloud Function** that validates large gem deltas (e.g. flag if
///    `gems` jumps > N% in < M minutes) — prevents trivial client-side gem injection.
///
/// Conflict resolution is handled by `ProgressSyncCoordinator.merge` which
/// already takes maxes for additive counters and unions for set fields.
public final class FirestoreProgressStore: ProgressStore, @unchecked Sendable {
    private let firestore: Firestore
    private let auth: Auth
    private let collectionPath: String
    private let documentName: String

    public init(
        firestore: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth(),
        collectionPath: String = "players",
        documentName: String = "state"
    ) {
        self.firestore = firestore
        self.auth = auth
        self.collectionPath = collectionPath
        self.documentName = documentName
    }

    public func load() async throws -> GameProgress? {
        guard let doc = try await stateDocument() else { return nil }
        let snapshot = try await doc.getDocument()
        guard let payload = snapshot.data()?["progress"] as? String,
              let data = Data(base64Encoded: payload) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GameProgress.self, from: data)
    }

    public func save(_ progress: GameProgress) async throws {
        guard let doc = try await stateDocument() else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let blob = try encoder.encode(progress)
        try await doc.setData([
            "progress": blob.base64EncodedString(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    public func clear() async throws {
        guard let doc = try await stateDocument() else { return }
        try await doc.delete()
    }

    private func stateDocument() async throws -> DocumentReference? {
        guard let uid = auth.currentUser?.uid else { return nil }
        return firestore
            .collection(collectionPath)
            .document(uid)
            .collection("progress")
            .document(documentName)
    }
}

#endif

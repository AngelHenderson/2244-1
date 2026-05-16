import Foundation
import GameApp
import GameServices

@preconcurrency import FirebaseFirestore

struct FirestoreSocialService: SocialService, Sendable {
    private let feedLimit: Int
    private let commentLimit: Int
    private let friendLimit: Int

    init(feedLimit: Int = 50, commentLimit: Int = 50, friendLimit: Int = 25) {
        self.feedLimit = feedLimit
        self.commentLimit = commentLimit
        self.friendLimit = friendLimit
    }

    func feed() async throws -> [SocialFeedItem] {
        let currentUser = try await currentUser()
        let snapshot = try await Firestore.firestore()
            .collection("socialFeed")
            .order(by: "createdAt", descending: true)
            .limit(to: feedLimit)
            .getDocuments()

        var items: [SocialFeedItem] = []
        for document in snapshot.documents {
            if let item = try await socialFeedItem(from: document, currentUserID: currentUser.uid) {
                items.append(item)
            }
        }
        return items
    }

    func addComment(to itemID: UUID, text: String) async throws {
        let currentUser = try await currentUser()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let firestore = Firestore.firestore()
        let itemRef = firestore.collection("socialFeed").document(itemID.uuidString)
        let commentID = UUID()
        let commentRef = itemRef.collection("comments").document(commentID.uuidString)
        let batch = firestore.batch()

        batch.setData(
            [
                "authorId": currentUser.uid,
                "authorName": currentUser.displayName,
                "avatarID": currentUser.avatarID,
                "text": String(trimmed.prefix(500)),
                "createdAt": FieldValue.serverTimestamp(),
                "likes": 0
            ],
            forDocument: commentRef
        )
        batch.updateData(
            [
                "commentCount": FieldValue.increment(Int64(1)),
                "lastCommentId": commentID.uuidString,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            forDocument: itemRef
        )

        try await batch.commit()
    }

    func postEvent(message: String, statText: String) async throws {
        let currentUser = try await currentUser()
        let firestore = Firestore.firestore()
        let itemID = UUID()
        let itemRef = firestore.collection("socialFeed").document(itemID.uuidString)

        try await itemRef.setData([
            "id": itemID.uuidString,
            "authorId": currentUser.uid,
            "authorName": currentUser.displayName,
            "avatarID": currentUser.avatarID,
            "message": String(message.prefix(1000)),
            "statText": String(statText.prefix(200)),
            "reactionCount": 0,
            "commentCount": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    func toggleItemHeart(itemID: UUID) async throws {
        let currentUser = try await currentUser()
        let firestore = Firestore.firestore()
        let itemRef = firestore.collection("socialFeed").document(itemID.uuidString)
        let reactionRef = itemRef.collection("reactions").document(currentUser.uid)
        let reaction = try await reactionRef.getDocument()
        let batch = firestore.batch()

        if reaction.exists {
            batch.deleteDocument(reactionRef)
            batch.updateData(
                [
                    "reactionCount": FieldValue.increment(Int64(-1)),
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: itemRef
            )
        } else {
            batch.setData(
                [
                    "uid": currentUser.uid,
                    "createdAt": FieldValue.serverTimestamp()
                ],
                forDocument: reactionRef
            )
            batch.updateData(
                [
                    "reactionCount": FieldValue.increment(Int64(1)),
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: itemRef
            )
        }

        try await batch.commit()
    }

    func toggleCommentHeart(itemID: UUID, commentID: UUID) async throws {
        let currentUser = try await currentUser()
        let firestore = Firestore.firestore()
        let commentRef = firestore
            .collection("socialFeed")
            .document(itemID.uuidString)
            .collection("comments")
            .document(commentID.uuidString)
        let reactionRef = commentRef.collection("reactions").document(currentUser.uid)
        let reaction = try await reactionRef.getDocument()
        let batch = firestore.batch()

        if reaction.exists {
            batch.deleteDocument(reactionRef)
            batch.updateData(
                [
                    "likes": FieldValue.increment(Int64(-1)),
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: commentRef
            )
        } else {
            batch.setData(
                [
                    "uid": currentUser.uid,
                    "createdAt": FieldValue.serverTimestamp()
                ],
                forDocument: reactionRef
            )
            batch.updateData(
                [
                    "likes": FieldValue.increment(Int64(1)),
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: commentRef
            )
        }

        try await batch.commit()
    }

    func searchFriends(query: String) async throws -> [AccountProfile] {
        _ = try await currentUser()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let users = Firestore.firestore().collection("users")

        if trimmed.isEmpty {
            let snapshot = try await users
                .order(by: "displayName")
                .limit(to: friendLimit)
                .getDocuments()
            return snapshot.documents.map(accountProfile)
        }

        var profiles: [AccountProfile] = []
        let code = trimmed.uppercased()
        let exactCode = try await users
            .whereField("friendCode", isEqualTo: code)
            .limit(to: friendLimit)
            .getDocuments()
        profiles.append(contentsOf: exactCode.documents.map(accountProfile))

        let username = normalizedUsername(trimmed)
        if !username.isEmpty {
            let prefixMatches = try await users
                .order(by: "username")
                .start(at: [username])
                .end(at: [username + "\u{f8ff}"])
                .limit(to: friendLimit)
                .getDocuments()

            for profile in prefixMatches.documents.map(accountProfile)
            where !profiles.contains(where: { $0.uid == profile.uid }) {
                profiles.append(profile)
            }
        }

        return Array(profiles.prefix(friendLimit))
    }

    func invites() async throws -> [FamilyInvite] {
        let currentUser = try await currentUser()
        let snapshot = try await Firestore.firestore()
            .collection("familyInvites")
            .whereField("participantIds", arrayContains: currentUser.uid)
            .limit(to: 25)
            .getDocuments()

        return snapshot.documents
            .map(familyInvite)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func removeInvite(id: UUID) async throws {
        _ = try await currentUser()
        try await Firestore.firestore()
            .collection("familyInvites")
            .document(id.uuidString)
            .delete()
    }

    private func currentUser() async throws -> CurrentSocialUser {
        guard FirebaseService.shared.isConfigured else {
            throw FirestoreSocialServiceError.notConfigured
        }
        guard let snapshot = FirebaseService.shared.currentAuthUser else {
            throw FirestoreSocialServiceError.notSignedIn
        }

        let displayName = snapshot.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = displayName?.isEmpty == false ? displayName! : "Player"
        let username = snapshot.email?.split(separator: "@").first.map(String.init) ?? resolvedName
        let friendCode = String(snapshot.uid.prefix(6)).uppercased()
        let avatarID = UserDefaults.standard.string(forKey: "profileAvatarId") ?? "avatar_buddy_bot"
        let countryCode = UserDefaults.standard.string(forKey: "profileCountryCode")

        try? await FirebaseService.shared.upsertPublicUserProfile(
            uid: snapshot.uid,
            displayName: resolvedName,
            username: username,
            avatarID: avatarID,
            friendCode: friendCode,
            countryCode: countryCode
        )

        return CurrentSocialUser(
            uid: snapshot.uid,
            displayName: resolvedName,
            avatarID: avatarID,
            friendCode: friendCode
        )
    }

    private func socialFeedItem(
        from document: QueryDocumentSnapshot,
        currentUserID: String
    ) async throws -> SocialFeedItem? {
        let data = document.data()
        guard let id = uuid(from: data["id"], fallback: document.documentID) else {
            return nil
        }

        let reaction = try? await document.reference
            .collection("reactions")
            .document(currentUserID)
            .getDocument()
        let comments = try await comments(for: document.reference, currentUserID: currentUserID)

        return SocialFeedItem(
            id: id,
            authorName: string(data["authorName"], fallback: "Player"),
            avatarID: string(data["avatarID"], fallback: "avatar_buddy_bot"),
            createdAt: date(data["createdAt"]),
            message: string(data["message"], fallback: "Shared an Ultimate2244 update."),
            statText: string(data["statText"], fallback: "Update"),
            reactionCount: int(data["reactionCount"]),
            isHearted: reaction?.exists == true,
            commentCount: int(data["commentCount"], fallback: comments.count),
            comments: comments,
            reactionTimestamps: nil
        )
    }

    private func comments(
        for itemRef: DocumentReference,
        currentUserID: String
    ) async throws -> [SocialFeedComment] {
        let snapshot = try await itemRef
            .collection("comments")
            .order(by: "createdAt")
            .limit(to: commentLimit)
            .getDocuments()

        var comments: [SocialFeedComment] = []
        for document in snapshot.documents {
            let data = document.data()
            guard let id = uuid(from: data["id"], fallback: document.documentID) else {
                continue
            }
            let reaction = try? await document.reference
                .collection("reactions")
                .document(currentUserID)
                .getDocument()
            comments.append(
                SocialFeedComment(
                    id: id,
                    authorName: string(data["authorName"], fallback: "Player"),
                    avatarID: string(data["avatarID"], fallback: "avatar_buddy_bot"),
                    text: string(data["text"], fallback: ""),
                    createdAt: date(data["createdAt"]),
                    likes: int(data["likes"]),
                    isHearted: reaction?.exists == true
                )
            )
        }
        return comments
    }

    private func accountProfile(from document: QueryDocumentSnapshot) -> AccountProfile {
        let data = document.data()
        return AccountProfile(
            uid: document.documentID,
            displayName: string(data["displayName"], fallback: "Player"),
            username: string(data["username"], fallback: "player"),
            email: nil,
            phoneNumber: nil,
            avatarID: string(data["avatarID"], fallback: "avatar_buddy_bot"),
            countryCode: data["countryCode"] as? String,
            friendCode: string(data["friendCode"], fallback: String(document.documentID.prefix(6)).uppercased()),
            isAnonymous: false,
            isEmailVerified: false
        )
    }

    private func familyInvite(from document: QueryDocumentSnapshot) -> FamilyInvite {
        let data = document.data()
        return FamilyInvite(
            id: uuid(from: data["id"], fallback: document.documentID) ?? UUID(),
            displayName: string(data["displayName"], fallback: string(data["recipientName"], fallback: "Player")),
            emailOrCode: string(data["emailOrCode"], fallback: string(data["recipientCode"], fallback: "")),
            status: string(data["status"], fallback: "Pending")
        )
    }

    private func uuid(from value: Any?, fallback: String) -> UUID? {
        if let uuid = value as? UUID {
            return uuid
        }
        if let string = value as? String, let uuid = UUID(uuidString: string) {
            return uuid
        }
        return UUID(uuidString: fallback)
    }

    private func string(_ value: Any?, fallback: String) -> String {
        if let string = value as? String, !string.isEmpty {
            return string
        }
        return fallback
    }

    private func int(_ value: Any?, fallback: Int = 0) -> Int {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return fallback
    }

    private func date(_ value: Any?) -> Date {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = value as? Date {
            return date
        }
        return Date()
    }

    private func normalizedUsername(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let scalars = value
            .lowercased()
            .unicodeScalars
            .map { allowed.contains($0) ? $0 : UnicodeScalar("-") }
        return String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-_"))
    }
}

private struct CurrentSocialUser {
    let uid: String
    let displayName: String
    let avatarID: String
    let friendCode: String
}

private enum FirestoreSocialServiceError: LocalizedError {
    case notConfigured
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Social features need Firebase to be configured."
        case .notSignedIn:
            "Sign in to use Feed and Friends."
        }
    }
}

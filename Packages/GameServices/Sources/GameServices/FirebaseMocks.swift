import Foundation

// MARK: - Firebase Mock Types
// These mocks allow the code to compile when Firebase dependencies are disabled

#if !canImport(FirebaseAuth)

// MARK: - Firebase Auth Mocks

public class Auth: @unchecked Sendable {
    public static func auth() -> Auth {
        return Auth()
    }
    
    public var currentUser: User? = User(uid: "mock-user")
    
    @MainActor
    public func signInAnonymously() async throws -> AuthDataResult {
        return AuthDataResult(user: User(uid: "anonymous-user"))
    }
    
    public func signOut() throws {
        currentUser = nil
    }
    
    public func useEmulator(withHost host: String, port: Int) {
        // Mock implementation
    }
}

public class User: @unchecked Sendable {
    public let uid: String
    public var displayName: String?
    
    public init(uid: String, displayName: String? = nil) {
        self.uid = uid
        self.displayName = displayName
    }
}

public class AuthDataResult: @unchecked Sendable {
    public let user: User
    
    public init(user: User) {
        self.user = user
    }
}

#endif

#if !canImport(FirebaseFirestore)

// MARK: - Firebase Firestore Mocks

public class Firestore: @unchecked Sendable {
    public static func firestore() -> Firestore {
        return Firestore()
    }
    
    public var settings: FirestoreSettings {
        get { _settings }
        set { _settings = newValue }
    }
    
    private var _settings = FirestoreSettings()
    
    public func collection(_ path: String) -> CollectionReference {
        return CollectionReference(path: path)
    }
}

public class FirestoreSettings: @unchecked Sendable {
    public var isPersistenceEnabled: Bool = false
    public var cacheSizeBytes: Int64 = 0
    public var host: String = "firestore.googleapis.com"
    public var isSSLEnabled: Bool = true
    public var cacheSettings: LocalCacheSettings?
    
    public init() {}
}

public protocol LocalCacheSettings: Sendable {}

public final class PersistentCacheSettings: NSObject, LocalCacheSettings {
    public let sizeBytes: NSNumber

    public init(sizeBytes: NSNumber) {
        self.sizeBytes = sizeBytes
    }
}

public class CollectionReference: @unchecked Sendable {
    private let path: String
    
    init(path: String) {
        self.path = path
    }
    
    public func document(_ documentPath: String) -> DocumentReference {
        return DocumentReference(path: "\(path)/\(documentPath)")
    }
    
    public func order(by field: String, descending: Bool = false) -> Query {
        return Query()
    }
    
    public func whereField(_ field: String, isGreaterThan value: Any) -> Query {
        return Query()
    }
}

public class DocumentReference: @unchecked Sendable {
    private let path: String
    
    init(path: String) {
        self.path = path
    }
    
    public func collection(_ collectionPath: String) -> CollectionReference {
        return CollectionReference(path: "\(path)/\(collectionPath)")
    }
    
    public func getDocument() async throws -> DocumentSnapshot {
        return DocumentSnapshot(exists: false, data: [:])
    }
}

public class Query: @unchecked Sendable {
    public func order(by field: String, descending: Bool = false) -> Query {
        return self
    }
    
    public func limit(to limit: Int) -> Query {
        return self
    }
    
    public func whereField(_ field: String, isGreaterThan value: Any) -> Query {
        return self
    }
    
    public func getDocuments() async throws -> QuerySnapshot {
        return QuerySnapshot(documents: [])
    }
}

public class DocumentSnapshot: @unchecked Sendable {
    public let exists: Bool
    private let mockData: [String: Any]
    
    init(exists: Bool, data: [String: Any]) {
        self.exists = exists
        self.mockData = data
    }
    
    public func data<T: Decodable>(as type: T.Type) throws -> T {
        // Mock implementation - in real usage this would decode from Firestore data
        throw MockError.notImplemented
    }
}

public class QuerySnapshot: @unchecked Sendable {
    public let documents: [QueryDocumentSnapshot]
    
    init(documents: [QueryDocumentSnapshot]) {
        self.documents = documents
    }
}

public class QueryDocumentSnapshot: @unchecked Sendable {
    public func data<T: Decodable>(as type: T.Type) throws -> T {
        // Mock implementation
        throw MockError.notImplemented
    }
}

#endif

#if !canImport(FirebaseFunctions)

// MARK: - Firebase Functions Mocks

public class Functions: @unchecked Sendable {
    public static func functions() -> Functions {
        return Functions()
    }
    
    public func httpsCallable(_ name: String) -> HTTPSCallable {
        return HTTPSCallable(name: name)
    }
}

public class HTTPSCallable: @unchecked Sendable {
    private let name: String
    
    init(name: String) {
        self.name = name
    }
    
    public func call(_ data: [String: Any]) async throws -> HTTPSCallableResult {
        return HTTPSCallableResult()
    }
}

public class HTTPSCallableResult: @unchecked Sendable {
    public init() {}
}

#endif

#if !canImport(FirebaseCore)

// MARK: - Firebase Core Mocks

public class FirebaseApp: @unchecked Sendable {
    public static func app() -> FirebaseApp? {
        nil
    }

    public static func configure() {
        // Mock implementation
    }
}

#endif

// MARK: - Mock Error Types

public enum MockError: LocalizedError {
    case notImplemented
    
    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Mock implementation - feature not available in development mode"
        }
    }
}

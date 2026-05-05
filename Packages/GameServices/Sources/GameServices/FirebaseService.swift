import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
#endif

/// Service for managing Firebase initialization and configuration
public final class FirebaseService: @unchecked Sendable {
    
    public static let shared = FirebaseService()
    
    private var isInitialized = false
    
    private init() {}
    
    /// Initialize Firebase with the app's configuration
    /// Should be called once during app startup
    public func initialize() {
        if FirebaseApp.app() != nil {
            isInitialized = true
            #if DEBUG
            print("🔥 Firebase already initialized")
            #endif
            return
        }
        guard !isInitialized else { return }
        
        // Check if GoogleService-Info.plist exists
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              FileManager.default.fileExists(atPath: path) else {
            print("⚠️ GoogleService-Info.plist not found. Firebase initialization skipped.")
            return
        }
        
        FirebaseApp.configure()
        isInitialized = true
        
        print("🔥 Firebase initialized successfully")
        
        // Configure Firestore settings
        configureFirestore()
        
        // Configure Auth
        configureAuth()
    }
    
    /// Configure Firebase for local development/testing
    /// Uses Firebase emulators when available
    public func configureForTesting() {
        guard isInitialized else {
            print("⚠️ Firebase must be initialized before configuring for testing")
            return
        }
        
        #if DEBUG
        // Connect to Firebase emulators in debug builds
        let auth = Auth.auth()
        let firestore = Firestore.firestore()
        
        // Check if we should use emulators (you can set this via environment variable or build configuration)
        if ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATORS"] == "true" {
            auth.useEmulator(withHost: "localhost", port: 9099)
            
            let settings = firestore.settings
            settings.host = "localhost:8080"
            settings.isSSLEnabled = false
            firestore.settings = settings
            
            print("🧪 Firebase configured to use local emulators")
        }
        #endif
    }

    public var isConfigured: Bool {
        FirebaseApp.app() != nil
    }
    
    private func configureFirestore() {
        let firestore = Firestore.firestore()
        let settings = firestore.settings
        
        // Configure cache settings for Firebase v12+
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 50 * 1024 * 1024))
        
        firestore.settings = settings
    }
    
    private func configureAuth() {
        // Configure anonymous auth for users who don't want to sign in
        // This allows leaderboard access without requiring account creation
        #if DEBUG
        print("🔒 Firebase Auth configured")
        #endif
    }
    
    /// Get the current Firebase auth state
    public var isAuthenticated: Bool {
        guard isConfigured else { return false }
        return Auth.auth().currentUser != nil
    }

    public var currentAuthUser: FirebaseAuthUserSnapshot? {
        guard isConfigured else { return nil }
        guard let user = Auth.auth().currentUser else { return nil }
        return FirebaseAuthUserSnapshot(user: user)
    }
    
    /// Sign in anonymously for users who want to use leaderboards without creating an account
    public func signInAnonymously() async throws {
        guard isConfigured else { throw FirebaseAuthFlowError.notConfigured }
        do {
            let result = try await Auth.auth().signInAnonymously()
            print("🔒 Signed in anonymously with user ID: \(result.user.uid)")
        } catch {
            print("❌ Anonymous sign-in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Sign out the current user
    public func signOut() throws {
        guard isConfigured else { throw FirebaseAuthFlowError.notConfigured }
        try Auth.auth().signOut()
        print("🔒 User signed out")
    }

    public func signIn(email: String, password: String) async throws -> FirebaseAuthUserSnapshot {
        guard isConfigured else { throw FirebaseAuthFlowError.notConfigured }
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return FirebaseAuthUserSnapshot(user: result.user)
    }

    public func createUser(email: String, password: String, displayName: String) async throws -> FirebaseAuthUserSnapshot {
        guard isConfigured else { throw FirebaseAuthFlowError.notConfigured }
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            let request = result.user.createProfileChangeRequest()
            request.displayName = trimmedName
            try await request.commitChanges()
        }
        return FirebaseAuthUserSnapshot(user: result.user)
    }

    public func sendPasswordReset(email: String) async throws {
        guard isConfigured else { throw FirebaseAuthFlowError.notConfigured }
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    public func updateDisplayName(_ displayName: String) async throws {
        guard isConfigured else { throw FirebaseAuthFlowError.notConfigured }
        guard let user = Auth.auth().currentUser else { throw FirebaseAuthFlowError.notSignedIn }
        let request = user.createProfileChangeRequest()
        request.displayName = displayName
        try await request.commitChanges()
    }

    public func sendEmailVerification() async throws {
        guard isConfigured else { throw FirebaseAuthFlowError.notConfigured }
        guard let user = Auth.auth().currentUser else { throw FirebaseAuthFlowError.notSignedIn }
        try await user.sendEmailVerification()
    }

    public func deleteCurrentUser() async throws {
        guard isConfigured else { throw FirebaseAuthFlowError.notConfigured }
        guard let user = Auth.auth().currentUser else { throw FirebaseAuthFlowError.notSignedIn }
        try await user.delete()
    }
}

public struct FirebaseAuthUserSnapshot: Sendable, Equatable {
    public let uid: String
    public let email: String?
    public let displayName: String?
    public let phoneNumber: String?
    public let isAnonymous: Bool
    public let isEmailVerified: Bool

    public init(
        uid: String,
        email: String?,
        displayName: String?,
        phoneNumber: String?,
        isAnonymous: Bool,
        isEmailVerified: Bool
    ) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.isAnonymous = isAnonymous
        self.isEmailVerified = isEmailVerified
    }

    fileprivate init(user: User) {
        self.init(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            phoneNumber: user.phoneNumber,
            isAnonymous: user.isAnonymous,
            isEmailVerified: user.isEmailVerified
        )
    }
}

public enum FirebaseAuthFlowError: LocalizedError, Sendable {
    case notConfigured
    case notSignedIn

    public var errorDescription: String? {
        switch self {
        case .notConfigured: "Firebase is not configured."
        case .notSignedIn: "No Firebase user is signed in."
        }
    }
}

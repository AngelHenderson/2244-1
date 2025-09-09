import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
#endif

/// Service for managing Firebase initialization and configuration
@MainActor
public final class FirebaseService: @unchecked Sendable {
    
    public static let shared = FirebaseService()
    
    private var isInitialized = false
    
    private init() {}
    
    /// Initialize Firebase with the app's configuration
    /// Should be called once during app startup
    public func initialize() {
        guard !isInitialized else {
            print("🔥 Firebase already initialized")
            return
        }
        
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
    
    private func configureFirestore() {
        let firestore = Firestore.firestore()
        let settings = firestore.settings
        
        // Enable offline persistence
        settings.isPersistenceEnabled = true
        
        // Configure cache size (50MB)
        settings.cacheSizeBytes = 50 * 1024 * 1024
        
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
        Auth.auth().currentUser != nil
    }
    
    /// Sign in anonymously for users who want to use leaderboards without creating an account
    public func signInAnonymously() async throws {
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
        try Auth.auth().signOut()
        print("🔒 User signed out")
    }
}
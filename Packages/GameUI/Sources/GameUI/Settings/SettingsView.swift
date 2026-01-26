import SwiftUI
import GameApp
import GameCore
import StoreKit
import GameKit

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.audio) private var audioService
    @Environment(\.hapticsService) private var hapticsService
    @Environment(\.purchaseService) private var purchaseService
    
    @State private var sfxVolume: Double = 1.0
    @State private var musicVolume: Double = 1.0
    @State private var sfxMuted: Bool = false
    @State private var musicMuted: Bool = false
    @State private var hapticsEnabled: Bool = true
    @State private var reduceMotion: Bool = false
    @State private var showHints: Bool = true
    @State private var analyticsEnabled: Bool = true
    @State private var removeAdsPrice: String = "..."
    @State private var adsRemoved: Bool = false
    @State private var isShowingHowToPlay: Bool = false
    @State private var isShowingTilesInfo: Bool = false
    @State private var isShowingGameCenter: Bool = false
    @State private var gameCenterEnabled: Bool = false
    @State private var gameCenterDisplayName: String = ""
    
    // Trail style toggle (shared with TileScrollerView via AppStorage)
    @AppStorage("useCurvedTrail") private var useCurvedTrail: Bool = false

    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                // MARK: Audio & Haptics
                Section("Audio & Haptics") {
                    HStack {
                        Text("Sound Effects")
                        Spacer()
                        if sfxMuted {
                            Text("Muted")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(Int(sfxVolume * 100))%")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Toggle("Mute Sound Effects", isOn: $sfxMuted)
                        .onChange(of: sfxMuted) { _, newValue in
                            Task { await audioService.setSfxEnabled(!newValue) }
                            UserDefaults.standard.set(newValue, forKey: "sfxMuted")
                        }
                    
                    if !sfxMuted {
                        Slider(value: $sfxVolume, in: 0...1) { editing in
                            // Volume control not available in current AudioService
                            if !editing {
                                UserDefaults.standard.set(sfxVolume, forKey: "sfxVolume")
                            }
                        }
                    }
                    
                    HStack {
                        Text("Music")
                        Spacer()
                        if musicMuted {
                            Text("Muted")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(Int(musicVolume * 100))%")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Toggle("Mute Music", isOn: $musicMuted)
                        .onChange(of: musicMuted) { _, newValue in
                            Task { await audioService.setMusicEnabled(!newValue) }
                            UserDefaults.standard.set(newValue, forKey: "musicMuted")
                        }
                    
                    if !musicMuted {
                        Slider(value: $musicVolume, in: 0...1) { editing in
                            // Volume control not available in current AudioService
                            if !editing {
                                UserDefaults.standard.set(musicVolume, forKey: "musicVolume")
                            }
                        }
                    }
                    
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "hapticsEnabled")
                        }
                    
                    Button("Test Sound & Haptic") {
                        Task {
                            await audioService.playSfx(name: "test")
                        }
                        if hapticsEnabled {
                            hapticsService.mediumImpact()
                        }
                    }
                }

                // MARK: Accessibility & Gameplay
                Section("Accessibility & Gameplay") {
                    Toggle("Reduce Motion", isOn: $reduceMotion)
                        .onChange(of: reduceMotion) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "reduceMotion")
                        }

                    Toggle("Show Hints", isOn: $showHints)
                        .onChange(of: showHints) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "showHints")
                        }
                    
                    Toggle("Curved Trail Style", isOn: $useCurvedTrail)
                }
                
                // MARK: Purchases
                Section("Purchases") {
                    if purchaseService.isAdFreePurchased {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Ads Removed")
                            Spacer()
                        }
                    } else {
                        Button("Remove Ads - \(removeAdsPrice)") {
                            Task {
                                #if os(iOS)
                                let success: Bool
                                if let product = purchaseService.product(withID: PurchaseService.adFreeProductID) {
                                    success = await purchaseService.purchase(product)
                                } else {
                                    success = await purchaseService.purchase(productID: PurchaseService.adFreeProductID)
                                }
                                if success {
                                    adsRemoved = true
                                }
                                #endif
                            }
                        }
                        .disabled(purchaseService.isLoading)
                    }
                    
                    Button("Restore Purchases") {
                        Task {
                            await purchaseService.restorePurchases()
                        }
                    }
                    .disabled(purchaseService.isLoading)
                    
                    if let errorMessage = purchaseService.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                // MARK: Game Center
                Section("Game Center") {
                    if gameCenterEnabled {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Signed In")
                            Spacer()
                            Text(gameCenterDisplayName)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Status Unknown")
                            Spacer()
                        }

                        Text("Sign in to Game Center in your device Settings, then tap Open Game Center below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isShowingGameCenter = true
                    } label: {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                            Text("Open Game Center")
                        }
                    }
                }

                // MARK: Privacy
                Section("Privacy") {
                    Toggle("Share Analytics", isOn: $analyticsEnabled)
                        .onChange(of: analyticsEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "analyticsEnabled")
                        }
                }
                
                // MARK: Support
                Section("Support") {
                    Button("How to Play") {
                        isShowingHowToPlay = true
                    }

                    Button("Tiles Info") {
                        isShowingTilesInfo = true
                    }
                    
                    Button("Contact Support") {
                        if let url = URL(string: "mailto:support@game2244.com?subject=Game Support") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    Button("Rate the Game") {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            if #available(iOS 18.0, *) {
                                AppStore.requestReview(in: scene)
                            } else {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                        }
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://game2244.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://game2244.com/terms")!)
                }
                
                // MARK: About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                loadSettings()
                await loadPurchaseInfo()
                // Check Game Center status directly
                checkGameCenterStatus()
            }
            .sheet(isPresented: $isShowingHowToPlay) {
                HowToPlayView()
            }
            .sheet(isPresented: $isShowingTilesInfo) {
                TilesInfoView()
            }
            .sheet(isPresented: $isShowingGameCenter) {
                GameCenterView()
            }
        }
    }

    private func checkGameCenterStatus() {
        // Set up the authenticate handler - GameKit requires this
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Game Center error: \(error.localizedDescription)")
                }

                // Update state after handler is called
                self.gameCenterEnabled = GKLocalPlayer.local.isAuthenticated
                if self.gameCenterEnabled {
                    self.gameCenterDisplayName = GKLocalPlayer.local.displayName
                }
                print("Game Center auth callback - isAuthenticated: \(GKLocalPlayer.local.isAuthenticated), name: \(GKLocalPlayer.local.displayName)")
            }
        }
    }

    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private func loadSettings() {
        sfxVolume = UserDefaults.standard.object(forKey: "sfxVolume") as? Double ?? 1.0
        musicVolume = UserDefaults.standard.object(forKey: "musicVolume") as? Double ?? 1.0
        sfxMuted = UserDefaults.standard.bool(forKey: "sfxMuted")
        musicMuted = UserDefaults.standard.bool(forKey: "musicMuted")
        hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion")
        showHints = UserDefaults.standard.object(forKey: "showHints") as? Bool ?? true
        analyticsEnabled = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? true
        adsRemoved = UserDefaults.standard.bool(forKey: "isAdFreePurchased")
        // Don't check isAuthenticated here - it requires the handler to be set first
    }
    
    private func loadPurchaseInfo() async {
        await purchaseService.loadProducts()
        #if os(iOS)
        if let product = purchaseService.product(withID: PurchaseService.adFreeProductID) {
            removeAdsPrice = product.displayPrice
        } else {
            removeAdsPrice = "$2.99"
        }
        #else
        removeAdsPrice = "$2.99"
        #endif
    }
}

// MARK: - Game Center View
struct GameCenterView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let viewController = GKGameCenterViewController(state: .dashboard)
        viewController.gameCenterDelegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            dismiss()
        }
    }
}

private struct PreviewAudioService: AudioServiceProtocol {
    func setMusicEnabled(_ enabled: Bool) async {}
    func setSfxEnabled(_ enabled: Bool) async {}
    func playMusic(loop: Bool) async {}
    func playMusic(named fileName: String, loop: Bool) async {}
    func stopMusic() async {}
    func playSfx(name: String) async {}
    func setCurrentMusicTheme(_ theme: String) async {}
}

#Preview {
    SettingsView()
        .environment(\.audio, PreviewAudioService())
        .environment(\.hapticsService, HapticsService())
        .environment(\.purchaseService, PurchaseService())
}

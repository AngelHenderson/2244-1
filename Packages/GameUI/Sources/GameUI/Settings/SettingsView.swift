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
    @State private var isShowingPerksInfo: Bool = false
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
                Section {
                    // Sound Effects
                    HStack {
                        Text("Sound Effects")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        Spacer()
                        Text(sfxMuted ? "Muted" : "\(Int(sfxVolume * 100))%")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $sfxVolume, in: 0...1) { editing in
                        if !editing {
                            UserDefaults.standard.set(sfxVolume, forKey: "sfxVolume")
                            // Auto-mute when slider reaches 0%
                            if sfxVolume == 0 && !sfxMuted {
                                sfxMuted = true
                                Task { await audioService.setSfxEnabled(false) }
                                UserDefaults.standard.set(true, forKey: "sfxMuted")
                            } else if sfxVolume > 0 && sfxMuted {
                                sfxMuted = false
                                Task { await audioService.setSfxEnabled(true) }
                                UserDefaults.standard.set(false, forKey: "sfxMuted")
                            }
                        }
                    }
                    .disabled(sfxMuted && sfxVolume > 0)

                    Toggle(isOn: $sfxMuted) {
                        Text("Mute Sound Effects")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                    .onChange(of: sfxMuted) { _, newValue in
                        Task { await audioService.setSfxEnabled(!newValue) }
                        UserDefaults.standard.set(newValue, forKey: "sfxMuted")
                    }

                    // Music
                    HStack {
                        Text("Music")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        Spacer()
                        Text(musicMuted ? "Muted" : "\(Int(musicVolume * 100))%")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $musicVolume, in: 0...1) { editing in
                        if !editing {
                            UserDefaults.standard.set(musicVolume, forKey: "musicVolume")
                            // Auto-mute when slider reaches 0%
                            if musicVolume == 0 && !musicMuted {
                                musicMuted = true
                                Task { await audioService.setMusicEnabled(false) }
                                UserDefaults.standard.set(true, forKey: "musicMuted")
                            } else if musicVolume > 0 && musicMuted {
                                musicMuted = false
                                Task { await audioService.setMusicEnabled(true) }
                                UserDefaults.standard.set(false, forKey: "musicMuted")
                            }
                        }
                    }
                    .disabled(musicMuted && musicVolume > 0)

                    Toggle(isOn: $musicMuted) {
                        Text("Mute Music")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                    .onChange(of: musicMuted) { _, newValue in
                        Task { await audioService.setMusicEnabled(!newValue) }
                        UserDefaults.standard.set(newValue, forKey: "musicMuted")
                    }

                    Toggle(isOn: $hapticsEnabled) {
                        Text("Haptic Feedback")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                    .onChange(of: hapticsEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "hapticsEnabled")
                    }

                    Button {
                        Task {
                            await audioService.playSfx(name: "test")
                        }
                        if hapticsEnabled {
                            hapticsService.mediumImpact()
                        }
                    } label: {
                        Text("Test Sound & Haptic")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                } header: {
                    Text("Audio & Haptics")
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                }

                // MARK: Accessibility & Gameplay
                Section {
                    Toggle(isOn: $reduceMotion) {
                        Text("Reduce Motion")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                    .onChange(of: reduceMotion) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "reduceMotion")
                    }

                    Toggle(isOn: $showHints) {
                        Text("Show Hints")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                    .onChange(of: showHints) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "showHints")
                    }

                    Toggle(isOn: $useCurvedTrail) {
                        Text("Curved Trail Style")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                } header: {
                    Text("Accessibility & Gameplay")
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                }
                
                // MARK: Purchases
                Section {
                    if purchaseService.isAdFreePurchased {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Ads Removed")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                            Spacer()
                        }
                    } else {
                        Button {
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
                        } label: {
                            Text("Remove Ads - \(removeAdsPrice)")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        }
                        .disabled(purchaseService.isLoading)
                    }

                    Button {
                        Task {
                            await purchaseService.restorePurchases()
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                    .disabled(purchaseService.isLoading)

                    if let errorMessage = purchaseService.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                } header: {
                    Text("Purchases")
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                }

                // MARK: Game Center
                Section {
                    if gameCenterEnabled {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Signed In")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                            Spacer()
                            Text(gameCenterDisplayName)
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Status Unknown")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                            Spacer()
                        }

                        Text("Sign in to Game Center in your device Settings, then tap Open Game Center below.")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isShowingGameCenter = true
                    } label: {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                            Text("Open Game Center")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        }
                    }
                } header: {
                    Text("Game Center")
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                }

                // MARK: Privacy
                Section {
                    Toggle(isOn: $analyticsEnabled) {
                        Text("Share Analytics")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                    .onChange(of: analyticsEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "analyticsEnabled")
                    }
                } header: {
                    Text("Privacy")
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                }
                
                // MARK: Support
                Section {
                    Button {
                        isShowingHowToPlay = true
                    } label: {
                        Text("How to Play")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }

                    Button {
                        isShowingTilesInfo = true
                    } label: {
                        Text("Tiles Info")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }

                    Button {
                        isShowingPerksInfo = true
                    } label: {
                        Text("Perks Info")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }

                    Button {
                        if let url = URL(string: "mailto:support@game2244.com?subject=Game Support") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Contact Support")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }

                    Button {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            if #available(iOS 18.0, *) {
                                AppStore.requestReview(in: scene)
                            } else {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                        }
                    } label: {
                        Text("Rate the Game")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }

                    Link(destination: URL(string: "https://game2244.com/privacy")!) {
                        Text("Privacy Policy")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                    Link(destination: URL(string: "https://game2244.com/terms")!) {
                        Text("Terms of Service")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }
                } header: {
                    Text("Support")
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                }
                
                // MARK: About
                Section {
                    HStack {
                        Text("Version")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        Spacer()
                        Text(appVersion)
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        GemBalancePill()
                        Button("Done") {
                            dismiss()
                        }
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
            .sheet(isPresented: $isShowingPerksInfo) {
                PerksInfoView()
            }
            .sheet(isPresented: $isShowingGameCenter) {
                gameCenterSheet
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

    @available(iOS, deprecated: 26.0)
    @MainActor
    private func makeGameCenterView() -> some View {
        GameCenterView()
    }

    @available(iOS, deprecated: 26.0)
    private var gameCenterSheet: some View {
        if #available(iOS 14.0, *) {
            return AnyView(makeGameCenterView())
        } else {
            return AnyView(EmptyView())
        }
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
@available(iOS, deprecated: 26.0, message: "GKGameCenterViewController is deprecated in iOS 26")
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

        @available(iOS, deprecated: 26.0)
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            let dismissAction = dismiss
            Task { @MainActor in
                dismissAction()
            }
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
    func playMergeSfx(tileCount: Int) async {}
    func stopAllSfx() async {}
    func setCurrentMusicTheme(_ theme: String) async {}
}

#Preview {
    SettingsView()
        .environment(\.audio, PreviewAudioService())
        .environment(\.hapticsService, HapticsService())
        .environment(\.purchaseService, PurchaseService())
}

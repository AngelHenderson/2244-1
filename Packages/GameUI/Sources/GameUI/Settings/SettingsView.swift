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
    @Environment(\.adService) private var adService
    
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
    @State private var isShowingValidMovesInfo: Bool = false
    @State private var gameCenterEnabled: Bool = false
    @State private var gameCenterDisplayName: String = ""
    @State private var isShowingReportPrompt: Bool = false
    @State private var showReportSubmittedToast: Bool = false
    @State private var isShowingSlotPicker: Bool = false
    @State private var isShowingReplayExport: Bool = false
    @State private var isShowingReplayImport: Bool = false
    @State private var isPrivacyOptionsRequired: Bool = false
    @State private var privacyOptionsMessage: String?
    
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
                        GameCenterManager.shared.presentDashboard()
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

                    if isPrivacyOptionsRequired {
                        Button {
                            Task {
                                let didPresent = await adService.showPrivacyOptions()
                                isPrivacyOptionsRequired = await adService.isPrivacyOptionsRequired()
                                privacyOptionsMessage = didPresent
                                    ? nil
                                    : "Ad privacy options are unavailable right now."
                            }
                        } label: {
                            Text("Ad Privacy Choices")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        }
                    }

                    if let privacyOptionsMessage {
                        Text(privacyOptionsMessage)
                            .foregroundStyle(.secondary)
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
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
                        isShowingValidMovesInfo = true
                    } label: {
                        Text("Valid Moves Info")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }

                    Button {
                        if let url = URL(string: "mailto:support@game2244.com?subject=Game Support") {
                            openPlatformURL(url)
                        }
                    } label: {
                        Text("Contact Support")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }

                    Button {
                        isShowingReportPrompt = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Report a Player")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        }
                    }

                    Button {
                        requestPlatformReview()
                    } label: {
                        Text("Rate the Game")
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                    }

                    if let privacyURL = URL(string: "https://game2244.com/privacy") {
                        Link(destination: privacyURL) {
                            Text("Privacy Policy")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        }
                    }
                    if let termsURL = URL(string: "https://game2244.com/terms") {
                        Link(destination: termsURL) {
                            Text("Terms of Service")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        }
                    }
                } header: {
                    Text("Support")
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                }
                
                // MARK: Game Data
                Section {
                    Button {
                        isShowingSlotPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundStyle(.tint)
                            Text("Save Slots")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        }
                    }

                    Button {
                        isShowingReplayExport = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.tint)
                            Text("Export Replay Code")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        }
                    }

                    Button {
                        isShowingReplayImport = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(.tint)
                            Text("Import Replay Code")
                                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        }
                    }
                } header: {
                    Text("Game Data")
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
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .platformTopBarTrailing) {
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
                isPrivacyOptionsRequired = await adService.isPrivacyOptionsRequired()
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
            .sheet(isPresented: $isShowingValidMovesInfo) {
                ValidMovesInfoView()
            }
            .sheet(isPresented: $isShowingReportPrompt) {
                ReportPlayerSheet(onSubmitted: { showReportSubmittedToast = true })
            }
            .sheet(isPresented: $isShowingSlotPicker) {
                SlotPickerView()
            }
            .sheet(isPresented: $isShowingReplayExport) {
                ReplayExportSheet()
            }
            .sheet(isPresented: $isShowingReplayImport) {
                ReplayImportSheet()
            }
            .alert("Report submitted", isPresented: $showReportSubmittedToast) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Thank you. Our team will review the report.")
            }
        }
        .trackScreen(.settings)
    }

    private func checkGameCenterStatus() {
        Task { @MainActor in
            let authenticated = await GameCenterManager.shared.authenticate()
            gameCenterEnabled = authenticated
            if authenticated {
                gameCenterDisplayName = GameCenterManager.shared.displayName
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
            removeAdsPrice = IAPProduct.adFreeProduct.formattedPrice
        }
        #else
        removeAdsPrice = IAPProduct.adFreeProduct.formattedPrice
        #endif
    }
}

// MARK: - Report Player Sheet

struct ReportPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeState.self) private var homeState
    @Environment(\.reportService) private var reportService

    @State private var playerName: String
    private let playerID: String?
    private let onSubmitted: (() -> Void)?

    @State private var selectedReason: String = "Cheating or memory editing"
    @State private var additionalDetails: String = ""
    @State private var showAreYouSure = false
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var submitError: String?
    @State private var blockAfterSubmit: Bool = false

    init(
        initialName: String = "",
        playerID: String? = nil,
        onSubmitted: (() -> Void)? = nil
    ) {
        _playerName = State(initialValue: initialName)
        self.playerID = playerID
        self.onSubmitted = onSubmitted
    }

    private let reasons: [String] = [
        "Cheating or memory editing",
        "Fake currency/gem generation",
        "Impossible scores or progression",
        "Speed hacks or timer manipulation",
        "Bots, macros, or auto-play",
        "Exploiting bugs repeatedly for unfair gain",
        "Refund or payment abuse",
        "Account selling, sharing, or ban evasion",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Player") {
                    TextField("Player Name", text: $playerName)
                }

                Section("Why are you reporting them?") {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(reasons, id: \.self) { reason in
                            Text(reason).tag(reason)
                        }
                    }

                    TextField("Additional details (optional)", text: $additionalDetails, axis: .vertical)
                        .lineLimit(4...8)
                }

                if let pid = playerID, !pid.isEmpty {
                    Section("Hide this player") {
                        Toggle("Also hide them from my leaderboard", isOn: $blockAfterSubmit)
                            .accessibilityHint("Hides this player from your leaderboard view; does not affect other players.")
                    }
                }

                if let submitError {
                    Section {
                        Text(submitError)
                            .foregroundStyle(.red)
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                }

                Section {
                    Button(action: { showAreYouSure = true }) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Submitting...")
                            } else if didSubmit {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Report submitted")
                            } else {
                                Text("Submit report")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .font(.avenirNext(size: GameFonts.bodySize, weight: .bold))
                    }
                    .disabled(isSubmitting || didSubmit || playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Report Player")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSubmit ? "Done" : "Cancel") { dismiss() }
                }
            }
            .alert("Submit this report?", isPresented: $showAreYouSure) {
                Button("Submit", role: .destructive) { Task { await submitReport() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Our team will review this report. You can also hide this player from your view at any time.")
            }
        }
    }

    @MainActor
    private func submitReport() async {
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedDetails = additionalDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        let report = PlayerReport(
            reportedPlayerName: trimmedName,
            reportedPlayerId: playerID,
            reason: selectedReason,
            additionalDetails: trimmedDetails.isEmpty ? nil : trimmedDetails
        )

        isSubmitting = true
        submitError = nil
        do {
            try await reportService.submit(report)
            didSubmit = true
            if blockAfterSubmit, let pid = playerID, !pid.isEmpty {
                homeState.block(playerID: pid)
            }
            onSubmitted?()
            // Brief delay so the player sees the green checkmark before dismissal.
            try? await Task.sleep(nanoseconds: 600_000_000)
            dismiss()
        } catch {
            submitError = "Could not send the report. Please try again."
        }
        isSubmitting = false
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
    func stopTickSound() async {}
    func setCurrentMusicTheme(_ theme: String) async {}
}

#Preview {
    SettingsView()
        .environment(\.audio, PreviewAudioService())
        .environment(\.hapticsService, HapticsService())
        .environment(\.purchaseService, PurchaseService())
}

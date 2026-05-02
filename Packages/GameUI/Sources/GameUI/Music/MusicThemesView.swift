import SwiftUI
import GameApp
import GameCore

@MainActor
struct MusicThemesView: View {
    struct Instrument: Identifiable, Hashable {
        let id: String
        let displayName: String
        let tagline: String
        let assetName: String
        let priceLabel: String
        let iapProductID: String?

        init(id: String, displayName: String, tagline: String, assetName: String,
             priceLabel: String, iapProductID: String? = nil) {
            self.id = id
            self.displayName = displayName
            self.tagline = tagline
            self.assetName = assetName
            self.priceLabel = priceLabel
            self.iapProductID = iapProductID
        }

        var isPremium: Bool { iapProductID != nil }
    }

    // Inputs. The last three instruments are wired to the existing premium theme
    // IAP product IDs so the paywall flow works end-to-end. Adjust the mapping if
    // the App Store Connect catalog grows different theme SKUs.
    var instruments: [Instrument] = [
        .init(id: "piano", displayName: "Piano", tagline: "Merge with Classic Warmth!", assetName: "piano", priceLabel: "Free"),
        .init(id: "xylophone", displayName: "Xylophone", tagline: "Merging Melodies Chime!", assetName: "xylophone", priceLabel: "Free"),
        .init(id: "guitar", displayName: "Guitar", tagline: "Strumming Merges Delight!", assetName: "guitar", priceLabel: "Free"),
        .init(id: "kalimba", displayName: "Kalimba", tagline: "Merge with Gentle Resonance!", assetName: "kalimba", priceLabel: "$1.99",
              iapProductID: "com.game2244.theme.lofi"),
        .init(id: "muted-nylon", displayName: "Muted Nylon", tagline: "Softly Merge Melodies!", assetName: "guitar", priceLabel: "$1.99",
              iapProductID: "com.game2244.theme.orchestral"),
        .init(id: "drum", displayName: "Drum", tagline: "Feel the Rhythm Merge!", assetName: "drum", priceLabel: "$1.99",
              iapProductID: "com.game2244.theme.cyberpunk")
    ]
    var onTry: @Sendable (Instrument) -> Void = { _ in }
    var onPurchase: @Sendable (Instrument) -> Void = { _ in }

    // State
    @State private var selectionIndex: Int = 0
    @State private var paywallInstrument: Instrument?
    @AppStorage("currentMusicTheme") private var currentTheme: String = "piano"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.audio) private var audioService
    @Environment(\.purchaseService) private var purchaseService
    @State private var previewTimer: Timer?
    @State private var previewTapIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            buttons
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
//        .background(Color.black.opacity(0.9).ignoresSafeArea())
        .onChange(of: selectionIndex) {
            let instrument = instruments[selectionIndex]
            startPreview(for: instrument.id)
        }
        .onAppear {
            let currentInstrument = instruments[selectionIndex]
            startPreview(for: currentInstrument.id)
        }
        .onDisappear {
            stopSequencedPreview()
            Task { await audioService.stopMusic() }
        }
        .sheet(item: $paywallInstrument) { instrument in
            ThemePaywallSheet(
                title: instrument.displayName,
                tagline: instrument.tagline,
                assetName: instrument.assetName,
                productID: instrument.iapProductID ?? "",
                onUnlocked: {
                    Task { await audioService.setCurrentMusicTheme(instrument.id) }
                    onPurchase(instrument)
                }
            )
        }
        .accessibilityElement(children: .contain)
        .trackScreen(.music)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.avenirNext(size: 28, weight: .semibold))
            }
            .accessibilityLabel("Close")

            Spacer()
            Text("MUSIC THEMES")
                .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))
                .textCase(.uppercase)
            Spacer()

            GemBalancePill()
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var content: some View {
        GeometryReader { geo in
            ZStack {
                TabView(selection: $selectionIndex) {
                    ForEach(Array(instruments.enumerated()), id: \.offset) { index, instrument in
                        instrumentPage(instrument)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .tag(index)
                    }
                }
                .platformPageTabViewStyle(indexDisplayMode: .never)

                // Left/Right arrows overlay
                HStack {
                    arrowButton(direction: .left) {
                        moveLeft()
                    }
                    Spacer()
                    arrowButton(direction: .right) {
                        moveRight()
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private func instrumentPage(_ instrument: Instrument) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Text(instrument.displayName.uppercased())
                .font(.avenirNext(size: GameFonts.largeTitleSize, weight: .heavy))
                .foregroundStyle(.primary)

            Text(instrument.tagline)
                .font(.avenirNext(size: GameFonts.title3Size, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Image(instrument.assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 320)
                .shadow(radius: 10, y: 6)
                .accessibilityLabel(Text(instrument.displayName))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            let instrument = instruments.indices.contains(selectionIndex) ? instruments[selectionIndex] : instruments.first!
            let isSelected = instrument.id == currentTheme
            let needsPurchase = instrument.isPremium && !purchaseService.isOwned(instrument.iapProductID ?? "")

            if isSelected {
                primaryButton(title: "Selected", role: .secondary) {
                    dismiss()
                }
            } else if needsPurchase {
                primaryButton(title: "Unlock for \(instrument.priceLabel)", role: .primary) {
                    paywallInstrument = instrument
                }
            } else {
                primaryButton(title: "Select", role: .primary) {
                    Task { await audioService.setCurrentMusicTheme(instrument.id) }
                    onTry(instrument)
                    dismiss()
                }
            }
        }
    }

    private enum PrimaryRole { case primary, secondary }

    private func primaryButton(title: String, role: PrimaryRole, action: @escaping () -> Void) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) {
                    Text(title)
                        .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.glass)
                .tint(role == .primary ? .green : .indigo)
                .accessibilityLabel(Text(title))
            } else {
                Button(action: action) {
                    Text(title)
                        .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: role == .primary ? [Color.green, Color.green.opacity(0.85)] : [Color.purple, Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                }
                .shadow(color: (role == .primary ? Color.green : Color.indigo).opacity(0.35), radius: 10, y: 6)
                .accessibilityLabel(Text(title))
            }
        }
    }

    private enum ArrowDirection { case left, right }

    private func arrowButton(direction: ArrowDirection, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: direction == .left ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                .font(.avenirNext(size: 36, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .shadow(radius: 2)
                .accessibilityLabel(direction == .left ? Text("Previous") : Text("Next"))
        }
        .padding(6)
    }

    // MARK: - Preview Playback

    /// Sequenced tap file lists for instruments with multiple tap sounds
    private static let sequencedTaps: [String: [String]] = [
        "xylophone": ["xylophone_tap_1", "xylophone_tap_2"],
    ]

    private func startPreview(for instrumentId: String) {
        stopSequencedPreview()

        if let taps = Self.sequencedTaps[instrumentId] {
            // Sequenced preview: alternate between tap files
            Task { await audioService.stopMusic() }
            previewTapIndex = 0
            // Play the first tap immediately
            Task { await audioService.playMusic(named: taps[0], loop: false) }
            // Timer to cycle through taps
            previewTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [self] _ in
                Task { @MainActor in
                    previewTapIndex = (previewTapIndex + 1) % taps.count
                    await audioService.playMusic(named: taps[previewTapIndex], loop: false)
                }
            }
        } else {
            // Single-file loop preview
            let soundName: String
            switch instrumentId {
            case "piano": soundName = "piano_tap_1"
            case "kalimba": soundName = "kalimba_tap_1"
            case "guitar": soundName = "guitar_tap_1"
            case "muted-nylon": soundName = "muted_nylon_tap_1"
            case "drum": soundName = "drum_tap_1"
            default:
                Task { await audioService.stopMusic() }
                return
            }
            Task { await audioService.playMusic(named: soundName, loop: true) }
        }
    }

    private func stopSequencedPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
    }

    // MARK: - Navigation

    private func moveLeft() {
        guard !instruments.isEmpty else { return }
        selectionIndex = (selectionIndex - 1 + instruments.count) % instruments.count
    }

    private func moveRight() {
        guard !instruments.isEmpty else { return }
        selectionIndex = (selectionIndex + 1) % instruments.count
    }
}

#Preview("Music Themes") {
    MusicThemesView()
        .background(Color.black)
}



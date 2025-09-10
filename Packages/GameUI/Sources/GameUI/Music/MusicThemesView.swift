import SwiftUI
import GameServices

@MainActor
struct MusicThemesView: View {
    struct Instrument: Identifiable, Hashable {
        let id: String
        let displayName: String
        let tagline: String
        let assetName: String
        let priceLabel: String
    }

    // Inputs
    var instruments: [Instrument] = [
        .init(id: "piano", displayName: "Piano", tagline: "Merge with Classic Warmth!", assetName: "piano", priceLabel: "$0.99"),
        .init(id: "harp", displayName: "Harp", tagline: "Merge with Ethereal Strings!", assetName: "harp", priceLabel: "$0.99"),
        .init(id: "xylophone", displayName: "Xylophone", tagline: "Merge with Bright Chimes!", assetName: "xylophone", priceLabel: "$0.99"),
        .init(id: "guitar", displayName: "Guitar", tagline: "Merge with Gentle Resonance!", assetName: "guitar", priceLabel: "$0.99"),
        .init(id: "kalimba", displayName: "Kalimba", tagline: "Merge with Gentle Resonance!", assetName: "kalimba", priceLabel: "$0.99"),
        .init(id: "muted-nylon", displayName: "Muted Nylon", tagline: "Merge with Soft Plucks!", assetName: "guitar", priceLabel: "$0.99"),
        .init(id: "drum", displayName: "Drum", tagline: "Merge with Rhythmic Beats!", assetName: "drum", priceLabel: "$0.99")
    ]
    var onTry: @Sendable (Instrument) -> Void = { _ in }
    var onPurchase: @Sendable (Instrument) -> Void = { _ in }

    // State
    @State private var selectionIndex: Int = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.audio) private var audioService

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            buttons
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
//        .background(Color.black.opacity(0.9).ignoresSafeArea())
        .onChange(of: selectionIndex) { _ in
            let instrument = instruments[selectionIndex]
            print("[MusicThemesView] Selected instrument: \(instrument.id) – start preview sound here")
            
            // Play specific background music for each instrument
            switch instrument.id {
            case "piano":
                Task { await audioService.playMusic(named: "piano_background", loop: true) }
            case "harp":
                Task { await audioService.playMusic(named: "harp_melody", loop: true) }
            case "xylophone":
                Task { await audioService.playMusic(named: "xylophone_melody", loop: true) }
            case "kalimba":
                Task { await audioService.playMusic(named: "kalimba_melody", loop: true) }
            case "guitar":
                Task { await audioService.playMusic(named: "acoustic_guitar_background", loop: true) }
            default:
                // For other instruments, stop current music
                Task { await audioService.stopMusic() }
            }
        }
        .onAppear {
            // Start appropriate background music for the initially selected instrument
            let currentInstrument = instruments[selectionIndex]
            switch currentInstrument.id {
            case "piano":
                Task { await audioService.playMusic(named: "piano_background", loop: true) }
            case "harp":
                Task { await audioService.playMusic(named: "harp_melody", loop: true) }
            case "xylophone":
                Task { await audioService.playMusic(named: "xylophone_melody", loop: true) }
            case "kalimba":
                Task { await audioService.playMusic(named: "kalimba_melody", loop: true) }
            case "guitar":
                Task { await audioService.playMusic(named: "acoustic_guitar_background", loop: true) }
            default:
                break
            }
        }
        .onDisappear {
            // Stop music when leaving the view
            Task { await audioService.stopMusic() }
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
            }
            .accessibilityLabel("Back")

            Spacer()
            Text("MUSIC THEMES")
                .font(.title2.weight(.bold))
                .textCase(.uppercase)
            Spacer()

            // Spacer button to balance layout
            Color.clear.frame(width: 28, height: 28)
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
                .tabViewStyle(.page(indexDisplayMode: .never))

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
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(.primary)

            Text(instrument.tagline)
                .font(.title3.weight(.semibold))
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
            let instrument = instruments[safe: selectionIndex] ?? instruments.first!
            // Try Now – host will handle ad presentation later
            primaryButton(title: "Try Now", role: .secondary) {
                // Set the music theme when trying
                Task { await audioService.setCurrentMusicTheme(instrument.id) }
                onTry(instrument)
            }
            // Purchase button
            primaryButton(title: instrument.priceLabel, role: .primary) {
                // Set the music theme when purchasing
                Task { await audioService.setCurrentMusicTheme(instrument.id) }
                onPurchase(instrument)
            }
        }
    }

    private enum PrimaryRole { case primary, secondary }

    private func primaryButton(title: String, role: PrimaryRole, action: @escaping () -> Void) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.glass)
                .tint(role == .primary ? .green : .indigo)
                .accessibilityLabel(Text(title))
            } else {
                Button(action: action) {
                    Text(title)
                        .font(.title2.weight(.bold))
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
                .font(.system(size: 36, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .shadow(radius: 2)
                .accessibilityLabel(direction == .left ? Text("Previous") : Text("Next"))
        }
        .padding(6)
    }

    private func moveLeft() {
        guard !instruments.isEmpty else { return }
        selectionIndex = (selectionIndex - 1 + instruments.count) % instruments.count
    }

    private func moveRight() {
        guard !instruments.isEmpty else { return }
        selectionIndex = (selectionIndex + 1) % instruments.count
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

#Preview("Music Themes") {
    MusicThemesView()
        .background(Color.black)
}



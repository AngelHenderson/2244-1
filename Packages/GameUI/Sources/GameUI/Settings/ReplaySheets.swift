import SwiftUI
import GameApp

@MainActor
struct ReplayExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameStore) private var gameStore
    @State private var code: String = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Share Replay")
                    .font(.title2.weight(.bold))

                Text("Anyone with this code can simulate the same run from the same starting seed and move history.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !code.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(code)
                            .font(.system(.footnote, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    HStack {
                        ShareLink(item: code) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = code
                            #endif
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                } else if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Export Replay")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                generate()
            }
        }
    }

    private func generate() {
        do {
            code = try gameStore.exportReplay()
        } catch {
            errorText = "Couldn't generate replay code: \(error.localizedDescription)"
        }
    }
}

@MainActor
struct ReplayImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameStore) private var gameStore
    @State private var input: String = ""
    @State private var resultMessage: String?
    @State private var resultIsError: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Replay a Shared Run")
                    .font(.title2.weight(.bold))

                Text("Paste a replay code (starts with GR1|...) to simulate it headlessly and see the resulting score.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $input)
                    .font(.system(.footnote, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 120)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    runImport()
                } label: {
                    Label("Simulate", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let resultMessage {
                    Text(resultMessage)
                        .foregroundStyle(resultIsError ? .red : .primary)
                        .font(.callout)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Import Replay")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func runImport() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let replay = try gameStore.importReplay(trimmed)
            let finalState = gameStore.simulateReplay(replay)
            resultIsError = false
            resultMessage = "Simulated. Final score: \(finalState.score.formatted()) • Highest tile: \(finalState.highestTile.formatted())"
        } catch let GameStore.ReplayError.unsupportedVersion(tag) {
            resultIsError = true
            resultMessage = "This replay uses unsupported version \"\(tag)\". Update the app to play it."
        } catch {
            resultIsError = true
            resultMessage = "Couldn't import: \(error.localizedDescription)"
        }
    }
}

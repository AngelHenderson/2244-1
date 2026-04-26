import SwiftUI
import GameApp
import GameCore

@MainActor
public struct SlotPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameStore) private var gameStore
    @Environment(\.storage) private var storage

    @AppStorage("currentSlotId") private var currentSlotId: String = ""
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "raised-3d-square"

    @State private var slots: [SaveSlotMeta] = []
    @State private var isLoading: Bool = true
    @State private var pendingDeleteSlot: SaveSlotMeta?

    public init() {}

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Save Slots")
                .platformNavigationTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .platformTopBarTrailing) {
                        Button {
                            createNewSlot()
                        } label: {
                            Label("New Slot", systemImage: "plus.circle.fill")
                        }
                    }
                }
                .task { await reload() }
                .alert(
                    "Delete this slot?",
                    isPresented: Binding(
                        get: { pendingDeleteSlot != nil },
                        set: { if !$0 { pendingDeleteSlot = nil } }
                    )
                ) {
                    Button("Cancel", role: .cancel) { pendingDeleteSlot = nil }
                    Button("Delete", role: .destructive) {
                        if let slot = pendingDeleteSlot {
                            Task { await deleteSlot(slot) }
                        }
                    }
                } message: {
                    if let slot = pendingDeleteSlot {
                        Text("Slot \"\(displayName(for: slot.id))\" will be permanently deleted.")
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if slots.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No save slots yet")
                    .font(.headline)
                Text("Tap the + button above to start a new game in a fresh slot.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(slots, id: \.id) { slot in
                        slotRow(slot)
                    }
                } footer: {
                    Text("Selecting a slot loads its saved board. The current slot is auto-saved as you play.")
                        .font(.footnote)
                }
            }
        }
    }

    private func slotRow(_ slot: SaveSlotMeta) -> some View {
        Button {
            Task { await selectSlot(slot) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: slot.id == currentSlotId ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(slot.id == currentSlotId ? Color.accentColor : .secondary)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(for: slot.id))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text("Best: \(slot.best.formatted())")
                        Text("•")
                        Text(slot.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeleteSlot = slot
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func displayName(for id: String) -> String {
        if id == "default" { return "Default" }
        let suffix = id.split(separator: "-").last.map(String.init) ?? id
        return "Slot \(suffix.prefix(6))"
    }

    private func reload() async {
        isLoading = true
        let loaded = await gameStore.listSlots(using: storage)
        slots = loaded
        if currentSlotId.isEmpty, let first = loaded.first {
            currentSlotId = first.id
        }
        isLoading = false
    }

    private func selectSlot(_ slot: SaveSlotMeta) async {
        currentSlotId = slot.id
        _ = await gameStore.load(from: slot.id, using: storage)
        await reload()
        dismiss()
    }

    private func createNewSlot() {
        let id = "slot-\(UUID().uuidString.prefix(8))"
        currentSlotId = id
        Task {
            await gameStore.save(to: id, using: storage, theme: selectedThemeId)
            await reload()
        }
    }

    private func deleteSlot(_ slot: SaveSlotMeta) async {
        await gameStore.deleteSlot(slot.id, using: storage)
        if slot.id == currentSlotId {
            currentSlotId = ""
        }
        pendingDeleteSlot = nil
        await reload()
    }
}

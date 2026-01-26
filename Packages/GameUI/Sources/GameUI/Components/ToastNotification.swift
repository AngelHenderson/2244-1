import SwiftUI

/// A floating toast notification that appears over the entire view
public struct ToastNotification: View {
    let message: String
    let icon: String?
    let iconColor: Color
    let onDismiss: () -> Void

    public init(
        message: String,
        icon: String? = nil,
        iconColor: Color = .white,
        onDismiss: @escaping () -> Void
    ) {
        self.message = message
        self.icon = icon
        self.iconColor = iconColor
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(message)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(6)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassBackground(in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }
}

/// Represents a toast notification to display
public struct ToastItem: Identifiable, Equatable {
    public let id = UUID()
    public let message: String
    public let icon: String?
    public let iconColor: Color
    public let duration: TimeInterval

    public init(
        message: String,
        icon: String? = nil,
        iconColor: Color = .white,
        duration: TimeInterval = 3.0
    ) {
        self.message = message
        self.icon = icon
        self.iconColor = iconColor
        self.duration = duration
    }

    public static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Container that manages and displays floating toast notifications
public struct ToastContainer<Content: View>: View {
    @Binding var currentToast: ToastItem?
    let content: Content

    public init(
        currentToast: Binding<ToastItem?>,
        @ViewBuilder content: () -> Content
    ) {
        self._currentToast = currentToast
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .top) {
            content

            // Floating toast overlay
            if let toast = currentToast {
                ToastNotification(
                    message: toast.message,
                    icon: toast.icon,
                    iconColor: toast.iconColor,
                    onDismiss: { dismissToast() }
                )
                .padding(.horizontal, 20)
                .padding(.top, 60) // Below status bar
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(1000)
                .onAppear {
                    scheduleAutoDismiss(duration: toast.duration)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentToast?.id)
    }

    private func dismissToast() {
        currentToast = nil
    }

    private func scheduleAutoDismiss(duration: TimeInterval) {
        let toastId = currentToast?.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            // Only dismiss if it's still the same toast
            if currentToast?.id == toastId {
                dismissToast()
            }
        }
    }
}

// MARK: - Toast Queue Manager

/// Observable manager for queueing and displaying toasts
@MainActor
@Observable
public final class ToastManager {
    public var currentToast: ToastItem?
    private var queue: [ToastItem] = []
    private var dismissTask: Task<Void, Never>?

    nonisolated public init() {}

    /// Show a toast notification
    public func show(
        _ message: String,
        icon: String? = nil,
        iconColor: Color = .white,
        duration: TimeInterval = 3.0
    ) {
        let toast = ToastItem(
            message: message,
            icon: icon,
            iconColor: iconColor,
            duration: duration
        )

        if currentToast == nil {
            present(toast)
        } else {
            queue.append(toast)
        }
    }

    /// Show a success toast
    public func showSuccess(_ message: String) {
        show(message, icon: "checkmark.circle.fill", iconColor: .green)
    }

    /// Show an error toast
    public func showError(_ message: String) {
        show(message, icon: "exclamationmark.circle.fill", iconColor: .red)
    }

    /// Show a boost activated toast
    public func showBoostActivated(_ label: String) {
        show("\(label) Activated!", icon: "bolt.fill", iconColor: .yellow)
    }

    /// Show a boost queued toast
    public func showBoostQueued(_ label: String) {
        show("\(label) Queued", icon: "clock.fill", iconColor: .orange)
    }

    /// Show a discount activated toast
    public func showDiscountActivated(_ label: String) {
        show("\(label) Active!", icon: "wand.and.stars", iconColor: .purple)
    }

    /// Dismiss the current toast
    public func dismiss() {
        dismissTask?.cancel()
        currentToast = nil
        showNextInQueue()
    }

    private func present(_ toast: ToastItem) {
        currentToast = toast

        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(toast.duration))
            if !Task.isCancelled {
                currentToast = nil
                showNextInQueue()
            }
        }
    }

    private func showNextInQueue() {
        guard !queue.isEmpty else { return }
        let next = queue.removeFirst()
        // Small delay between toasts
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            present(next)
        }
    }
}

// MARK: - Environment Key

public struct ToastManagerKey: EnvironmentKey {
    public static let defaultValue = ToastManager()
}

public extension EnvironmentValues {
    var toastManager: ToastManager {
        get { self[ToastManagerKey.self] }
        set { self[ToastManagerKey.self] = newValue }
    }
}

// MARK: - View Extension

public extension View {
    /// Adds a floating toast notification overlay to the view
    func toastOverlay(manager: ToastManager) -> some View {
        ToastContainer(currentToast: Binding(
            get: { manager.currentToast },
            set: { manager.currentToast = $0 }
        )) {
            self
        }
    }
}

#Preview("Toast Notification") {
    struct PreviewContainer: View {
        @State private var manager = ToastManager()

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Button("Show Success") {
                        manager.showSuccess("Purchase Complete!")
                    }
                    Button("Show Boost") {
                        manager.showBoostActivated("5× Score")
                    }
                    Button("Show Queued") {
                        manager.showBoostQueued("20× Score")
                    }
                    Button("Show Discount") {
                        manager.showDiscountActivated("25% Off Power-Ups")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .toastOverlay(manager: manager)
        }
    }

    return PreviewContainer()
}

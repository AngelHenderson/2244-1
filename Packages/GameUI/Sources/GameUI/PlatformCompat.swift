import SwiftUI

#if canImport(StoreKit)
import StoreKit
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if os(macOS)
typealias UIImage = NSImage
typealias UIColor = NSColor

extension Image {
    init(uiImage: NSImage) {
        self.init(nsImage: uiImage)
    }
}

extension Color {
    init(uiColor: NSColor) {
        self.init(nsColor: uiColor)
    }
}

extension NSColor {
    static var systemBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemBackground: NSColor { .controlBackgroundColor }
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemGroupedBackground: NSColor { .underPageBackgroundColor }
    static var tertiarySystemGroupedBackground: NSColor { .textBackgroundColor }
    static var separator: NSColor { .separatorColor }
    static var systemGray4: NSColor { .tertiaryLabelColor }
    static var systemGray5: NSColor { .quaternaryLabelColor }
    static var systemGray6: NSColor { .controlBackgroundColor }
}
#endif

enum PlatformNavigationTitleDisplayMode {
    case automatic
    case inline
    case large
}

enum PlatformPageIndexDisplayMode {
    case automatic
    case always
    case never
}

extension ToolbarItemPlacement {
    static var platformTopBarTrailing: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .topBarTrailing
        #endif
    }
}

extension View {
    @ViewBuilder
    func platformNavigationTitleDisplayMode(_ displayMode: PlatformNavigationTitleDisplayMode) -> some View {
        #if os(macOS)
        self
        #else
        switch displayMode {
        case .automatic:
            self.navigationBarTitleDisplayMode(.automatic)
        case .inline:
            self.navigationBarTitleDisplayMode(.inline)
        case .large:
            self.navigationBarTitleDisplayMode(.large)
        }
        #endif
    }

    @ViewBuilder
    func platformPageTabViewStyle(indexDisplayMode: PlatformPageIndexDisplayMode = .automatic) -> some View {
        #if os(macOS)
        self
        #else
        switch indexDisplayMode {
        case .automatic:
            self.tabViewStyle(.page(indexDisplayMode: .automatic))
        case .always:
            self.tabViewStyle(.page(indexDisplayMode: .always))
        case .never:
            self.tabViewStyle(.page(indexDisplayMode: .never))
        }
        #endif
    }

    @ViewBuilder
    func platformTextInputAutocapitalizationWords() -> some View {
        #if os(macOS)
        self
        #else
        self.textInputAutocapitalization(.words)
        #endif
    }

    @ViewBuilder
    func platformTextInputAutocapitalizationNever() -> some View {
        #if os(macOS)
        self
        #else
        self.textInputAutocapitalization(.never)
        #endif
    }

    @ViewBuilder
    func platformNavigationBarHidden() -> some View {
        #if os(macOS)
        self
        #else
        self.toolbar(.hidden, for: .navigationBar)
        #endif
    }

    @ViewBuilder
    func platformInsetGroupedListStyle() -> some View {
        #if os(macOS)
        self.listStyle(.automatic)
        #else
        self.listStyle(.insetGrouped)
        #endif
    }

    @ViewBuilder
    func platformFullScreenCover<SheetContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        #if os(macOS)
        self.sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #endif
    }

    @ViewBuilder
    func platformFullScreenCover<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        #if os(macOS)
        self.sheet(item: item, onDismiss: onDismiss, content: content)
        #else
        self.fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #endif
    }
}

@MainActor
func openPlatformURL(_ url: URL) {
    #if os(macOS)
    NSWorkspace.shared.open(url)
    #else
    UIApplication.shared.open(url)
    #endif
}

@MainActor
func requestPlatformReview() {
    #if os(iOS)
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
        return
    }

    AppStore.requestReview(in: scene)
    #else
    // Non-iOS builds (Mac Catalyst preview, Mac unit-test host) do not present
    // a review prompt. The iOS device is the only shipping platform.
    #endif
}

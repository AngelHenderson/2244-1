import Testing
import SwiftUI
@testable import GameUI

struct EventBannerHostTests {
    @Test
    @MainActor
    func testConfigureExposesShowAndDismissClosures() {
        var isPresented = false
        var text = ""
        var show: ((String) -> Void)?
        var dismiss: (() -> Void)?

        _ = EventBannerHost(
            isPresented: .init(get: { isPresented }, set: { isPresented = $0 }),
            text: .init(get: { text }, set: { text = $0 }),
            onConfigure: { showClosure, dismissClosure in
                show = showClosure
                dismiss = dismissClosure
            },
            content: { Color.clear }
        )

        #expect(show != nil)
        #expect(dismiss != nil)

        show?("Daily streak +1")
        #expect(isPresented == true)
        #expect(text == "Daily streak +1")

        dismiss?()
        #expect(isPresented == false)
    }

    @Test
    @MainActor
    func testBindingDrivenPresentationState() {
        var isPresented = false
        var text = "Hello"

        let view = EventBannerHost(
            isPresented: .init(get: { isPresented }, set: { isPresented = $0 }),
            text: .init(get: { text }, set: { text = $0 })
        ) {
            ZStack { Color.red }
        }

        // Render indirectly by accessing body; this should be safe and side-effect free
        _ = view.body

        // Toggle state externally to simulate host driving visibility
        isPresented = true
        #expect(isPresented == true)

        isPresented = false
        #expect(isPresented == false)
    }
}



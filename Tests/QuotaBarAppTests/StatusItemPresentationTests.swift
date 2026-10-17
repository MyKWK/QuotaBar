import AppKit
import Foundation
import Testing
@testable import QuotaBarApp

@Suite("Status item presentation")
struct StatusItemPresentationTests {
    private let primary = StatusItemPresentation.ScreenFrame(
        frame: NSRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: NSRect(x: 0, y: 0, width: 1440, height: 875)
    )
    private let secondary = StatusItemPresentation.ScreenFrame(
        frame: NSRect(x: 1440, y: 0, width: 1920, height: 1080),
        visibleFrame: NSRect(x: 1440, y: 0, width: 1920, height: 1055)
    )

    private var screens: [StatusItemPresentation.ScreenFrame] {
        [primary, secondary]
    }

    @Test("mouse on a replicant picks that display even if the real item is elsewhere")
    func mouseOnReplicantPicksCurrentDisplay() {
        let context = StatusItemPresentation.Context(
            mouseLocation: NSPoint(x: 2000, y: 1070),
            eventWindowFrame: NSRect(x: 3180, y: 1056, width: 72, height: 24),
            statusItemFrame: NSRect(x: 1200, y: 876, width: 72, height: 24),
            isMouseEvent: true
        )

        let visible = StatusItemPresentation.targetVisibleFrame(context: context, screens: screens)
        #expect(visible == secondary.visibleFrame)

        let frame = StatusItemPresentation.centeredFrame(
            size: NSSize(width: 720, height: 500),
            visibleFrame: visible
        )
        #expect(StatusItemPresentation.isFrameOnScreen(frame, visibleFrame: secondary.visibleFrame))
        #expect(!StatusItemPresentation.isFrameOnScreen(frame, visibleFrame: primary.visibleFrame))
    }

    @Test("keyboard navigation falls back to the real status item screen")
    func keyboardUsesStatusItemScreen() {
        let context = StatusItemPresentation.Context(
            mouseLocation: NSPoint(x: 2000, y: 1070),
            eventWindowFrame: NSRect(x: 3180, y: 1056, width: 72, height: 24),
            statusItemFrame: NSRect(x: 1200, y: 876, width: 72, height: 24),
            isMouseEvent: false
        )

        let visible = StatusItemPresentation.targetVisibleFrame(context: context, screens: screens)
        #expect(visible == primary.visibleFrame)
    }

    @Test("menu-bar clicks on the top edge still belong to that screen")
    func menuBarTopEdgeIsIncluded() {
        let point = NSPoint(x: 200, y: primary.frame.maxY)
        #expect(StatusItemPresentation.containsMenuBarPoint(primary.frame, point))
        #expect(!primary.frame.contains(point))
    }

    @Test("centered frame stays inside the visible display")
    func centeredFrameStaysOnScreen() {
        let frame = StatusItemPresentation.centeredFrame(
            size: NSSize(width: 720, height: 500),
            visibleFrame: secondary.visibleFrame
        )
        #expect(frame.width == 720)
        #expect(frame.height == 500)
        #expect(frame.minX >= secondary.visibleFrame.minX)
        #expect(frame.maxX <= secondary.visibleFrame.maxX)
        #expect(frame.minY >= secondary.visibleFrame.minY)
        #expect(frame.maxY <= secondary.visibleFrame.maxY)
    }
}

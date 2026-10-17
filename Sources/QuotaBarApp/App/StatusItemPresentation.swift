import AppKit

// MARK: - Status item window placement
//
// `NSStatusItem.button.window` lives on one screen. macOS also draws replicants
// on other menu bars, so a click on the current display can still report the
// original item's frame. Prefer the mouse / event window from that click, then
// fall back to the real button.

enum StatusItemPresentation {
    struct ScreenFrame: Equatable {
        var frame: NSRect
        var visibleFrame: NSRect
    }

    struct Context: Equatable {
        var mouseLocation: NSPoint
        var eventWindowFrame: NSRect?
        var statusItemFrame: NSRect
        var isMouseEvent: Bool
    }

    private static let mouseEventTypes: Set<NSEvent.EventType> = [
        .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp
    ]

    @MainActor
    static func capture(button: NSStatusBarButton?) -> Context {
        let event = NSApp.currentEvent
        let isMouseEvent = event.map { mouseEventTypes.contains($0.type) } ?? false
        let statusItemFrame: NSRect
        if let button, let window = button.window {
            statusItemFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        } else {
            let mouse = NSEvent.mouseLocation
            statusItemFrame = NSRect(origin: mouse, size: NSSize(width: 1, height: 1))
        }
        return Context(
            mouseLocation: NSEvent.mouseLocation,
            eventWindowFrame: isMouseEvent ? event?.window?.frame : nil,
            statusItemFrame: statusItemFrame,
            isMouseEvent: isMouseEvent
        )
    }

    static func targetVisibleFrame(
        context: Context,
        screens: [ScreenFrame]
    ) -> NSRect {
        let mouse = context.isMouseEvent ? context.mouseLocation : nil
        let eventFrame = context.isMouseEvent ? context.eventWindowFrame : nil
        if let index = screenIndex(
            mouseLocation: mouse,
            eventWindowFrame: eventFrame,
            statusItemFrame: context.statusItemFrame,
            screens: screens
        ) {
            return screens[index].visibleFrame
        }
        return screens.first?.visibleFrame ?? .zero
    }

    @MainActor
    static func targetVisibleFrame(context: Context) -> NSRect {
        targetVisibleFrame(
            context: context,
            screens: NSScreen.screens.map { ScreenFrame(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        )
    }

    static func screenIndex(
        mouseLocation: NSPoint?,
        eventWindowFrame: NSRect?,
        statusItemFrame: NSRect?,
        screens: [ScreenFrame]
    ) -> Int? {
        if let mouseLocation, let index = screens.firstIndex(where: { containsMenuBarPoint($0.frame, mouseLocation) }) {
            return index
        }
        if let eventWindowFrame, let index = screens.firstIndex(where: { $0.frame.intersects(eventWindowFrame) }) {
            return index
        }
        if let statusItemFrame, let index = screens.firstIndex(where: { $0.frame.intersects(statusItemFrame) }) {
            return index
        }
        return screens.isEmpty ? nil : 0
    }

    static func centeredFrame(
        size: NSSize,
        visibleFrame: NSRect,
        margin: CGFloat = 16
    ) -> NSRect {
        let usable = visibleFrame.insetBy(dx: margin, dy: margin)
        var frame = NSRect(origin: .zero, size: size)
        if size.width >= usable.width {
            frame.origin.x = usable.midX - size.width / 2
        } else {
            frame.origin.x = min(max(usable.midX - size.width / 2, usable.minX), usable.maxX - size.width)
        }
        if size.height >= usable.height {
            frame.origin.y = usable.midY - size.height / 2
        } else {
            frame.origin.y = min(max(usable.midY - size.height / 2, usable.minY), usable.maxY - size.height)
        }
        return frame
    }

    static func isFrameOnScreen(_ frame: NSRect, visibleFrame: NSRect) -> Bool {
        visibleFrame.contains(NSPoint(x: frame.midX, y: frame.midY))
    }

    /// Menu-bar clicks sit on the top edge; AppKit treats `maxY` as outside `contains`.
    static func containsMenuBarPoint(_ rect: NSRect, _ point: NSPoint) -> Bool {
        point.x >= rect.minX && point.x < rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }
}

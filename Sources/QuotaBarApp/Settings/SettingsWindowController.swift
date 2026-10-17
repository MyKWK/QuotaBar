import AppKit
import SwiftUI

// MARK: - Settings window
//
// The standalone, settings-style main window that replaced the status bar popover
// panel. Sidebar is 通用、流水账, plus one page per registered `ServiceKind`. Opened by
// the status item's expanded-interface session. Chrome is fixed-intensity
// interactive Liquid Glass.

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let contentSize = NSSize(width: 720, height: 500)
    static let minimumContentSize = NSSize(width: 640, height: 420)
    static let hostingSizingOptions: NSHostingSizingOptions = [.minSize]

    private let appState: AppState
    private var window: NSWindow?
    var onWindowWillClose: (() -> Void)?

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    var windowForTesting: NSWindow? { window }

    var isWindowVisible: Bool {
        window?.isVisible == true
    }

    func show(using context: StatusItemPresentation.Context) {
        if window == nil {
            let controller = FrostedGlassHostingController(
                rootView: SettingsRootView(appState: appState),
                sizingOptions: Self.hostingSizingOptions
            )
            // Do not let SwiftUI's intrinsic/ideal size drive the NSWindow.
            // Placeholder pages used to report an unbounded height and stretch
            // the whole settings window when switching to ZCode.
            let window = SettingsWindow(contentViewController: controller)
            window.title = "QuotaBar"
            window.styleMask = FrostedGlassChrome.settingsWindowStyleMask
            FrostedGlassChrome.apply(to: window)
            window.setContentSize(Self.contentSize)
            window.contentMinSize = Self.minimumContentSize
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.collectionBehavior.formUnion(MenuBarForeground.collectionBehavior)
            window.delegate = self
            self.window = window
        }

        appState.refreshLaunchAtLoginState()
        placeOnCurrentDisplay(using: context)
        if let window {
            MenuBarForeground.bringToFront(window)
        }
    }

    func show() {
        show(using: StatusItemPresentation.capture(button: nil))
    }

    func makeKey() {
        guard let window else { return }
        MenuBarForeground.bringToFront(window)
    }

    /// Center on the display the user actually clicked. `NSWindow.center()` uses
    /// the key-window screen, which for a menu-bar replicant is often a different
    /// monitor than the one in front of the user.
    private func placeOnCurrentDisplay(using context: StatusItemPresentation.Context) {
        guard let window else { return }
        let visibleFrame = StatusItemPresentation.targetVisibleFrame(context: context)
        guard !visibleFrame.isEmpty else { return }
        if window.isVisible, StatusItemPresentation.isFrameOnScreen(window.frame, visibleFrame: visibleFrame) {
            return
        }
        window.setFrame(
            StatusItemPresentation.centeredFrame(size: window.frame.size, visibleFrame: visibleFrame),
            display: false
        )
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window, notification.object as? NSWindow === window else { return }
        MenuBarForeground.settleLevelIfActive(window)
    }

    func windowWillClose(_ notification: Notification) {
        _ = notification
        onWindowWillClose?()
        MenuBarForeground.restoreAccessoryPolicyIfNeeded(closing: window)
    }
}

/// Ordinary key window, not the menu-bar expanded-interface scene. ⌘V and the
/// other Edit keys are delivered to the field editor here instead of being
/// swallowed by the status item session.
final class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if TextEditingKeyEquivalents.perform(event, in: self) {
                return
            }
            if WindowKeyEquivalents.perform(event, in: self) {
                return
            }
        }
        super.sendEvent(event)
    }
}

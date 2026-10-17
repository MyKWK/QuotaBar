import AppKit

// MARK: - Bring a menu-bar window to the front
//
// QuotaBar runs as `.accessory`, so `NSApp.activate()` is cooperative and will
// not steal focus from the current app or Space. Opening the settings window
// from the status item has to become `.regular`, hop to the active Space, and
// order front regardless of who is currently key.

@MainActor
enum MenuBarForeground {
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .moveToActiveSpace,
        .fullScreenAuxiliary
    ]

    static func bringToFront(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        window.collectionBehavior.formUnion(collectionBehavior)
        window.hidesOnDeactivate = false

        // `moveToActiveSpace` only applies when the window is ordered in.
        // Pull it out first so a copy sitting on another desktop cannot keep
        // the user there, then order it onto the Space they just clicked from.
        if window.isVisible {
            window.orderOut(nil)
        }

        window.level = .floating
        NSApp.unhide(nil)
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        window.orderFrontRegardless()
        NSApp.activate()
        NSRunningApplication.current.activate(options: [.activateAllWindows])

        Task { @MainActor in
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            settleLevelIfActive(window)
        }
    }

    static func settleLevelIfActive(_ window: NSWindow) {
        guard NSApp.isActive, window.isVisible else { return }
        window.level = .normal
    }

    static func restoreAccessoryPolicyIfNeeded(closing closingWindow: NSWindow?) {
        Task { @MainActor in
            let hasMainWindow = NSApp.windows.contains { window in
                window !== closingWindow && window.isVisible && window.canBecomeMain
            }
            if !hasMainWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

import AppKit
import SwiftUI
import Testing
@testable import QuotaBarApp

@Suite("Settings layout")
struct SettingsLayoutTests {
    @Test("ZCode placeholder reports a bounded fitting size")
    @MainActor
    func zcodePlaceholderDoesNotInflateWindow() {
        let host = NSHostingView(rootView: ServiceSettingsView(appState: AppState(), service: .zcode))
        host.layoutSubtreeIfNeeded()

        let fitting = host.fittingSize
        #expect(fitting.height < 900)
        #expect(fitting.width < 1100)
        #expect(fitting.height > 80)
    }

    @Test("each service page keeps a bounded origin card")
    @MainActor
    func originCardDoesNotInflateWindow() {
        for service in ServiceKind.allCases {
            let host = NSHostingView(rootView: ServiceSettingsView(appState: AppState(), service: service))
            host.layoutSubtreeIfNeeded()
            let fitting = host.fittingSize
            #expect(fitting.height < 900)
            #expect(fitting.width < 1100)
            #expect(fitting.height > 80)
        }
    }

    @Test("Cursor settings page reports a bounded fitting size")
    @MainActor
    func cursorSettingsDoesNotInflateWindow() {
        let host = NSHostingView(rootView: ServiceSettingsView(appState: AppState(), service: .cursor))
        host.layoutSubtreeIfNeeded()

        let fitting = host.fittingSize
        #expect(fitting.height < 900)
        #expect(fitting.width < 1100)
        #expect(fitting.height > 80)
    }

    @Test("settings sidebar is general, hourly ledger, then every ServiceKind")
    func settingsSidebarFollowsServiceKinds() {
        #expect(
            SettingsSection.allSections
                == [.general, .history] + ServiceKind.allCases.map(SettingsSection.service)
        )
    }

    @Test("hourly ledger page reports a bounded empty fitting size")
    @MainActor
    func historyPageEmptyIsBounded() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotabar-history-layout-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = QuotaHistoryStore(
            databaseURL: directory.appendingPathComponent("quota-history.sqlite")
        )
        defer { store.close() }
        let recorder = QuotaHistoryRecorder(store: store)
        let host = NSHostingView(
            rootView: QuotaHistorySettingsView(store: store, recorder: recorder)
        )
        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        #expect(fitting.height < 900)
        #expect(fitting.width < 1100)
        #expect(fitting.height > 80)
    }

    @Test("settings window does not follow unbounded SwiftUI intrinsic size")
    @MainActor
    func settingsWindowIgnoresIntrinsicContentSize() {
        #expect(!SettingsWindowController.hostingSizingOptions.contains(.intrinsicContentSize))
        #expect(SettingsWindowController.hostingSizingOptions.contains(.minSize))
    }

    @Test("settings window uses fixed system glass chrome")
    @MainActor
    func settingsWindowUsesFixedFrostedGlass() throws {
        #expect(FrostedGlassChrome.settingsWindowStyleMask.contains(.fullSizeContentView))
        #expect(FrostedGlassChrome.glassStyle == .regular)
        #expect(FrostedGlassChrome.cardGlass != .regular)
        #expect(FrostedGlassChrome.cardGlass != .clear)
        #expect(FrostedGlassChrome.cardGlass != .identity)

        let controller = SettingsWindowController(appState: AppState())
        controller.show()
        let window = try #require(controller.windowForTesting)
        #expect(window is SettingsWindow)
        #expect(window.canBecomeKey)
        #expect(window.canBecomeMain)
        #expect(window.isOpaque == false)
        #expect(window.backgroundColor == .clear)
        #expect(window.titlebarAppearsTransparent)
        #expect(window.styleMask.contains(.fullSizeContentView))
        #expect(window.contentView is FrostedGlassRootView)

        let backdrop = try #require(window.contentView)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            #expect(!(backdrop.subviews.contains { $0 is NSGlassEffectView }))
        } else {
            let glass = backdrop.subviews.compactMap { $0 as? NSGlassEffectView }.first
            #expect(glass != nil)
            #expect(glass?.style == .regular)
            #expect(glass?.tintColor == nil)
            #expect(glass?.effectIsInteractive == true)
        }
        window.close()
    }

    @Test("settings window follows the clicked display instead of NSWindow.center")
    @MainActor
    func settingsWindowMovesToActiveSpace() throws {
        let controller = SettingsWindowController(appState: AppState())
        controller.show()
        let window = try #require(controller.windowForTesting)
        #expect(window.collectionBehavior.contains(.moveToActiveSpace))
        #expect(window.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(!window.isRestorable)
        #expect(window.hidesOnDeactivate == false)
        window.close()
    }

    @Test("⌘W closes the settings window")
    @MainActor
    func commandWClosesSettingsWindow() throws {
        let controller = SettingsWindowController(appState: AppState())
        controller.show()
        let window = try #require(controller.windowForTesting)
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "w",
                charactersIgnoringModifiers: "w",
                isARepeat: false,
                keyCode: 13
            )
        )
        window.sendEvent(event)
        #expect(window.isVisible == false)
    }
}

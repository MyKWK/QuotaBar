import AppKit
import Combine
import SwiftUI

final class DashboardPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: DashboardLayout.panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Fallback when SwiftUI does not consume Esc (e.g. focus outside the hosting view).
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

@MainActor
final class StatusBarController: NSObject, NSWindowDelegate, @MainActor NSStatusItemExpandedInterfaceDelegate {
    let statusItem: NSStatusItem
    let dashboardPanel: DashboardPanel
    var globalEventMonitor: Any?
    var localEventMonitor: Any?
    var applicationResignObserver: NSObjectProtocol?
    let appState: AppState
    let updateService = UpdateService()
    let launchAtLoginService = LaunchAtLoginService()
    var isCheckingForUpdates = false
    var isInstallingUpdate = false
    var availableRelease: UpdateRelease?
    var updateProgressWindow: NSWindow?
    var updateProgressIndicator: NSProgressIndicator?
    var updateProgressTitleLabel: NSTextField?
    var updateProgressDetailLabel: NSTextField?
    var pendingPanelPresentationTask: Task<Void, Never>?
    var pendingSettingsPresentation: StatusItemPresentation.Context?
    private var fallbackIcon: NSImage?
    private var lastRenderFingerprint: StatusBarRenderFingerprint?
    private var menuBarAppearanceObservation: NSKeyValueObservation?
    private var isStatusTitleUpdateScheduled = false
    var isPresentingRestartPrompt = false
    var cancellables = Set<AnyCancellable>()
    lazy var settingsWindowController = SettingsWindowController(appState: appState)

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.dashboardPanel = DashboardPanel()
        super.init()

        appState.registerUpdateActions(
            checkForUpdates: { [weak self] in
                Task { @MainActor in
                    self?.performUpdateCheck(showFeedback: true)
                }
            },
            installAvailableUpdate: { [weak self] in
                Task { @MainActor in
                    self?.installAvailableUpdateFromDashboard()
                }
            },
            ignoreAvailableUpdate: { [weak self] in
                Task { @MainActor in
                    self?.ignoreAvailableUpdateFromDashboard()
                }
            }
        )
        appState.registerLaunchAtLoginActions(
            isEnabled: { [weak self] in
                self?.launchAtLoginService.isEnabled ?? false
            },
            setEnabled: { [weak self] enabled in
                self?.setLaunchAtLoginEnabled(enabled)
            }
        )

        configureStatusItem()
        configureDashboardPanel()
        performUpdateCheck(showFeedback: false)
    }

    func shutdown() {
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let applicationResignObserver {
            NotificationCenter.default.removeObserver(applicationResignObserver)
            self.applicationResignObserver = nil
        }
        pendingPanelPresentationTask?.cancel()
        pendingPanelPresentationTask = nil
        pendingSettingsPresentation = nil
        menuBarAppearanceObservation?.invalidate()
        menuBarAppearanceObservation = nil
        statusItem.expandedInterfaceSession?.cancel()
        dashboardPanel.close()
    }

    // One single-line capsule per service enabled on the General settings page,
    // side by side. Clicking any of them opens the settings window.
    func updateStatusTitle() {
        guard let button = statusItem.button else { return }

        let inputs = ServiceKind.menuBarOrder
            .filter { appState.isServiceVisibleInMenuBar($0) }
            .map { service in
                let reading = appState.menuBarReading(for: service)
                return StatusBarServiceInput(
                    service: service,
                    remainingPercent: reading.remainingPercent,
                    headline: reading.headline,
                    placeholderHeadline: reading.placeholderHeadline,
                    headlineKind: reading.headlineKind,
                    warningLevel: reading.warningLevel
                )
            }
        let entries = StatusBarServicesPresenter.entries(for: inputs)
        let display = entries.isEmpty ? nil : StatusBarServicesDisplay(items: entries)
        let appearance = button.effectiveAppearance
        let scale = max(
            button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2,
            1
        )
        let fingerprint = StatusBarRenderFingerprint(
            items: entries,
            isDark: MenuBarContrast.isDark(appearance),
            appearanceName: appearance.name.rawValue,
            scale: (scale * 100).rounded() / 100
        )

        button.toolTip = StatusBarServicesPresenter.tooltip(for: entries)
        button.setAccessibilityLabel(button.toolTip ?? "QuotaBar")

        let length = display?.preferredStatusItemLength ?? NSStatusItem.squareLength
        if statusItem.length != length {
            statusItem.length = length
        }

        guard fingerprint != lastRenderFingerprint else { return }
        lastRenderFingerprint = fingerprint

        let icon = fallbackIcon ?? Branding.makeMenuBarIcon(size: 17.5)
        button.image = StatusBarServicesRenderer.makeImage(
            display: display,
            fallbackIcon: icon,
            appearance: appearance,
            scale: scale
        )
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        applyMenuBarIcon(to: button)
        statusItem.autosaveName = "QuotaBar.StatusItem"
        statusItem.expandedInterfaceDelegate = self
        // Left click and keyboard navigation go through the expanded-interface
        // session. Right click still presents the context menu.
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.rightMouseUp])
        button.target = self
        settingsWindowController.onWindowWillClose = { [weak self] in
            self?.pendingSettingsPresentation = nil
            self?.statusItem.expandedInterfaceSession?.cancel()
        }
        updateStatusTitle()
    }

    func scheduleStatusTitleUpdate() {
        guard !isStatusTitleUpdateScheduled else { return }
        isStatusTitleUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isStatusTitleUpdateScheduled = false
            self.updateStatusTitle()
        }
    }

    private func applyMenuBarIcon(to button: NSStatusBarButton) {
        let iconSize: CGFloat = 17.5
        fallbackIcon = Branding.makeMenuBarIcon(size: iconSize)
        lastRenderFingerprint = nil
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = nil
        observeMenuBarAppearance(button)
    }

    private func observeMenuBarAppearance(_ button: NSStatusBarButton) {
        menuBarAppearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.scheduleStatusTitleUpdate()
            }
        }
    }

}

private struct StatusBarRenderFingerprint: Equatable {
    var items: [StatusBarServiceEntry]
    var isDark: Bool
    var appearanceName: String
    var scale: CGFloat
}

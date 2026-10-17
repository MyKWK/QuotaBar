import Foundation

extension AppState {
    func isServiceVisibleInMenuBar(_ service: ServiceKind) -> Bool {
        menuBarVisibleServices.contains(service)
    }

    func setServiceVisibleInMenuBar(_ service: ServiceKind, _ visible: Bool) {
        if visible {
            menuBarVisibleServices.insert(service)
        } else {
            menuBarVisibleServices.remove(service)
        }
        AppPreferencesStore.setMenuBarVisibleServices(menuBarVisibleServices)
    }

    /// Live reading a menu bar capsule should show. Always comes from the
    /// registered collector plugin; unimplemented services yield no number.
    func menuBarReading(for service: ServiceKind) -> QuotaServiceReading {
        quotaServices.plugin(for: service).reading
    }

    /// Remaining percent a menu bar capsule should show. Always comes from the
    /// registered collector plugin; unimplemented services yield `nil`.
    func menuBarRemainingPercent(for service: ServiceKind) -> Int? {
        menuBarReading(for: service).remainingPercent
    }
}

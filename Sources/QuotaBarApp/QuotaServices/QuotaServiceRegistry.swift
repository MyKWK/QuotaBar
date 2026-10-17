import Combine
import Foundation

/// Owns the quota-collection plugins the shell reads. Adding a service is a
/// plugin + `ServiceKind` case; AppState / the status bar do not switch on
/// collectors.
@MainActor
final class QuotaServiceRegistry: ObservableObject {
    private let pluginsByKind: [ServiceKind: any QuotaServicePlugin]
    private var cancellables = Set<AnyCancellable>()

    init(plugins: [any QuotaServicePlugin]? = nil) {
        var map: [ServiceKind: any QuotaServicePlugin] = [:]
        for plugin in plugins ?? Self.makeDefaultPlugins() {
            map[plugin.kind] = plugin
        }
        for kind in ServiceKind.allCases where map[kind] == nil {
            map[kind] = UnimplementedQuotaService(kind: kind)
        }
        self.pluginsByKind = map

        for plugin in map.values {
            plugin.objectWillChange
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }

    /// Plugins in `ServiceKind.allCases` order, one per kind.
    var plugins: [any QuotaServicePlugin] {
        ServiceKind.allCases.map { pluginsByKind[$0]! }
    }

    func plugin(for kind: ServiceKind) -> any QuotaServicePlugin {
        pluginsByKind[kind]!
    }

    func remainingPercent(for kind: ServiceKind) -> Int? {
        plugin(for: kind).reading.remainingPercent
    }

    func startAll() {
        plugins.forEach { $0.start() }
    }

    func stopAll() {
        plugins.forEach { $0.stop() }
    }

    static func makeDefaultPlugins() -> [any QuotaServicePlugin] {
        [
            GPTQuotaStore(),
            KimiQuotaStore(),
            CursorQuotaStore(),
            DeepSeekQuotaStore(),
            UnimplementedQuotaService(kind: .zcode)
        ]
    }
}

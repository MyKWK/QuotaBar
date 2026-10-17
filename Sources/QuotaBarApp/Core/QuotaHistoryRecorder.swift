import Combine
import Foundation

/// Writes successful plugin readings into hourly SQLite buckets.
/// Capture is driven by `QuotaServiceReading.historyPoints`; this type does
/// not switch on `ServiceKind`.
@MainActor
final class QuotaHistoryRecorder: ObservableObject {
    private let store: QuotaHistoryStore
    private var lastUpdatedByService: [ServiceKind: Date] = [:]
    private var cancellables = Set<AnyCancellable>()
    /// Bumped after a successful write so the hourly ledger can reload.
    @Published private(set) var revision: Int = 0

    init(store: QuotaHistoryStore) {
        self.store = store
    }

    func attach(to registry: QuotaServiceRegistry) {
        registry.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self, weak registry] _ in
                guard let self, let registry else { return }
                self.capture(registry.plugins)
            }
            .store(in: &cancellables)
    }

    func detach() {
        cancellables.removeAll()
    }

    func capture(_ plugins: [any QuotaServicePlugin]) {
        var samples: [QuotaHistorySample] = []
        for plugin in plugins {
            guard plugin.isImplemented else { continue }
            let reading = plugin.reading
            guard let updated = reading.lastUpdated,
                  lastUpdatedByService[plugin.kind] != updated,
                  !reading.historyPoints.isEmpty else {
                continue
            }
            lastUpdatedByService[plugin.kind] = updated
            for point in reading.historyPoints {
                samples.append(
                    QuotaHistorySample(
                        service: plugin.kind,
                        metricKey: point.metricKey,
                        remaining: point.remaining,
                        unit: point.unit,
                        isCanonical: point.isCanonical,
                        capturedAt: updated
                    )
                )
            }
        }
        guard !samples.isEmpty else { return }
        do {
            try store.record(samples)
            revision += 1
        } catch {
            AppLog.history.error(
                "Failed to record quota history: \(String(describing: error), privacy: .private)"
            )
        }
    }
}

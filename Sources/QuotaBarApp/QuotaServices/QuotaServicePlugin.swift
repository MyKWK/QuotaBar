import Combine
import Foundation

// MARK: - Quota collection plugin
//
// Display (logo, percent capsule, settings chrome) lives in the shell.
// Fetching, credential files, and payload mapping live in the plugin.
//
// To add a tool: add a `ServiceKind` case + logo, implement this protocol
// (or use `UnimplementedQuotaService` as a stub), and register it in
// `QuotaServiceRegistry`. Percent tools fill `remainingPercent`; prepaid
// balance tools fill `headline` and leave remaining percent nil.

@MainActor
protocol QuotaServicePlugin: AnyObject {
    var kind: ServiceKind { get }
    /// False for stubs such as ZCode: the shell hides refresh and shows the
    /// unimplemented copy instead of a fabricated percentage.
    var isImplemented: Bool { get }
    var reading: QuotaServiceReading { get }
    var isRefreshing: Bool { get }
    var objectWillChange: ObservableObjectPublisher { get }

    func start()
    func stop()
    func refresh()
}

extension QuotaServicePlugin {
    var isImplemented: Bool { true }
}

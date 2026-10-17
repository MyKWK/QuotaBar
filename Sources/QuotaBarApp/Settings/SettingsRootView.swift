import AppKit
import SwiftUI

// MARK: - Settings root
//
// macOS settings-style split view. Sidebar is 通用、流水账, plus one row
// per `ServiceKind`; adding a plugin does not require a new detail switch.

enum SettingsSection: Hashable, Identifiable {
    case general
    case history
    case service(ServiceKind)

    var id: String {
        switch self {
        case .general:
            return "general"
        case .history:
            return "history"
        case .service(let kind):
            return kind.rawValue
        }
    }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .history:
            return "流水账"
        case .service(let kind):
            return kind.displayName
        }
    }

    static var allSections: [SettingsSection] {
        [.general, .history] + ServiceKind.allCases.map(SettingsSection.service)
    }
}

struct SettingsRootView: View {
    @ObservedObject var appState: AppState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var selection: SettingsSection? = .general
    @State private var backdropPrefersDarkInterface: Bool?

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allSections, selection: $selection) { section in
                Label {
                    Text(section.title)
                } icon: {
                    settingsIcon(for: section)
                }
                .tag(section)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 210)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background {
                    if reduceTransparency {
                        Branding.pageBackground
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .containerBackground(for: .window) { Color.clear }
        .background {
            if reduceTransparency {
                Branding.pageBackground
            } else {
                GlassBackdropSampler(prefersDarkInterface: $backdropPrefersDarkInterface)
            }
        }
        .preferredColorScheme(resolvedColorScheme)
        .environment(\.colorScheme, resolvedColorScheme)
    }

    private var resolvedColorScheme: ColorScheme {
        if reduceTransparency {
            return systemColorScheme
        }
        if let prefersDark = backdropPrefersDarkInterface {
            return prefersDark ? .dark : .light
        }
        return systemColorScheme
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .general {
        case .general:
            GeneralSettingsView(appState: appState)
        case .history:
            QuotaHistorySettingsView(
                store: appState.quotaHistoryStore,
                recorder: appState.quotaHistoryRecorder
            )
        case .service(let kind):
            ServiceSettingsView(appState: appState, service: kind)
        }
    }

    @ViewBuilder
    private func settingsIcon(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            Image(systemName: "gearshape")
        case .history:
            Image(systemName: "list.bullet.rectangle")
        case .service(let kind):
            Image(nsImage: ServiceLogoImage.image(
                for: kind,
                size: 32,
                color: TintedTemplateImage.resolvedRGBColor(
                    .labelColor,
                    in: NSAppearance(named: resolvedColorScheme == .dark ? .darkAqua : .aqua)
                )
            ))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 16, height: 16)
            .id(resolvedColorScheme)
        }
    }
}

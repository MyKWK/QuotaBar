import AppKit
import SwiftUI

// MARK: - Shared settings page for every quota plugin
//
// Section order is fixed: obtain/setup → configuration → remaining
// headline and extras → origin. Collector-specific extras (Cursor pool
// picker, Kimi / DeepSeek credentials) are the only type switches.

struct ServiceSettingsView: View {
    @ObservedObject private var registry: QuotaServiceRegistry
    @Environment(\.colorScheme) private var colorScheme
    let service: ServiceKind
    /// Keep origin copy wrapping inside the settings detail column instead of
    /// reporting an unbounded ideal width.
    private static let originReadableWidth: CGFloat = 500

    init(appState: AppState, service: ServiceKind) {
        self._registry = ObservedObject(wrappedValue: appState.quotaServices)
        self.service = service
    }

    private var plugin: any QuotaServicePlugin {
        registry.plugin(for: service)
    }

    private var reading: QuotaServiceReading {
        plugin.reading
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            GlassEffectContainer(spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let setup = reading.setup, setup.hasContent {
                        setupCard(setup)
                    }
                    if let cursor = plugin as? CursorQuotaStore {
                        CursorQuotaPoolPicker(store: cursor)
                    }
                    if let kimi = plugin as? KimiQuotaStore {
                        KimiCredentialsEditor(store: kimi)
                    }
                    if let deepseek = plugin as? DeepSeekQuotaStore {
                        DeepSeekCredentialsEditor(store: deepseek)
                    }
                    quotaCard
                    if let url = reading.externalQuotaURL {
                        externalLinkCard(url: url, title: reading.externalQuotaURLTitle ?? "打开额度页")
                    }
                    if let footnote = reading.footnote, !footnote.isEmpty {
                        Text(footnote)
                            .font(.system(size: 11))
                            .foregroundStyle(Branding.inkSubtle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let origin = reading.origin, !origin.paragraphs.isEmpty {
                        originCard(origin)
                    }
                    Spacer(minLength: 0)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: ServiceLogoImage.image(
                for: service,
                size: 32,
                color: MenuBarContrast.inkColor(in: settingsAppearance)
            ))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 22, height: 22)
                .opacity(0.9)
                .id(colorScheme)

            Text(service.displayName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Branding.inkStrong)
                .glassLegibleInk()

            Spacer()

            if plugin.isImplemented {
                if plugin.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    plugin.refresh()
                } label: {
                    Label("立即刷新", systemImage: "arrow.clockwise")
                }
                .disabled(plugin.isRefreshing)
            }
        }
    }

    private var quotaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reading.metricTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Branding.inkMuted)

                Spacer()

                if let updated = reading.lastUpdated {
                    Text("更新于 \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Branding.inkSubtle)
                }
            }

            if plugin.isImplemented {
                Text(reading.displayedHeadline)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(remainingColor)
            }

            if let caption = reading.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Branding.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !reading.details.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(reading.details.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 8) {
                            Text(row.label)
                                .foregroundStyle(Branding.inkMuted)
                            Spacer()
                            Text(row.value)
                                .monospacedDigit()
                                .foregroundStyle(Branding.ink)
                        }
                        .font(.system(size: 11.5))
                    }
                }
            }

            if let error = reading.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(Branding.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frostedGlassCard()
    }

    private func setupCard(_ setup: QuotaSetupGuide) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 12, weight: .semibold))
                Text(setup.title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Branding.inkMuted)

            if !setup.actions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(setup.actions) { action in
                        Button {
                            NSWorkspace.shared.open(action.url)
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                        .buttonStyle(.link)
                    }
                }
            }

            ForEach(Array(setup.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: 11))
                    .foregroundStyle(Branding.inkSubtle)
                    .frame(maxWidth: Self.originReadableWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frostedGlassCard()
    }

    private func originCard(_ origin: QuotaBalanceOrigin) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .semibold))
                Text(origin.title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Branding.inkMuted)

            ForEach(Array(origin.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: 11))
                    .foregroundStyle(Branding.inkSubtle)
                    .frame(maxWidth: Self.originReadableWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let current = origin.currentReading, !current.isEmpty {
                Text(current)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Branding.ink)
                    .frame(maxWidth: Self.originReadableWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frostedGlassCard()
    }

    private func externalLinkCard(url: URL, title: String) -> some View {
        HStack(spacing: 10) {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label(title, systemImage: "safari")
            }
            .buttonStyle(.link)
            Spacer()
        }
        .frostedGlassCard()
    }

    private var remainingColor: Color {
        if let remaining = reading.remainingPercent {
            if remaining <= 0 { return Branding.danger }
            if remaining <= StatusBarServicesPresenter.lowRemainingThresholdPercent { return Branding.warning }
            return Branding.inkStrong
        }
        switch reading.warningLevel {
        case .exhausted:
            return Branding.danger
        case .low:
            return Branding.warning
        case .normal:
            return Branding.inkStrong
        case nil:
            return reading.hasLiveHeadline ? Branding.inkStrong : Branding.inkSubtle
        }
    }

    private var settingsAppearance: NSAppearance {
        NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua) ?? NSApp.effectiveAppearance
    }
}

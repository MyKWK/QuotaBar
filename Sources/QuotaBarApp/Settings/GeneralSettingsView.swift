import SwiftUI

// MARK: - General settings page
//
// Capsule toggles (GPT / Kimi / Cursor / DeepSeek / ZCode). Each enabled
// service adds one single-line "Logo + 额度" capsule to the menu bar.

struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            GlassEffectContainer(spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("通用")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Branding.inkStrong)
                        .glassLegibleInk()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("状态栏显示")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Branding.inkMuted)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 118), spacing: 10, alignment: .leading)],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(ServiceKind.menuBarOrder) { service in
                                ServiceCapsuleToggle(
                                    service: service,
                                    isOn: appState.isServiceVisibleInMenuBar(service)
                                ) {
                                    appState.setServiceVisibleInMenuBar(
                                        service,
                                        !appState.isServiceVisibleInMenuBar(service)
                                    )
                                }
                            }
                        }

                        Text("每开启一项，顶部状态栏会多显示一个「Logo + 额度」胶囊。会员类服务显示剩余百分比，DeepSeek 显示账户余额。点击任一状态栏项目即可打开本窗口。")
                            .font(.system(size: 11))
                            .foregroundStyle(Branding.inkMuted)
                            .glassLegibleInk()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frostedGlassCard()

                    Spacer(minLength: 0)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct ServiceCapsuleToggle: View {
    let service: ServiceKind
    let isOn: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                let appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
                Image(nsImage: ServiceLogoImage.image(
                    for: service,
                    size: 26,
                    color: TintedTemplateImage.resolvedRGBColor(
                        isOn ? NSColor(Branding.accentBlueDark) : .secondaryLabelColor,
                        in: appearance
                    )
                ))
                .frame(width: 13, height: 13)

                Text(service.displayName)
                    .font(.system(size: 12.5, weight: isOn ? .semibold : .medium))
                    .foregroundStyle(isOn ? Branding.accentBlueDark : Branding.inkMuted)

                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Branding.accentBlueDark)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(
                Capsule(style: .continuous)
                    .fill(isOn ? Branding.accentBlueSoft : Branding.chipSurface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isOn ? Branding.borderSelected : Branding.controlStroke, lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .help(isOn ? "在状态栏隐藏 \(service.displayName)" : "在状态栏显示 \(service.displayName)")
        .accessibilityLabel(service.displayName)
        .accessibilityValue(isOn ? "已开启" : "已关闭")
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}

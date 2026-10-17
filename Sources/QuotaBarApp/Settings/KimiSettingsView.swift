import AppKit
import SwiftUI

// MARK: - Kimi credential editor
//
// Plugin-specific accessory on the shared `ServiceSettingsView`. Status shows
// only whether a token is stored — never the token itself.

struct KimiCredentialsEditor: View {
    @ObservedObject var store: KimiQuotaStore

    @State private var accessTokenInput = ""
    @State private var refreshTokenInput = ""
    @State private var feedback: Feedback?

    private enum Feedback {
        case error(String)
        case saved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("配置凭据")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Branding.inkMuted)

            HStack(spacing: 6) {
                Image(systemName: hasAnyCredential ? "checkmark.shield" : "shield")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(hasAnyCredential ? Branding.success : Branding.inkSubtle)
                Text(credentialStatusText)
                    .font(.system(size: 11))
                    .foregroundStyle(Branding.inkSubtle)
            }

            Text("请先从上方打开 Kimi 获取 access_token。支持标准 ⌘V 粘贴。凭据仅保存在本机，不会回显。")
                .font(.system(size: 10.5))
                .foregroundStyle(Branding.inkSubtle)
                .fixedSize(horizontal: false, vertical: true)

            credentialField(
                label: "access_token",
                placeholder: "可选；留空则保持现有值",
                text: $accessTokenInput
            )
            credentialField(
                label: "refresh_token",
                placeholder: "建议填写；用于 access_token 自动续期",
                text: $refreshTokenInput
            )

            HStack(spacing: 10) {
                Button("保存凭据") {
                    save()
                }
                .disabled(accessTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && refreshTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if hasAnyCredential {
                    Button("清除凭据", role: .destructive) {
                        clear()
                    }
                }

                Spacer()

                switch feedback {
                case .error(let message):
                    Text(message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Branding.danger)
                        .lineLimit(2)
                case .saved:
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Branding.success)
                case nil:
                    EmptyView()
                }
            }
        }
        .frostedGlassCard()
    }

    private var hasAnyCredential: Bool {
        store.hasAccessToken || store.hasRefreshToken
    }

    private var credentialStatusText: String {
        var parts: [String] = []
        parts.append(store.hasAccessToken ? "access_token 已保存" : "access_token 未设置")
        parts.append(store.hasRefreshToken ? "refresh_token 已保存" : "refresh_token 未设置")
        return parts.joined(separator: " · ")
    }

    private func credentialField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Branding.inkMuted)

            HStack(spacing: 8) {
                PasteEnabledSecureField(placeholder: placeholder, text: text)
                    .frame(height: 22)

                Button("粘贴") {
                    guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
                        NSSound.beep()
                        return
                    }
                    text.wrappedValue = value
                }
                .controlSize(.small)
            }
        }
    }

    private func save() {
        if let error = store.setCredentials(accessToken: accessTokenInput, refreshToken: refreshTokenInput) {
            feedback = .error(error)
        } else {
            accessTokenInput = ""
            refreshTokenInput = ""
            feedback = .saved
        }
    }

    private func clear() {
        if let error = store.clearCredentials() {
            feedback = .error(error)
        } else {
            feedback = nil
        }
    }
}

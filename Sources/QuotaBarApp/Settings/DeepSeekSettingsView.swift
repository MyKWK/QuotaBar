import AppKit
import SwiftUI

// MARK: - DeepSeek API key editor
//
// Plugin-specific accessory on the shared `ServiceSettingsView`. Status shows
// whether a source is configured — never the key itself.

struct DeepSeekCredentialsEditor: View {
    @ObservedObject var store: DeepSeekQuotaStore

    @State private var source: DeepSeekKeySource = .environmentVariable
    @State private var environmentVariableName = ""
    @State private var apiKeyInput = ""
    @State private var feedback: Feedback?
    private static let readableWidth: CGFloat = 500

    private enum Feedback {
        case error(String)
        case saved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("配置 API Key")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Branding.inkMuted)

            HStack(spacing: 6) {
                Image(systemName: store.hasConfiguration ? "checkmark.shield" : "shield")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.hasConfiguration ? Branding.success : Branding.inkSubtle)
                Text(credentialStatusText)
                    .font(.system(size: 11))
                    .foregroundStyle(Branding.inkSubtle)
                    .lineLimit(2)
            }

            privacyNote

            Picker("配置方式", selection: $source) {
                ForEach(DeepSeekKeySource.allCases) { option in
                    Text(option.pickerTitle).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch source {
            case .environmentVariable:
                VStack(alignment: .leading, spacing: 4) {
                    Text("环境变量名")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Branding.inkMuted)
                    PasteEnabledPlainField(placeholder: "例如 DEEPSEEK_API_KEY", text: $environmentVariableName)
                        .frame(height: 22)
                }
                Text("QuotaBar 只读取当前进程环境里这个名字对应的值，不会把 Key 写入凭据文件。从「应用程序」启动时通常读不到终端 ~/.zshrc 里的变量；若读不到请改用直接粘贴，或从终端启动。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Branding.inkSubtle)
                    .frame(maxWidth: Self.readableWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            case .storedKey:
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Branding.inkMuted)
                    HStack(spacing: 8) {
                        PasteEnabledSecureField(placeholder: "sk-…，支持 ⌘V 粘贴", text: $apiKeyInput)
                            .frame(height: 22)
                        Button("粘贴") {
                            guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
                                NSSound.beep()
                                return
                            }
                            apiKeyInput = value
                        }
                        .controlSize(.small)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("保存配置") {
                    save()
                }
                .disabled(!canSave)

                if store.hasConfiguration {
                    Button("清除配置", role: .destructive) {
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
                        .frame(maxWidth: 280, alignment: .trailing)
                case .saved:
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Branding.success)
                case nil:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: Self.readableWidth, alignment: .leading)
        .frostedGlassCard()
        .onAppear {
            source = store.keySource
            environmentVariableName = store.configuredEnvironmentVariableName ?? ""
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lock.shield")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Branding.success)
                .padding(.top, 1)
            Text("QuotaBar 只做本机展示。粘贴的 Key 保存在本机 \(localCredentialsPath)（权限 0600），查询余额时只发给 DeepSeek 官方接口。没有对外的数据上报，也没有 QuotaBar 自己的云端，可以放心复制粘贴。")
                .font(.system(size: 10.5))
                .foregroundStyle(Branding.inkSubtle)
                .frame(maxWidth: Self.readableWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var localCredentialsPath: String {
        let path = AppPaths.credentialsFile.path
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private var credentialStatusText: String {
        if store.hasStoredAPIKey {
            return "已在本机保存 API Key（不会回显）"
        }
        if let name = store.configuredEnvironmentVariableName {
            return "已配置环境变量 \(name)"
        }
        return "尚未配置 API Key"
    }

    private var canSave: Bool {
        switch source {
        case .environmentVariable:
            return DeepSeekAPIKeyResolver.normalizedEnvironmentVariableName(environmentVariableName) != nil
        case .storedKey:
            return DeepSeekAPIKeyResolver.normalizedAPIKey(apiKeyInput) != nil
        }
    }

    private func save() {
        let error: String?
        switch source {
        case .environmentVariable:
            error = store.setEnvironmentVariableName(environmentVariableName)
        case .storedKey:
            error = store.setStoredAPIKey(apiKeyInput)
        }
        if let error {
            feedback = .error(error)
        } else {
            apiKeyInput = ""
            feedback = .saved
        }
    }

    private func clear() {
        if let error = store.clearCredentials() {
            feedback = .error(error)
        } else {
            apiKeyInput = ""
            feedback = nil
        }
    }
}

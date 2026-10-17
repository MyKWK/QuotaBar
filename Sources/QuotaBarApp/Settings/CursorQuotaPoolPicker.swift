import SwiftUI

// MARK: - Cursor pool picker
//
// Lets the user choose which included-usage bar the capsule mirrors:
// internal Cursor Models, or external Other Models.

struct CursorQuotaPoolPicker: View {
    @ObservedObject var store: CursorQuotaStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("配置设置")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Branding.inkMuted)

            Picker("展示额度", selection: $store.selectedPool) {
                ForEach(CursorQuotaPool.allCases) { pool in
                    Text(pool.displayName).tag(pool)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("内部额度对应 Cursor Models（Grok / Composer），外部额度对应 Other Models（第三方模型）。")
                .font(.system(size: 10.5))
                .foregroundStyle(Branding.inkSubtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frostedGlassCard()
    }
}

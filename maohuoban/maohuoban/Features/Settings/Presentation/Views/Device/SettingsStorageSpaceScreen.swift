import SwiftUI
import MaohuobanDesignSystem

// SettingsStorageSpaceScreen 存储空间页面
// 核心职责：
// - 展示设备和 App 沙盒存储占用
// - 提供清理缓存的 mock 可执行入口
struct SettingsStorageSpaceScreen: View {
    @State private var snapshot: SettingsStorageCalculator.StorageSnapshot?
    @State private var isClearing = false

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsStorageOverviewCard(snapshot: snapshot)

                SettingsSection {
                    SettingsRow(title: "缓存", value: snapshot?.appCaches.settingsStorageFormatted ?? "计算中...", showChevron: false)
                    SettingsDivider()
                    SettingsRow(title: "文稿与数据", value: snapshot?.appDocuments.settingsStorageFormatted ?? "计算中...", showChevron: false)
                    SettingsDivider()
                    SettingsRow(title: "临时文件", value: snapshot?.appTemporary.settingsStorageFormatted ?? "计算中...", showChevron: false)
                }

                Button(action: clearCaches) {
                    Text(isClearing ? "清理中..." : "清理缓存")
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(MHBTheme.ColorToken.primary.color)
                        .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
                }
                .disabled(isClearing)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("存储空间")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            snapshot = await SettingsStorageCalculator.calculate()
        }
    }

    private func clearCaches() {
        guard isClearing == false else { return }
        isClearing = true
        Task {
            snapshot = await SettingsStorageCalculator.clearCaches()
            isClearing = false
        }
    }
}

// SettingsStorageOverviewCard 存储空间概览卡片
// 核心职责：
// - 展示毛伙伴 App 总占用量和比例
struct SettingsStorageOverviewCard: View {
    let snapshot: SettingsStorageCalculator.StorageSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("毛伙伴占用")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text(snapshot?.appTotal.settingsStorageFormatted ?? "计算中...")
                .font(MHBTheme.Typography.largeTitle)
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
            Text("约占设备容量 \(snapshot?.appPercentageText ?? "--")")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s5)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(.rect(cornerRadius: MHBTheme.Radius.extraLarge))
    }
}

import SwiftUI
import MaohuobanDesignSystem

// PetWalkCompletionScreen 遛弯结束保存页
// 核心职责：
// - 展示本次遛弯结束摘要和保存选项
// - 承载 fullScreenCover 内的保存操作
struct PetWalkCompletionScreen: View {
    let summary: PetWalkCompletionSummary
    let onSave: () -> Void

    @State private var title: String
    @State private var recordsToProfile = true
    @State private var syncsToCityFeed = false

    init(
        summary: PetWalkCompletionSummary,
        onSave: @escaping () -> Void
    ) {
        self.summary = summary
        self.onSave = onSave
        self._title = State(initialValue: summary.defaultTitle)
    }

    var body: some View {
        NavigationStack {
            MHBScreenScrollView {
                VStack(spacing: MHBTheme.Spacing.s5) {
                    PetWalkCompletionSuccessHeader(summary: summary)

                    PetWalkCompletionTitleEditor(title: $title)

                    PetWalkCompletionPreviewCard(summary: summary)

                    PetWalkCompletionSettingsCard(
                        petName: summary.displayPetName,
                        recordsToProfile: $recordsToProfile,
                        syncsToCityFeed: $syncsToCityFeed
                    )
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.top, MHBTheme.Spacing.s5)
                .padding(.bottom, MHBTheme.Spacing.s8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("结束遛弯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", action: onSave)
                        .font(MHBTheme.Typography.headline)
                }
            }
        }
        .accessibilityIdentifier("pet.walkCompletion.screen")
    }
}

// PetWalkCompletionSuccessHeader 遛弯完成头部
// 核心职责：
// - 展示宠物头像完成态
// - 展示本次消耗热量摘要
private struct PetWalkCompletionSuccessHeader: View {
    let summary: PetWalkCompletionSummary

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            PetWalkCompletionAvatar(
                petName: summary.displayPetName,
                url: summary.petAvatarURL,
                petSex: summary.petSex
            )

            VStack(spacing: MHBTheme.Spacing.s2) {
                Text("遛弯完成！")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("\(summary.displayPetName)今天消耗了 \(summary.caloriesText)热量")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// PetWalkCompletionAvatar 遛弯完成头像
// 核心职责：
// - 展示宠物头像
// - 通过遮罩和勾选图标表达完成状态
private struct PetWalkCompletionAvatar: View {
    let petName: String
    let url: URL?
    let petSex: PetRecordPetSex

    private let size: CGFloat = 72

    var body: some View {
        MHBAvatar(
            subject: PetWalkAvatarPresentation.avatarSubject(
                id: "walk-completion-pet",
                name: petName,
                url: url,
                sex: petSex
            ),
            size: .custom(size),
            shape: .circle
        )
        .overlay {
            Circle()
                .fill(Color.black.opacity(0.28))
        }
        .overlay {
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
        }
        .shadow(color: MHBTheme.ColorToken.success.color.opacity(0.24), radius: 16, x: 0, y: 6)
    }
}

// PetWalkCompletionTitleEditor 遛弯标题编辑器
// 核心职责：
// - 提供结束记录标题输入
// - 保持输入区域卡片化展示
private struct PetWalkCompletionTitleEditor: View {
    @Binding var title: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            TextField("给这次遛弯起个标题", text: $title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)

            Image(systemName: "pencil")
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color, in: .rect(cornerRadius: 20))
        .accessibilityIdentifier("pet.walkCompletion.titleEditor")
    }
}

// PetWalkCompletionPreviewCard 遛弯路线和数据卡片
// 核心职责：
// - 展示路线缩略预览
// - 展示距离、时长和千卡指标
private struct PetWalkCompletionPreviewCard: View {
    let summary: PetWalkCompletionSummary

    var body: some View {
        HStack(spacing: 0) {
            PetWalkCompletionRoutePreview(points: summary.routePoints)
                .frame(width: 124)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(summary.distanceValueText)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)

                    Text("总里程 (KM)")
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }

                HStack(alignment: .top, spacing: MHBTheme.Spacing.s5) {
                    PetWalkCompletionMetricValue(
                        value: summary.elapsedText,
                        title: "时长"
                    )

                    PetWalkCompletionMetricValue(
                        value: summary.caloriesValueText,
                        title: "千卡"
                    )
                }
            }
            .padding(MHBTheme.Spacing.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 164)
        .background(MHBTheme.ColorToken.cardSolid.color, in: .rect(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityIdentifier("pet.walkCompletion.previewCard")
    }
}

// PetWalkCompletionMetricValue 遛弯结束指标项
// 核心职责：
// - 展示单个结束页指标
// - 保持数字宽度稳定
private struct PetWalkCompletionMetricValue: View {
    let value: String
    let title: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(value)
                .font(MHBTheme.Typography.title.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
    }
}

// PetWalkCompletionSettingsCard 遛弯保存选项卡片
// 核心职责：
// - 展示保存到档案和同步动态开关
// - 保持本期仅前端状态切换
private struct PetWalkCompletionSettingsCard: View {
    let petName: String
    @Binding var recordsToProfile: Bool
    @Binding var syncsToCityFeed: Bool

    var body: some View {
        VStack(spacing: 0) {
            PetWalkCompletionSettingsRow(
                systemImage: "folder.badge.plus",
                iconColor: MHBTheme.ColorToken.success.color,
                title: "记入宠物档案",
                subtitle: "将里程和时长同步至\(petName)的健康数据统计中。",
                isOn: $recordsToProfile
            )

            Divider()
                .padding(.leading, 20)

            PetWalkCompletionSettingsRow(
                systemImage: "globe.asia.australia.fill",
                iconColor: MHBTheme.ColorToken.primary.color,
                title: "同步至同城动态",
                subtitle: "开启后，可添加图文并将路线分享给同城宠友。",
                isOn: $syncsToCityFeed
            )
        }
        .background(MHBTheme.ColorToken.cardSolid.color, in: .rect(cornerRadius: 20))
        .accessibilityIdentifier("pet.walkCompletion.settingsCard")
    }
}

// PetWalkCompletionSettingsRow 遛弯保存设置行
// 核心职责：
// - 展示单个保存选项
// - 承载原生 Toggle 交互
private struct PetWalkCompletionSettingsRow: View {
    let systemImage: String
    let iconColor: Color
    let title: LocalizedStringResource
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                Image(systemName: systemImage)
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(title)
                        .font(MHBTheme.Typography.callout.weight(.bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(subtitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}

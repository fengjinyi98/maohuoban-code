import SwiftUI
import MaohuobanDesignSystem

// PublishSelectionOption 发布配置候选项
// 核心职责：
// - 为宠物、可见范围等本地选项提供统一展示字段
struct PublishSelectionOption: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let city: String?

    init(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        city: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.city = city
    }
}

// PublishPetSelectionSheet 发布宠物选择弹层
// 核心职责：
// - 提供图文发布首版本地宠物候选
struct PublishPetSelectionSheet: View {
    let selectedPetID: String?
    let onSelect: (PublishSelectionOption) -> Void

    var body: some View {
        PublishSelectionSheet(
            title: "关联宠物",
            options: PublishMockOptions.petOptions,
            selectedID: selectedPetID,
            onSelect: onSelect
        )
    }
}

// PublishEventTypeSelectionSheet 发布事件类型弹层
// 核心职责：
// - 提供图文发布事件类型候选
struct PublishEventTypeSelectionSheet: View {
    let selectedEventType: PublishEventType
    let onSelect: (PublishEventType) -> Void

    var body: some View {
        PublishSelectionSheet(
            title: "事件类型",
            options: PublishEventType.allCases.map {
                PublishSelectionOption(
                    id: $0.rawValue,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    systemImage: $0.systemImage
                )
            },
            selectedID: selectedEventType.rawValue,
            onSelect: { option in
                guard let eventType = PublishEventType(rawValue: option.id) else {
                    return
                }
                onSelect(eventType)
            }
        )
    }
}

// PublishVisibilitySelectionSheet 发布可见范围弹层
// 核心职责：
// - 提供发布隐私范围候选
struct PublishVisibilitySelectionSheet: View {
    let selectedVisibility: PublishVisibility
    let onSelect: (PublishVisibility) -> Void

    var body: some View {
        PublishSelectionSheet(
            title: "可见范围",
            options: PublishVisibility.allCases.map {
                PublishSelectionOption(
                    id: $0.rawValue,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    systemImage: $0.systemImage
                )
            },
            selectedID: selectedVisibility.rawValue,
            onSelect: { option in
                guard let visibility = PublishVisibility(rawValue: option.id) else {
                    return
                }
                onSelect(visibility)
            }
        )
    }
}

// PublishAlbumSelectionSheet 发布相册选择弹层
// 核心职责：
// - 提供图文发布选择同步相册的候选
struct PublishAlbumSelectionSheet: View {
    let selectedAlbumTitle: String?
    let onSelect: (PublishSelectionOption) -> Void

    var body: some View {
        PublishSelectionSheet(
            title: "同步存入宠物相册",
            options: PublishMockOptions.albumOptions,
            selectedID: selectedAlbumTitle,
            onSelect: onSelect
        )
    }
}

// PublishSelectionSheet 发布候选选择弹层
// 核心职责：
// - 统一渲染发布配置项的本地候选列表
private struct PublishSelectionSheet: View {
    let title: String
    let options: [PublishSelectionOption]
    let selectedID: String?
    let onSelect: (PublishSelectionOption) -> Void

    @State private var contentHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)
                .padding(.top, MHBTheme.Spacing.s4)
                .padding(.bottom, MHBTheme.Spacing.s3)

            PublishSelectionGroup {
                ForEach(options) { option in
                    PublishSelectionRow(
                        option: option,
                        isSelected: selectedID == option.id || selectedID == option.title,
                        showsSeparator: option.id != options.last?.id,
                        onSelect: { onSelect(option) }
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { contentProxy in
                Color.clear
                    .onAppear {
                        contentHeight = contentProxy.size.height
                    }
                    .onChange(of: contentProxy.size) { _, newSize in
                        contentHeight = newSize.height
                    }
            }
        }
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
        .presentationDetents([.height(contentHeight)])
    }
}

// PublishSelectionGroup 发布选择分组容器
// 核心职责：
// - 承载发布选择项的原生分组表面
// - 复用宠物编辑档案的分组背景与圆角规则
private struct PublishSelectionGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// PublishSelectionRow 发布选择分组行
// 核心职责：
// - 展示发布选择项标题、副标题和选中状态
// - 保持 iOS 原生分组列表的行距、图标列和分割线
private struct PublishSelectionRow: View {
    let option: PublishSelectionOption
    let isSelected: Bool
    let showsSeparator: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.title)
                            .font(MHBTheme.Typography.body)
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(option.subtitle)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(MHBTheme.ColorToken.primary.color)
                            .frame(width: 20, alignment: .trailing)
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.vertical, MHBTheme.Spacing.s3)
                .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                .contentShape(Rectangle())

                if showsSeparator {
                    Rectangle()
                        .fill(MHBTheme.ColorToken.separatorSoft.color)
                        .frame(height: 0.5)
                        .padding(.leading, MHBTheme.Spacing.s4 + 24 + MHBTheme.Spacing.s3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// PublishMockOptions 发布页本地候选数据
// 核心职责：
// - 为前端 UI 阶段提供宠物和相册候选
private enum PublishMockOptions {
    static let petOptions: [PublishSelectionOption] = [
        PublishSelectionOption(
            id: "pet-nuomi",
            title: "糯米",
            subtitle: "比熊 · 2岁 · 当前常用宠物",
            systemImage: "pawprint.fill"
        ),
        PublishSelectionOption(
            id: "pet-naigai",
            title: "奶盖",
            subtitle: "布偶猫 · 8个月 · 适合成长记录",
            systemImage: "cat.fill"
        ),
        PublishSelectionOption(
            id: "pet-buding",
            title: "布丁",
            subtitle: "柯基 · 3岁 · 同城活动常用",
            systemImage: "dog.fill"
        )
    ]

    static let albumOptions: [PublishSelectionOption] = [
        PublishSelectionOption(
            id: "album-daily",
            title: "日常相册",
            subtitle: "默认存储日常瞬间",
            systemImage: "photo.on.rectangle"
        ),
        PublishSelectionOption(
            id: "album-growth",
            title: "成长记录",
            subtitle: "存储身长、体重等成长点滴",
            systemImage: "waveform.path.ecg"
        ),
        PublishSelectionOption(
            id: "album-medical",
            title: "医疗相册",
            subtitle: "同步存储病历和诊断快照",
            systemImage: "stethoscope"
        )
    ]
}

import SwiftUI
import MaohuobanDesignSystem

// PetEventDetailScreen 宠物事件详情页
// 核心职责：
// - 展示宠物事件账本中的单条事件
// - 通过 PetEventDetailStore 加载当前用户可访问的事件详情
struct PetEventDetailScreen: View {
    let eventID: String
    let currentUserID: String?

    @State private var store = PetEventDetailStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                switch store.phase {
                case .idle, .loading:
                    PetEventDetailLoadingSection()
                case .loaded(let event):
                    PetEventDetailLoadedView(event: event)
                case .failed(let message):
                    PetEventDetailFailedSection(message: message)
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("事件详情")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: taskID) {
            await store.load(eventID: eventID, currentUserID: currentUserID)
        }
        .accessibilityIdentifier("pet.eventDetail.screen")
    }

    private var taskID: String {
        "\(eventID)-\(currentUserID ?? "anonymous")"
    }
}

// PetEventDetailLoadedView 宠物事件详情成功态
// 核心职责：
// - 组合事件详情各展示 section
// - 保持父视图只承担状态分发
private struct PetEventDetailLoadedView: View {
    let event: PetEventDetail

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            PetEventDetailHeaderSection(event: event)
            PetEventDetailBodySection(event: event)
            PetEventDetailMetaSection(event: event)
        }
    }
}

// PetEventDetailLoadingSection 事件详情加载态
// 核心职责：
// - 展示事件详情加载过程
// - 稳定首屏布局和可访问标识
private struct PetEventDetailLoadingSection: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在加载事件详情")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(MHBTheme.Spacing.s6)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("pet.eventDetail.loading")
    }
}

// PetEventDetailFailedSection 事件详情失败态
// 核心职责：
// - 展示加载失败原因
// - 保持错误反馈在页面内容区内呈现
private struct PetEventDetailFailedSection: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)
            Text("暂时无法加载事件详情")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("pet.eventDetail.failed")
    }
}

// PetEventDetailHeaderSection 事件详情头部
// 核心职责：
// - 展示事件标题、类型和发生时间
// - 让用户确认进入的是哪条账本记录
private struct PetEventDetailHeaderSection: View {
    let event: PetEventDetail

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: event.systemImage)
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)
                .background(MHBTheme.ColorToken.primaryBackground.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(event.title)
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text("\(String(localized: event.kind.displayTitle)) · \(event.occurredAt)")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
        )
        .accessibilityIdentifier("pet.eventDetail.header")
    }
}

// PetEventDetailBodySection 事件正文模块
// 核心职责：
// - 展示事件摘要
// - 保持空摘要时的明确反馈
private struct PetEventDetailBodySection: View {
    let event: PetEventDetail

    var body: some View {
        PetEventDetailSectionCard(title: "记录内容") {
            Text(summaryText)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
    }

    private var summaryText: String {
        guard let summary = event.summary, !summary.isEmpty else {
            return "暂无补充内容"
        }
        return summary
    }
}

// PetEventDetailMetaSection 事件元信息模块
// 核心职责：
// - 展示事件可见范围、版本和归属线索
// - 为后续审计与证据快照入口保留结构
private struct PetEventDetailMetaSection: View {
    let event: PetEventDetail

    var body: some View {
        PetEventDetailSectionCard(title: "账本信息") {
            VStack(spacing: MHBTheme.Spacing.s2) {
                PetEventDetailMetaRow(title: "可见范围", value: String(localized: event.visibility.displayTitle))
                PetEventDetailMetaRow(title: "记录版本", value: "第 \(event.recordRevision) 版")
                if let petID = event.petID {
                    PetEventDetailMetaRow(title: "宠物 ID", value: petID)
                }
                if let litterID = event.litterID {
                    PetEventDetailMetaRow(title: "窝次 ID", value: litterID)
                }
            }
        }
    }
}

// PetEventDetailSectionCard 事件详情分组容器
// 核心职责：
// - 统一事件详情分组标题和卡片样式
// - 复用 DesignSystem token 控制视觉一致性
private struct PetEventDetailSectionCard<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// PetEventDetailMetaRow 事件元信息行
// 核心职责：
// - 展示单项账本元信息
// - 保持标签和值的可扫描布局
private struct PetEventDetailMetaRow: View {
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(width: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6, alignment: .leading)
            Text(value)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

private extension PetEventDetail {
    var systemImage: String {
        switch kind {
        case .daily: "sparkles"
        case .health: "cross.case.fill"
        case .merchant: "storefront.fill"
        case .trade: "doc.text.fill"
        case .memorial: "heart.fill"
        }
    }
}

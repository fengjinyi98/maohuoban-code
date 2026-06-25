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
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                switch store.phase {
                case .idle, .loading:
                    PetEventDetailLoadingSection()
                case .loaded(let event):
                    PetEventDetailLoadedView(event: event)
                case .failed(let message):
                    PetEventDetailFailedSection(message: message)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("事件详情")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: taskID) {
            store.phase = .loaded(PetEventDetailMockData.detail(for: eventID))
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
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            PetEventDetailReceiptCard(presentation: PetEventDetailPresentation(event: event))
            PetEventDetailActions()
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

// PetEventDetailReceiptCard 事件详情小票卡片
// 核心职责：
// - 按设计稿展示事件图标、标题、发生时间和关键字段
// - 让时间线单条记录详情保持轻量可读
private struct PetEventDetailReceiptCard: View {
    let presentation: PetEventDetailPresentation

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(presentation.tint)
                .frame(width: 64, height: 64)
                .background(presentation.tint.opacity(0.10))
                .clipShape(Circle())
                .padding(.bottom, MHBTheme.Spacing.s5)

            Text(presentation.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.center)
                .padding(.bottom, MHBTheme.Spacing.s2)

            Text(presentation.timeText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
                .padding(.bottom, MHBTheme.Spacing.s8)

            PetEventDetailDashedDivider()
                .padding(.bottom, MHBTheme.Spacing.s5)

            VStack(spacing: 0) {
                ForEach(presentation.rows) { row in
                    PetEventDetailReceiptRow(row: row)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .padding(.vertical, MHBTheme.Spacing.s8)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 12, y: 4)
        .accessibilityIdentifier("pet.eventDetail.receiptCard")
    }
}

// PetEventDetailReceiptRow 事件详情小票字段行
// 核心职责：
// - 展示单个字段和值
// - 保持小票卡片内字段左右对齐
private struct PetEventDetailReceiptRow: View {
    let row: PetEventDetailPresentation.Row

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
            Text(row.title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s4)

            PetEventDetailReceiptRowValue(value: row.value)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}

// PetEventDetailReceiptRowValue 事件详情小票字段值
// 核心职责：
// - 根据字段值类型渲染普通文本或宠物身份
// - 复用头像基础设施展示宠物头像
private struct PetEventDetailReceiptRowValue: View {
    let value: PetEventDetailPresentation.RowValue

    var body: some View {
        switch value {
        case .text(let text):
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
        case .pet(let pet):
            HStack(spacing: MHBTheme.Spacing.s2) {
                MHBAvatar(
                    subject: .pet(
                        MHBAvatarPet(
                            id: pet.id,
                            name: pet.name,
                            source: pet.avatarSource,
                            species: .other,
                            sex: .unknown
                        )
                    ),
                    size: .custom(28),
                    shape: .circle
                )

                Text(pet.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
            }
        }
    }
}

// PetEventDetailDashedDivider 事件详情虚线分隔
// 核心职责：
// - 承载小票样式的字段区分隔线
// - 避免引入 UIKit 或图片资源
private struct PetEventDetailDashedDivider: View {
    var body: some View {
        Line()
            .stroke(
                MHBTheme.ColorToken.separator.color,
                style: StrokeStyle(lineWidth: 1, dash: [5, 5])
            )
            .frame(height: 1)
    }

    private struct Line: Shape {
        nonisolated func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

// PetEventDetailActions 事件详情底部操作
// 核心职责：
// - 提供修改记录和删除记录入口
// - 保持与设计稿底部操作布局一致
private struct PetEventDetailActions: View {
    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Button("修改记录信息") {}
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(MHBTheme.ColorToken.separatorSoft.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .buttonStyle(.plain)

            Button(role: .destructive) {} label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.danger.color)
                    .frame(width: 48, height: 48)
                    .background(MHBTheme.ColorToken.danger.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .accessibilityIdentifier("pet.eventDetail.actions")
    }
}

// PetEventDetailPresentation 事件详情展示模型
// 核心职责：
// - 将接口或 mock 事件转换为详情页小票展示数据
// - 隔离事件类型判断与 SwiftUI 视图渲染
private struct PetEventDetailPresentation {
    struct PetIdentity: Equatable {
        let id: String
        let name: String
        let avatarSource: MHBAvatarSource
    }

    enum RowValue: Equatable {
        case text(String)
        case pet(PetIdentity)
    }

    struct Row: Identifiable {
        let id: String
        let title: String
        let value: RowValue

        init(id: String, title: String, text: String) {
            self.id = id
            self.title = title
            self.value = .text(text)
        }

        init(id: String, title: String, pet: PetIdentity) {
            self.id = id
            self.title = title
            self.value = .pet(pet)
        }
    }

    let title: String
    let timeText: String
    let systemImage: String
    let tint: Color
    let rows: [Row]

    init(event: PetEventDetail) {
        self.title = event.receiptTitle
        self.timeText = event.occurredAt.eventDetailDisplayTime
        self.systemImage = event.systemImage
        self.tint = event.tint
        self.rows = event.receiptRows
    }
}

// PetEventDetailMockData 首页时间线详情 mock 数据
// 核心职责：
// - 为首页 mock 时间线事件提供可直接预览的详情数据
// - 避免快速 UI 阶段被后端数据缺失阻塞
private enum PetEventDetailMockData {
    static func detail(for eventID: String) -> PetEventDetail {
        switch eventID {
        case "event-breakfast":
            return PetEventDetail(
                id: eventID,
                petID: mockPetName,
                litterID: nil,
                kind: .daily,
                subkind: "feeding",
                title: "已喂食",
                summary: "渴望原味六种鱼 · 50g",
                visibility: .private,
                occurredAt: "2026年6月25日 10:30",
                recordRevision: 1
            )
        case "event-weight":
            return PetEventDetail(
                id: eventID,
                petID: mockPetName,
                litterID: nil,
                kind: .health,
                subkind: "weight",
                title: "体重更新",
                summary: "3.6 kg · 较上次 +0.2 kg",
                visibility: .private,
                occurredAt: "2026年6月25日 09:15",
                recordRevision: 1
            )
        case "event-deworming":
            return PetEventDetail(
                id: eventID,
                petID: mockPetName,
                litterID: nil,
                kind: .health,
                subkind: "deworming",
                title: "完成驱虫",
                summary: "大宠爱体外驱虫滴剂",
                visibility: .private,
                occurredAt: "2026年6月25日 11:30",
                recordRevision: 1
            )
        case "event-walk":
            return PetEventDetail(
                id: eventID,
                petID: mockPetName,
                litterID: nil,
                kind: .daily,
                subkind: "walk",
                title: "夜间散步",
                summary: "32 分钟 · 2.3 km",
                visibility: .private,
                occurredAt: "2026年6月25日 20:20",
                recordRevision: 1
            )
        default:
            return PetEventDetail(
                id: eventID,
                petID: mockPetName,
                litterID: nil,
                kind: .daily,
                subkind: "mental",
                title: "精神不错",
                summary: "正常平稳",
                visibility: .private,
                occurredAt: "2026年6月25日 10:30",
                recordRevision: 1
            )
        }
    }

    private static let mockPetName = "测试名字1"
}

private extension String {
    var eventDetailDisplayTime: String {
        if contains("年") {
            return self
        }

        let fractionalSecondsFormatter = ISO8601DateFormatter()
        fractionalSecondsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let date = fractionalSecondsFormatter.date(from: self) ?? formatter.date(from: self)
        guard let date else {
            return self
        }

        return date.formatted(
            .dateTime
                .year()
                .month(.defaultDigits)
                .day()
                .hour(.twoDigits(amPM: .omitted))
                .minute()
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}

private extension PetEventDetail {
    var receiptTitle: String {
        switch subkind {
        case "feeding":
            return "已喂食"
        default:
            return title
        }
    }

    var systemImage: String {
        switch subkind {
        case "feeding":
            return "fork.knife"
        case "weight":
            return "scalemass.fill"
        case "deworming":
            return "checkmark.seal.fill"
        case "walk":
            return "figure.walk"
        default:
            switch kind {
            case .daily:
                return "sparkles"
            case .health:
                return "cross.case.fill"
            case .merchant:
                return "storefront.fill"
            case .trade:
                return "doc.text.fill"
            case .memorial:
                return "heart.fill"
            }
        }
    }

    var tint: Color {
        switch subkind {
        case "feeding":
            return Color(mhbHex: "0093DD")
        case "weight":
            return MHBTheme.ColorToken.purple.color
        case "deworming":
            return MHBTheme.ColorToken.teal.color
        case "walk":
            return MHBTheme.ColorToken.warning.color
        default:
            return MHBTheme.ColorToken.primary.color
        }
    }

    var receiptRows: [PetEventDetailPresentation.Row] {
        switch subkind {
        case "feeding":
            return [
                .init(id: "pet", title: "宠物", pet: petIdentity),
                .init(id: "food", title: "食物名称", text: "渴望原味六种鱼"),
                .init(id: "amount", title: "摄入量", text: "50g"),
                .init(id: "source", title: "来源", text: "首页快捷按钮")
            ]
        case "weight":
            return [
                .init(id: "pet", title: "宠物", pet: petIdentity),
                .init(id: "weight", title: "体重", text: "3.6 kg"),
                .init(id: "change", title: "变化", text: "+0.2 kg"),
                .init(id: "source", title: "来源", text: "首页时间线")
            ]
        case "deworming":
            return [
                .init(id: "pet", title: "宠物", pet: petIdentity),
                .init(id: "medicine", title: "驱虫用品", text: summary ?? "大宠爱体外驱虫滴剂"),
                .init(id: "type", title: "记录类型", text: "驱虫"),
                .init(id: "source", title: "来源", text: "首页时间线")
            ]
        case "walk":
            return [
                .init(id: "pet", title: "宠物", pet: petIdentity),
                .init(id: "duration", title: "时长", text: "32 分钟"),
                .init(id: "distance", title: "距离", text: "2.3 km"),
                .init(id: "source", title: "来源", text: "首页时间线")
            ]
        default:
            var rows: [PetEventDetailPresentation.Row] = [
                .init(id: "pet", title: "宠物", pet: petIdentity),
                .init(id: "type", title: "记录类型", text: "精神状态"),
                .init(id: "content", title: "内容", text: "正常平稳")
            ]
            if let litterID {
                rows.append(.init(id: "litter", title: "窝次", text: litterID))
            }
            return rows
        }
    }

    private var petIdentity: PetEventDetailPresentation.PetIdentity {
        let name = petID?.isEmpty == false ? petID! : "测试名字1"
        return PetEventDetailPresentation.PetIdentity(
            id: petID ?? "pet-event-detail-current",
            name: name,
            avatarSource: .asset("HomePetHeroMock")
        )
    }
}

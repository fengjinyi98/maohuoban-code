import SwiftUI
import MaohuobanDesignSystem

// PetRecordDetailRoute 宠物记录详情分发路由
// 核心职责：
// - 统一首页时间线和全部记录列表的详情入口
// - 明确快速事实详情页只承载便便正常、精神不错、食欲正常三类记录
// - 将喂食、异常、体重、驱虫、疫苗、就诊和遛弯分发给各自详情页，避免通用详情页漂移
enum PetRecordDetailRoute: Hashable, Identifiable {
    case quickFact(PetQuickFactDetailKind)
    case feeding(recordID: String)
    case abnormal(recordID: String)
    case weight(recordID: String)
    case deworming(recordID: String)
    case vaccine(recordID: String)
    case clinicVisit(recordID: String)
    case walk(recordID: String)
    case unsupported(recordID: String)

    var id: String {
        switch self {
        case .quickFact(let kind):
            "quickFact-\(kind.rawValue)"
        case .feeding(let recordID):
            "feeding-\(recordID)"
        case .abnormal(let recordID):
            "abnormal-\(recordID)"
        case .weight(let recordID):
            "weight-\(recordID)"
        case .deworming(let recordID):
            "deworming-\(recordID)"
        case .vaccine(let recordID):
            "vaccine-\(recordID)"
        case .clinicVisit(let recordID):
            "clinicVisit-\(recordID)"
        case .walk(let recordID):
            "walk-\(recordID)"
        case .unsupported(let recordID):
            "unsupported-\(recordID)"
        }
    }

    static func mockRoute(for recordID: String) -> PetRecordDetailRoute {
        switch recordID {
        case "event-quick-poop-normal", "record-2026-06-poop-normal":
            .quickFact(.poopNormal)
        case "event-quick-energy-normal", "record-2026-06-energy-normal":
            .quickFact(.energyNormal)
        case "event-quick-appetite-normal", "record-2026-05-appetite":
            .quickFact(.appetiteNormal)
        case "event-feeding", "record-2026-06-feeding":
            .feeding(recordID: recordID)
        case "event-weight", "record-2026-06-weight":
            .weight(recordID: recordID)
        case "event-abnormal", "record-2026-06-abnormal":
            .abnormal(recordID: recordID)
        case "event-deworming", "record-2026-06-deworming", "deworming-2026-06", "deworming-2026-04":
            .deworming(recordID: recordID)
        case "event-vaccine", "record-2026-06-vaccine", "vaccine-rabies-2026-06", "vaccine-triple-2026-05":
            .vaccine(recordID: recordID)
        case "event-walk", "record-2026-05-walk":
            .walk(recordID: recordID)
        case "record-2026-04-hospital":
            .clinicVisit(recordID: recordID)
        default:
            .unsupported(recordID: recordID)
        }
    }
}

// PetRecordDetailDestinationScreen 宠物记录详情目标页
// 核心职责：
// - 根据 PetRecordDetailRoute 分发到正确的记录详情页
// - 在快速 UI 阶段为尚未实现的业务详情提供明确占位
struct PetRecordDetailDestinationScreen: View {
    let route: PetRecordDetailRoute
    var currentUserID: String? = nil

    var body: some View {
        switch route {
        case .quickFact(let kind):
            PetQuickFactDetailScreen(kind: kind)
        case .feeding(let recordID):
            PetFeedingDetailScreen(recordID: recordID)
        case .abnormal(let recordID):
            PetAbnormalRecordDetailScreen(
                recordID: recordID,
                currentUserID: currentUserID
            )
        case .weight(let recordID):
            PetWeightRecordDetailScreen(recordID: recordID)
        case .deworming(let recordID):
            PetPreventiveCareRecordDetailScreen(
                recordID: recordID,
                fallbackKind: .deworming
            )
        case .vaccine(let recordID):
            PetPreventiveCareRecordDetailScreen(
                recordID: recordID,
                fallbackKind: .vaccine
            )
        case .clinicVisit:
            PetRecordDetailPlaceholderScreen(
                systemImage: "stethoscope",
                title: "就诊记录详情",
                subtitle: "就诊记录会独立展示医院、检查项目、诊断、费用和附件。",
                accessibilityIdentifier: "pet.recordDetail.clinicVisit.placeholder"
            )
        case .walk:
            PetRecordDetailPlaceholderScreen(
                systemImage: "figure.walk",
                title: "遛弯记录详情",
                subtitle: "遛弯记录会进入遛弯模块详情，展示时长、距离和轨迹。",
                accessibilityIdentifier: "pet.recordDetail.walk.placeholder"
            )
        case .unsupported:
            PetRecordDetailPlaceholderScreen(
                systemImage: "doc.text.magnifyingglass",
                title: "记录详情",
                subtitle: "这条记录还没有接入对应的详情页。",
                accessibilityIdentifier: "pet.recordDetail.unsupported.placeholder"
            )
        }
    }
}

// PetQuickFactDetailKind 快速事实详情类型
// 核心职责：
// - 限定快速事实详情页允许展示的三类低成本记录
// - 为小票详情提供稳定标题、图标、记录类型和内容文案
enum PetQuickFactDetailKind: String, Hashable, Identifiable {
    case poopNormal
    case energyNormal
    case appetiteNormal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .poopNormal:
            "便便正常"
        case .energyNormal:
            "精神不错"
        case .appetiteNormal:
            "食欲正常"
        }
    }

    var recordTypeTitle: String {
        switch self {
        case .poopNormal:
            "排便状态"
        case .energyNormal:
            "精神状态"
        case .appetiteNormal:
            "食欲状态"
        }
    }

    var contentText: String {
        switch self {
        case .poopNormal:
            "正常"
        case .energyNormal:
            "正常平稳"
        case .appetiteNormal:
            "正常"
        }
    }

    var systemImage: String {
        switch self {
        case .poopNormal:
            "checkmark.seal.fill"
        case .energyNormal:
            "face.smiling"
        case .appetiteNormal:
            "takeoutbag.and.cup.and.straw.fill"
        }
    }

    var tint: Color {
        switch self {
        case .poopNormal:
            MHBTheme.ColorToken.teal.color
        case .energyNormal:
            MHBTheme.ColorToken.primary.color
        case .appetiteNormal:
            MHBTheme.ColorToken.warning.color
        }
    }
}

// PetQuickFactDetailScreen 快速事实详情页
// 核心职责：
// - 只展示便便正常、精神不错、食欲正常三类一次性快速事实
// - 复用宠物头像基础设施展示 mock 宠物身份
// - 保持喂食、异常、体重、医疗照护和遛弯记录不进入此页面
struct PetQuickFactDetailScreen: View {
    let kind: PetQuickFactDetailKind

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetQuickFactReceiptCard(
                    presentation: PetQuickFactDetailPresentation(kind: kind)
                )
                PetQuickFactDetailActions()
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("快速事实详情")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pet.quickFactDetail.screen")
    }
}

// PetQuickFactReceiptCard 快速事实小票卡片
// 核心职责：
// - 展示快速事实图标、标题、发生时间和关键字段
// - 让三类快速事实保持一致的轻量详情结构
private struct PetQuickFactReceiptCard: View {
    let presentation: PetQuickFactDetailPresentation

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

            PetQuickFactDashedDivider()
                .padding(.bottom, MHBTheme.Spacing.s5)

            VStack(spacing: 0) {
                ForEach(presentation.rows) { row in
                    PetQuickFactReceiptRow(row: row)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .padding(.vertical, MHBTheme.Spacing.s8)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 12, y: 4)
        .accessibilityIdentifier("pet.quickFactDetail.receiptCard")
    }
}

// PetQuickFactReceiptRow 快速事实小票字段行
// 核心职责：
// - 展示单个字段和值
// - 支持宠物身份和普通文本两种字段值
private struct PetQuickFactReceiptRow: View {
    let row: PetQuickFactDetailPresentation.Row

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
            Text(row.title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s4)

            PetQuickFactReceiptRowValue(value: row.value)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}

// PetQuickFactReceiptRowValue 快速事实字段值
// 核心职责：
// - 渲染普通文本或宠物头像名称组合
// - 复用 MHBAvatar 保持头像基础设施一致
private struct PetQuickFactReceiptRowValue: View {
    let value: PetQuickFactDetailPresentation.RowValue

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

// PetQuickFactDashedDivider 快速事实虚线分隔
// 核心职责：
// - 承载小票样式字段区分隔线
// - 避免引入图片或 UIKit 桥接
private struct PetQuickFactDashedDivider: View {
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

// PetQuickFactDetailActions 快速事实底部操作
// 核心职责：
// - 保留快速事实后续编辑和删除入口
// - 与当前详情页底部操作视觉保持一致
private struct PetQuickFactDetailActions: View {
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
        .accessibilityIdentifier("pet.quickFactDetail.actions")
    }
}

// PetRecordDetailPlaceholderScreen 记录详情占位页
// 核心职责：
// - 为尚未产品化的记录详情类型提供明确目标页
// - 在快速 UI 阶段防止非快速事实误入快速事实详情
private struct PetRecordDetailPlaceholderScreen: View {
    let systemImage: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let accessibilityIdentifier: String

    var body: some View {
        MHBTabPlaceholderRootScreen(
            systemImage: systemImage,
            title: title,
            subtitle: subtitle,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }
}

// PetQuickFactDetailPresentation 快速事实展示模型
// 核心职责：
// - 将快速事实类型转换为小票展示数据
// - 集中维护 mock 宠物和字段行，避免业务详情边界漂移
private struct PetQuickFactDetailPresentation {
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

    init(kind: PetQuickFactDetailKind) {
        self.title = kind.title
        self.timeText = "2026年6月25日 10:30"
        self.systemImage = kind.systemImage
        self.tint = kind.tint
        self.rows = [
            .init(id: "pet", title: "宠物", pet: Self.mockPet),
            .init(id: "type", title: "记录类型", text: kind.recordTypeTitle),
            .init(id: "content", title: "内容", text: kind.contentText)
        ]
    }

    private static let mockPet = PetIdentity(
        id: "pet-quick-fact-mock",
        name: "测试名字1",
        avatarSource: .asset("HomePetHeroMock")
    )
}

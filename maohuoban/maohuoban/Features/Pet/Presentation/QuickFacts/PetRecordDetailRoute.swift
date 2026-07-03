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
    var recordContext: PetRecordEntryContext? = nil

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
        case .weight:
            PetRecordDetailPlaceholderScreen(
                systemImage: "scalemass.fill",
                title: "体重记录详情",
                subtitle: "请从体重详情页进入单条体重记录，查看备注、趋势和编辑入口。",
                accessibilityIdentifier: "pet.recordDetail.weight.placeholder"
            )
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
        case .walk(let recordID):
            if let record = PetWalkRecordDetailResolver.record(for: recordID) {
                PetWalkHistoryDetailScreen(
                    record: record,
                    petName: walkPetName,
                    petAvatarURL: walkPetAvatarURL,
                    petSex: recordContext?.petSex ?? .unknown
                )
            } else {
                PetRecordDetailPlaceholderScreen(
                    systemImage: "figure.walk",
                    title: "遛弯记录详情",
                    subtitle: "遛弯记录会进入遛弯模块详情，展示时长、距离和轨迹。",
                    accessibilityIdentifier: "pet.recordDetail.walk.placeholder"
                )
            }
        case .unsupported:
            PetRecordDetailPlaceholderScreen(
                systemImage: "doc.text.magnifyingglass",
                title: "记录详情",
                subtitle: "这条记录还没有接入对应的详情页。",
                accessibilityIdentifier: "pet.recordDetail.unsupported.placeholder"
            )
        }
    }

    private var walkPetName: String {
        recordContext?.petName ?? recordContext?.selectedSwitchPet?.name ?? "当前宠物"
    }

    private var walkPetAvatarURL: URL? {
        guard let avatarURL = recordContext?.petAvatarURL ?? recordContext?.selectedSwitchPet?.avatarURL else {
            return nil
        }

        return MHBBackendEndpoint.resolve(avatarURL)
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

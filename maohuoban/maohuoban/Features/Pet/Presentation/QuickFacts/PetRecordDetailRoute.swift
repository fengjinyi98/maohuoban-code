import SwiftUI
import MaohuobanDesignSystem

// PetRecordDetailRoute 宠物记录详情分发路由
// 核心职责：
// - 统一首页时间线和全部记录列表的详情入口
// - 明确快速事实详情页只承载便便正常、精神不错、食欲正常三类记录
// - 将喂食、异常、体重、驱虫、疫苗、就诊和遛弯分发给各自详情页，避免通用详情页漂移
enum PetRecordDetailRoute: Hashable, Identifiable {
    case quickFact(recordID: String, kind: PetQuickFactDetailKind, context: PetRecordEntryContext?)
    case feeding(recordID: String, context: PetRecordEntryContext? = nil)
    case abnormal(recordID: String, context: PetRecordEntryContext? = nil)
    case weight(recordID: String)
    case deworming(recordID: String)
    case vaccine(recordID: String)
    case clinicVisit(recordID: String)
    case walk(recordID: String)
    case unsupported(recordID: String)

    var id: String {
        switch self {
        case .quickFact(let recordID, _, _):
            "quickFact-\(recordID)"
        case .feeding(let recordID, _):
            "feeding-\(recordID)"
        case .abnormal(let recordID, _):
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
        case .quickFact(let recordID, let kind, let context):
            PetQuickFactDetailScreen(
                recordID: recordID,
                kind: kind,
                currentUserID: currentUserID,
                recordContext: context ?? recordContext
            )
        case .feeding(let recordID, let context):
            PetFeedingDetailScreen(
                recordID: recordID,
                currentUserID: currentUserID,
                recordContext: context ?? recordContext
            )
        case .abnormal(let recordID, let context):
            PetAbnormalRecordDetailScreen(
                recordID: recordID,
                currentUserID: currentUserID,
                recordContext: context ?? recordContext
            )
        case .weight(let recordID):
            PetWeightRecordRouteScreen(
                recordID: recordID,
                context: recordContext ?? PetRecordEntryContext(petID: nil),
                currentUserID: currentUserID
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

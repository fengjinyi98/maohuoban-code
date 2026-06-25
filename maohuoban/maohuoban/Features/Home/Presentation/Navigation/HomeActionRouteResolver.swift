import Foundation

// HomeActionRoutingContext 首页动作路由上下文
// 核心职责：
// - 从首页快照提取当前宠物和商家主体 ID
// - 让动作映射不直接依赖完整首页快照
struct HomeActionRoutingContext: Equatable {
    let selectedPetID: String?
    let selectedPetName: String?
    let selectedPetAvatarURL: String?
    let selectedPetSex: PetRecordPetSex
    let selectedPetLifeStatus: String?
    let availablePets: [PetRecordSwitchPet]
    let merchantID: String?
    let city: String?

    init(
        selectedPetID: String? = nil,
        selectedPetName: String? = nil,
        selectedPetAvatarURL: String? = nil,
        selectedPetSex: PetRecordPetSex = .unknown,
        selectedPetLifeStatus: String? = nil,
        availablePets: [PetRecordSwitchPet] = [],
        merchantID: String? = nil,
        city: String? = nil
    ) {
        self.selectedPetID = selectedPetID
        self.selectedPetName = selectedPetName
        self.selectedPetAvatarURL = selectedPetAvatarURL
        self.selectedPetSex = selectedPetSex
        self.selectedPetLifeStatus = selectedPetLifeStatus
        self.availablePets = availablePets
        self.merchantID = merchantID
        self.city = city
    }

    init(snapshot: HomeDashboardSnapshot) {
        self.selectedPetID = snapshot.selectedPet?.id
        self.selectedPetName = snapshot.selectedPet?.name
        self.selectedPetAvatarURL = snapshot.selectedPet?.avatarURL
        self.selectedPetSex = PetRecordPetSex(homeDashboardSex: snapshot.selectedPet?.sex)
        self.selectedPetLifeStatus = snapshot.selectedPet?.lifeStatus
        self.availablePets = snapshot.petSwitcher.map { item in
            PetRecordSwitchPet(
                id: item.id,
                name: item.name,
                species: PetRecordPetSpecies(homeDashboardSpecies: item.species),
                breed: item.breed,
                avatarURL: item.avatarURL,
                sex: PetRecordPetSex(homeDashboardSex: item.sex ?? (item.id == snapshot.selectedPet?.id ? snapshot.selectedPet?.sex : nil)),
                lifeStatus: item.lifeStatus ?? (item.id == snapshot.selectedPet?.id ? snapshot.selectedPet?.lifeStatus : nil),
                isSelected: item.id == snapshot.selectedPet?.id
            )
        }
        self.merchantID = snapshot.merchantDashboard?.merchantID
        self.city = snapshot.identity.city
    }
}

private extension PetRecordPetSex {
    init(homeDashboardSex: HomeDashboardSnapshot.Sex?) {
        switch homeDashboardSex {
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown, nil:
            self = .unknown
        }
    }
}

private extension PetRecordPetSpecies {
    init(homeDashboardSpecies: HomeDashboardSnapshot.Species) {
        switch homeDashboardSpecies {
        case .dog:
            self = .dog
        case .cat:
            self = .cat
        case .other:
            self = .other
        }
    }
}

// HomeActionRouteResolver 首页动作路由解析器
// 核心职责：
// - 将后端下发的首页动作语义映射为本地 HomeRoute
// - 保持首页 section 只负责渲染和触发导航
enum HomeActionRouteResolver {
    static func route(
        for action: HomeDashboardSnapshot.Action,
        context: HomeActionRoutingContext
    ) -> HomeRoute? {
        switch action.kind {
        case .createPet:
            return .createPet
        case .dailyRecord:
            return nil
        case .healthRecord:
            return .recordHealth(
                PetRecordEntryContext(
                    petID: context.selectedPetID,
                    petName: context.selectedPetName,
                    petAvatarURL: context.selectedPetAvatarURL,
                    petSex: context.selectedPetSex,
                    lifeStatus: context.selectedPetLifeStatus
                )
            )
        case .preventiveCare:
            return .petPreventiveCare(
                PetPreventiveCareContext(
                    recordContext: PetRecordEntryContext(
                        petID: context.selectedPetID,
                        petName: context.selectedPetName,
                        petAvatarURL: context.selectedPetAvatarURL,
                        petSex: context.selectedPetSex,
                        lifeStatus: context.selectedPetLifeStatus,
                        availablePets: context.availablePets
                    ),
                    fallbackPetName: context.selectedPetName ?? "当前宠物"
                )
            )
        case .addReminder:
            // TODO: 通用提醒新增流程定稿后，在这里接入提醒系统新增入口。
            return nil
        case .walk:
            return .recordWalk(
                PetRecordEntryContext(
                    petID: context.selectedPetID,
                    petName: context.selectedPetName,
                    petAvatarURL: context.selectedPetAvatarURL,
                    petSex: context.selectedPetSex,
                    lifeStatus: context.selectedPetLifeStatus,
                    availablePets: context.availablePets
                )
            )
        case .bookHospital:
            return .bookHospital(petID: context.selectedPetID, city: context.city)
        case .importTradePet:
            return .importTradePet
        case .addMerchantPet:
            guard let merchantID = context.merchantID, !merchantID.isEmpty else {
                return nil
            }
            return .addMerchantPet(merchantID: merchantID)
        case .publishAvailableStatus:
            guard let merchantID = context.merchantID, !merchantID.isEmpty else {
                return nil
            }
            return .publishAvailableStatus(merchantID: merchantID)
        }
    }
}

// HomeReminderRouteResolver 首页提醒路由解析器
// 核心职责：
// - 将首页提醒摘要映射为本地导航目标
// - 优先根据提醒 sourceRef 进入关联业务详情
// - 保持提醒系统作为通用能力，疫苗驱虫等业务记录只负责创建和维护关联提醒
enum HomeReminderRouteResolver {
    static func route(
        for reminder: HomeDashboardSnapshot.Reminder,
        context: HomeActionRoutingContext
    ) -> HomeRoute? {
        if let sourceRoute = route(for: reminder.sourceRef) {
            return sourceRoute
        }

        switch reminder.kind {
        case .merchantTask:
            guard let merchantID = context.merchantID, !merchantID.isEmpty else {
                return nil
            }
            return .merchantTask(merchantID: merchantID, reminderID: reminder.id)
        case .vaccine:
            return .petRecordDetail(.vaccine(recordID: reminder.id))
        case .deworming:
            return .petRecordDetail(.deworming(recordID: reminder.id))
        case .followUp:
            return .petRecordDetail(.clinicVisit(recordID: reminder.id))
        case .completeHealthRecord:
            return .petRecordDetail(.unsupported(recordID: reminder.id))
        case .custom:
            return .petRecordDetail(.unsupported(recordID: reminder.id))
        }
    }

    private static func route(for sourceRef: HomeDashboardSnapshot.Reminder.SourceRef?) -> HomeRoute? {
        guard let sourceRef else { return nil }

        switch (sourceRef.domain, sourceRef.type) {
        case (.preventiveCare, .vaccine):
            return .petRecordDetail(.vaccine(recordID: sourceRef.recordID))
        case (.preventiveCare, .deworming):
            return .petRecordDetail(.deworming(recordID: sourceRef.recordID))
        case (.clinicVisit, .followUp):
            return .petRecordDetail(.clinicVisit(recordID: sourceRef.recordID))
        case (.custom, _), (_, .custom), (.preventiveCare, .followUp), (.clinicVisit, .vaccine), (.clinicVisit, .deworming):
            return nil
        }
    }
}

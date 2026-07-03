import SwiftUI

// PetWeightRecordRouteScreen 单条体重记录路由页
// 核心职责：
// - 根据首页时间线携带的宠物上下文加载体重记录数据源
// - 复用 PetWeightRecordDetailScreen 展示、编辑和删除单条体重记录
struct PetWeightRecordRouteScreen: View {
    let recordID: String
    let context: PetRecordEntryContext
    let currentUserID: String?

    @State private var store: PetWeightRecordStore?

    var body: some View {
        Group {
            if let store, store.hasLoaded || store.record(id: recordID) != nil {
                PetWeightRecordDetailScreen(
                    recordID: recordID,
                    petName: petName,
                    petAvatarSubject: petAvatarSubject,
                    store: store
                )
            } else if let store, let errorMessage = store.errorMessage {
                PetWeightRecordRouteErrorState(message: errorMessage) {
                    Task {
                        await store.load()
                    }
                }
            } else if context.petID == nil {
                PetWeightRecordRouteErrorState(message: "缺少当前宠物信息，暂时无法加载体重记录。") {}
            } else {
                PetWeightRecordRouteLoadingState()
            }
        }
        .task(id: recordID) {
            await ensureStoreLoaded()
        }
    }

    private var petName: String {
        context.petName ?? context.selectedSwitchPet?.name ?? "当前宠物"
    }

    private var petAvatarSubject: MHBAvatarSubject? {
        guard let pet = context.selectedSwitchPet else { return nil }
        return .pet(
            MHBAvatarPet(
                id: pet.id,
                name: pet.name ?? "未命名宠物",
                source: petAvatarSource(pet.avatarURL),
                species: petAvatarSpecies(pet.species),
                sex: petAvatarSex(pet.sex)
            )
        )
    }

    // petAvatarSource 将记录上下文头像地址映射为头像基础设施输入
    // 核心职责：
    // - 解析后端相对路径和完整远端地址
    // - 在缺少头像时回落为空头像源
    private func petAvatarSource(_ avatarURLString: String?) -> MHBAvatarSource {
        guard let avatarURLString,
              let avatarURL = MHBBackendEndpoint.resolve(avatarURLString) else {
            return .empty
        }

        return .remote(avatarURL)
    }

    // petAvatarSpecies 将记录上下文物种映射为头像基础设施物种
    // 核心职责：
    // - 隔离记录流程物种枚举与头像展示枚举
    private func petAvatarSpecies(_ species: PetRecordPetSpecies) -> MHBAvatarSpecies {
        switch species {
        case .dog:
            return .dog
        case .cat:
            return .cat
        case .other:
            return .other
        }
    }

    // petAvatarSex 将记录上下文性别映射为头像基础设施性别
    // 核心职责：
    // - 隔离记录流程性别枚举与头像描边枚举
    private func petAvatarSex(_ sex: PetRecordPetSex) -> MHBAvatarSex {
        switch sex {
        case .female:
            return .female
        case .male:
            return .male
        case .unknown:
            return .unknown
        }
    }

    private func ensureStoreLoaded() async {
        guard let petID = context.petID else { return }

        if store == nil {
            store = PetWeightRecordStore(
                petID: petID,
                currentUserID: currentUserID ?? ""
            )
        }

        await store?.load()
    }
}

import SwiftUI
import MaohuobanDesignSystem

// PetManagementPetAvatar 我的宠物列表头像
// 核心职责：
// - 展示本地或远端宠物头像资源
// - 在头像缺失时按物种提供稳定兜底视觉
struct PetManagementPetAvatar: View {
    let pet: PetManagementPet

    private let size: CGFloat = 48
 
    var body: some View {
        MHBAvatar(
            subject: PetManagementAvatarPresentation.avatarSubject(
                for: pet,
                source: PetManagementAvatarPresentation.source(
                    assetName: pet.avatarAssetName,
                    avatarURL: pet.avatarURL
                )
            ),
            size: .custom(size),
            shape: .squircle
        )
    }
}

// PetManagementAvatarPresentation 我的宠物头像展示映射器
// 核心职责：
// - 将我的宠物列表模型映射为宠物头像主体
// - 统一本地资源、远端资源和宠物性别描边输入
enum PetManagementAvatarPresentation {
    static func source(assetName: String?, avatarURL: String?) -> MHBAvatarSource {
        if let assetName,
           assetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return .asset(assetName)
        }

        if let avatarURL,
           let url = MHBBackendEndpoint.resolve(avatarURL) {
            return .remote(url)
        }

        return .empty
    }

    static func avatarSubject(
        for pet: PetManagementPet,
        source: MHBAvatarSource
    ) -> MHBAvatarSubject {
        .pet(
            MHBAvatarPet(
                id: pet.id,
                name: pet.name,
                source: source,
                species: pet.species.avatarSpecies,
                sex: pet.sex.avatarSex
            )
        )
    }
}

private extension PetProfileEditProfile.Species {
    nonisolated var avatarSpecies: MHBAvatarSpecies {
        switch self {
        case .dog:
            .dog
        case .cat:
            .cat
        case .other:
            .other
        }
    }
}

private extension PetManagementPet.Sex {
    nonisolated var avatarSex: MHBAvatarSex {
        switch self {
        case .male:
            .male
        case .female:
            .female
        case .unknown:
            .unknown
        }
    }
}

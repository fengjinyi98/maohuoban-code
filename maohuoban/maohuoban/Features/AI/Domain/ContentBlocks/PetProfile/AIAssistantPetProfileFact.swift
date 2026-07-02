import Foundation
import MaohuobanDesignSystem

// AIAssistantPetProfileFact 宠物档案事实字段
// 核心职责：
// - 表达来自数据库或工具结果的宠物基础事实
// - 隔离事实字段与 LLM 生成文案
struct AIAssistantPetProfileFact: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let species: AIAssistantPetProfileSpecies
    let speciesText: String
    let sex: AIAssistantPetProfileSex
    let sexText: String
    let breed: String
    let avatarURL: String?
    let birthDate: String?
    let arrivalDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case species
        case speciesText = "species_text"
        case sex
        case sexText = "sex_text"
        case breed
        case avatarURL = "avatar_url"
        case birthDate = "birth_date"
        case arrivalDate = "arrival_date"
    }

    var resolvedAvatarURL: URL? {
        guard let avatarURL, avatarURL.isEmpty == false else { return nil }
        return MHBBackendEndpoint.resolve(avatarURL)
    }

    var avatarSubject: MHBAvatarSubject {
        .pet(
            MHBAvatarPet(
                id: id,
                name: name,
                source: resolvedAvatarURL.map { .remote($0) } ?? .empty,
                species: species.avatarSpecies,
                sex: sex.avatarSex
            )
        )
    }
}

import Foundation

// ProfileFavoriteFolderCreateDraft 新建收藏夹草稿
// 核心职责：
// - 表达新建收藏夹表单的可提交状态
// - 统一收藏夹名称长度和空值校验
struct ProfileFavoriteFolderCreateDraft: Equatable {
    static let maxNameCount = 15

    let name: String
    let isPrivate: Bool

    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isNameLimitExceeded: Bool {
        name.count > Self.maxNameCount
    }

    var canCreate: Bool {
        !normalizedName.isEmpty && !isNameLimitExceeded
    }

    var counterText: String {
        "\(name.count) / \(Self.maxNameCount)"
    }
}

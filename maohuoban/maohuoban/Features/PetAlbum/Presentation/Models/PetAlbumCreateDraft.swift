import Foundation

// PetAlbumCreateDraft 新建相册草稿
// 核心职责：
// - 表达新建相册表单的可提交状态
// - 统一相册名称长度和空值校验
struct PetAlbumCreateDraft: Equatable {
    static let maxNameCount = 15

    let name: String
    let isPrivate: Bool
    let coverAssetID: String?

    init(
        name: String,
        isPrivate: Bool,
        coverAssetID: String? = nil
    ) {
        self.name = name
        self.isPrivate = isPrivate
        self.coverAssetID = coverAssetID
    }

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

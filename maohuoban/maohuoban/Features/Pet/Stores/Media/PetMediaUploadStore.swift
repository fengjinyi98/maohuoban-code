import Observation

// PetMediaUploadStore 宠物媒体上传状态模型
// 核心职责：
// - 统一管理添加和编辑档案的媒体上传状态
// - 暴露保存按钮禁用和进度遮罩所需数据
@MainActor
@Observable
final class PetMediaUploadStore {
    var avatarState: PetMediaUploadSlotState = .idle
    var backgroundState: PetMediaUploadSlotState = .idle

    var isUploading: Bool {
        avatarState.isUploading || backgroundState.isUploading
    }

    var uploadedBindings: PetUploadedMediaBindings {
        PetUploadedMediaBindings(
            avatarAssetID: avatarState.assetID,
            backgroundAssetID: backgroundState.assetID
        )
    }

    let repository: PetRepository

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }
}

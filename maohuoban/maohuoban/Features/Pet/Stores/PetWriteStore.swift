import Observation

// PetWriteStore 宠物写入状态模型
// 核心职责：
// - 管理创建宠物与记录事件的提交状态
// - 承接表单校验、Repository 调用和成功消息
@MainActor
@Observable
final class PetWriteStore {
    var phase: PetWritePhase = .idle
    var successMessage: String?
    var latestPetProfile: PetProfileSummary?

    var isSubmitting: Bool {
        phase == .submitting
    }

    let repository: PetRepository

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    func reset() {
        phase = .idle
        successMessage = nil
        latestPetProfile = nil
    }
}

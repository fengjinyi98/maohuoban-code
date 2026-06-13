import Foundation
import Observation

// MerchantPetCreateStore 商家新增宠物状态模型
// 核心职责：
// - 管理商家新增宠物提交状态
// - 承接当前用户、商家 ID、表单校验和 Repository 调用
@MainActor
@Observable
final class MerchantPetCreateStore {
    var phase: MerchantPetCreatePhase = .idle
    var successMessage: String?

    var isSubmitting: Bool {
        phase == .submitting
    }

    private let repository: MerchantRepository

    init(repository: MerchantRepository = DefaultMerchantRepository()) {
        self.repository = repository
    }

    func create(
        merchantID: String,
        draft: MerchantPetDraft,
        currentUserID: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard !merchantID.isEmpty else {
            phase = .failed("商家信息为空")
            return
        }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("请输入宠物名字")
            return
        }
        guard phase != .submitting else { return }

        phase = .submitting
        successMessage = nil
        do {
            let response = try await repository.createPet(
                merchantID: merchantID,
                draft: draft,
                currentUserID: currentUserID
            )
            guard let pet = response.data else {
                phase = .failed("商家宠物数据为空")
                return
            }
            successMessage = response.message
            phase = .created(pet.id)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func reset() {
        phase = .idle
        successMessage = nil
    }
}

// MerchantPetCreatePhase 商家新增宠物阶段
// 核心职责：
// - 表达提交、成功和失败状态
// - 支持视图基于单一状态渲染反馈
enum MerchantPetCreatePhase: Equatable {
    case idle
    case submitting
    case created(String)
    case failed(String)
}

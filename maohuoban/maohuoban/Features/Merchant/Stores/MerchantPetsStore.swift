import Foundation
import Observation

// MerchantPetsStore 商家宠物列表状态模型
// 核心职责：
// - 管理商家宠物列表加载状态
// - 承接当前用户上下文校验和 Repository 调用
@MainActor
@Observable
final class MerchantPetsStore {
    var phase: MerchantPetsPhase = .idle

    var isLoading: Bool {
        phase == .loading
    }

    private let repository: MerchantRepository

    init(repository: MerchantRepository = DefaultMerchantRepository()) {
        self.repository = repository
    }

    func load(
        merchantID: String,
        status: MerchantPetStatus,
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
        guard phase != .loading else { return }

        phase = .loading
        do {
            let response = try await repository.listPets(
                merchantID: merchantID,
                status: status,
                currentUserID: currentUserID
            )
            guard let list = response.data else {
                phase = .failed("商家宠物数据为空")
                return
            }
            phase = .loaded(list)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }
}

// MerchantPetsPhase 商家宠物列表加载阶段
// 核心职责：
// - 表达列表页空闲、加载、成功和失败状态
// - 支持视图基于单一状态渲染反馈
enum MerchantPetsPhase: Equatable {
    case idle
    case loading
    case loaded(MerchantPetList)
    case failed(String)
}

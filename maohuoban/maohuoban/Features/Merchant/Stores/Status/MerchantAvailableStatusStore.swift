import Foundation
import Observation

// MerchantAvailableStatusStore 商家可售状态发布模型
// 核心职责：
// - 管理待发布宠物候选列表加载状态
// - 承接当前用户、商家 ID、宠物 ID 和发布草稿校验
@MainActor
@Observable
final class MerchantAvailableStatusStore {
    var phase: MerchantAvailableStatusPhase = .idle
    var successMessage: String?

    var isBusy: Bool {
        phase == .loading || phase == .publishing
    }

    private let repository: MerchantRepository

    init(repository: MerchantRepository = DefaultMerchantRepository()) {
        self.repository = repository
    }

    func loadCandidates(merchantID: String, currentUserID: String?) async {
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
        successMessage = nil
        do {
            let response = try await repository.listPets(
                merchantID: merchantID,
                status: .needsRecord,
                currentUserID: currentUserID
            )
            guard let list = response.data else {
                phase = .failed("待发布宠物数据为空")
                return
            }
            phase = .loaded(list.pets)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func publish(
        merchantID: String,
        petID: String,
        draft: MerchantAvailableStatusDraft,
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
        guard !petID.isEmpty else {
            phase = .failed("请选择要发布的宠物")
            return
        }
        guard phase != .publishing else { return }

        phase = .publishing
        successMessage = nil
        do {
            let response = try await repository.publishAvailableStatus(
                merchantID: merchantID,
                petID: petID,
                draft: draft,
                currentUserID: currentUserID
            )
            guard let publication = response.data else {
                phase = .failed("可售发布结果为空")
                return
            }
            successMessage = response.message
            phase = .published(publication)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }
}

// MerchantAvailableStatusPhase 商家可售发布阶段
// 核心职责：
// - 表达候选加载、发布提交、成功和失败状态
// - 支持页面基于单一状态渲染反馈
enum MerchantAvailableStatusPhase: Equatable {
    case idle
    case loading
    case loaded([MerchantManagedPet])
    case publishing
    case published(MerchantAvailableStatusPublication)
    case failed(String)
}

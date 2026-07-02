import Foundation
import Observation

// MerchantLitterDetailStore 商家窝次详情状态模型
// 核心职责：
// - 管理商家窝次详情加载状态
// - 承接当前用户、商家 ID、窝次 ID 校验和 Repository 调用
@MainActor
@Observable
final class MerchantLitterDetailStore {
    var phase: MerchantLitterDetailPhase = .idle

    var isLoading: Bool {
        phase == .loading
    }

    private let repository: MerchantRepository

    init(repository: MerchantRepository = DefaultMerchantRepository()) {
        self.repository = repository
    }

    func load(
        merchantID: String,
        litterID: String,
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
        guard !litterID.isEmpty else {
            phase = .failed("窝次信息为空")
            return
        }
        guard phase != .loading else { return }

        phase = .loading
        do {
            let response = try await repository.loadLitterDetail(
                merchantID: merchantID,
                litterID: litterID,
                currentUserID: currentUserID
            )
            guard let detail = response.data else {
                phase = .failed("窝次详情为空")
                return
            }
            phase = .loaded(detail)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }
}

// MerchantLitterDetailPhase 商家窝次详情加载阶段
// 核心职责：
// - 表达空闲、加载、成功和失败状态
// - 支持详情页基于单一状态渲染反馈
enum MerchantLitterDetailPhase: Equatable {
    case idle
    case loading
    case loaded(MerchantLitterDetail)
    case failed(String)
}

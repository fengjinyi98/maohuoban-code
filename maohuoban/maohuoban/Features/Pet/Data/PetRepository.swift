import Foundation

// PetRepository 宠物写入仓库协议
// 核心职责：
// - 定义宠物档案与事件写入 API
// - 隔离 HTTP 客户端和展示层状态
protocol PetRepository {
    func createPet(
        draft: PetProfileDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary>

    func createEvent(
        petID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventSummary>

    func loadEventDetail(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail>
}

// DefaultPetRepository 默认宠物写入仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 宠物接口
// - 在写入请求中传递当前用户上下文
struct DefaultPetRepository: PetRepository {
    private let client: MHBHTTPClient

    init(client: MHBHTTPClient = MHBHTTPClient()) {
        self.client = client
    }

    func createPet(
        draft: PetProfileDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        try await client.post(
            path: "/api/v1/pets",
            body: draft,
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func createEvent(
        petID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventSummary> {
        try await client.post(
            path: "/api/v1/pets/\(petID)/events",
            body: draft,
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func loadEventDetail(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail> {
        try await client.get(
            path: "/api/v1/pet-events/\(eventID)",
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    private func userHeaders(currentUserID: String) -> [String: String] {
        ["x-maohuoban-user-id": currentUserID]
    }
}

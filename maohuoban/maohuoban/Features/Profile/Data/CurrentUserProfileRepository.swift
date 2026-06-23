import Foundation

// CurrentUserProfileRepository 当前用户资料仓储协议
// 核心职责：
// - 定义个人资料页读取和更新接口
// - 隔离 HTTP 客户端、TokenStore 与展示层状态
protocol CurrentUserProfileRepository {
    func loadCurrentProfile() async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile>

    func updateCurrentProfile(
        draft: CurrentUserProfileUpdateDraft
    ) async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile>

    func uploadCurrentProfileAvatar(
        draft: CurrentUserProfileMediaUploadDraft,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile>

    func uploadCurrentProfileCover(
        draft: CurrentUserProfileMediaUploadDraft,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile>
}

// DefaultCurrentUserProfileRepository 默认当前用户资料仓储
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust Profile 接口
// - 由 HTTP client 发送边界统一补齐 Authorization
struct DefaultCurrentUserProfileRepository: CurrentUserProfileRepository {
    let client: MHBHTTPClient

    init(
        client: MHBHTTPClient = MHBHTTPClient.authenticated()
    ) {
        self.client = client
    }

    func loadCurrentProfile() async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile> {
        try await client.get(
            path: "/api/v1/profile/me"
        )
    }

    func updateCurrentProfile(
        draft: CurrentUserProfileUpdateDraft
    ) async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile> {
        try await client.patch(
            path: "/api/v1/profile/me",
            body: draft
        )
    }

    func uploadCurrentProfileAvatar(
        draft: CurrentUserProfileMediaUploadDraft,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile> {
        try await uploadCurrentProfileMedia(
            path: "/api/v1/profile/me/avatar",
            draft: draft,
            onUploadProgress: onUploadProgress
        )
    }

    func uploadCurrentProfileCover(
        draft: CurrentUserProfileMediaUploadDraft,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile> {
        try await uploadCurrentProfileMedia(
            path: "/api/v1/profile/me/cover",
            draft: draft,
            onUploadProgress: onUploadProgress
        )
    }

    private func uploadCurrentProfileMedia(
        path: String,
        draft: CurrentUserProfileMediaUploadDraft,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile> {
        try await client.postMultipart(
            path: path,
            file: MHBMultipartFile(
                fieldName: "file",
                fileName: draft.fileName,
                mimeType: draft.mimeType,
                data: draft.content
            ),
            fields: ["source_client": draft.sourceClient],
            onUploadProgress: onUploadProgress
        )
    }
}

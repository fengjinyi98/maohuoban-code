import Foundation
import MaohuobanDiagnostics

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
        let mediaKind = path.hasSuffix("/avatar") ? "avatar" : "cover"
        let startedAt = Date()
        print("[DEBUG:ProfileAvatarUpload] profile repository upload request path=\(path) kind=\(mediaKind) bytes=\(draft.content.count) mime=\(draft.mimeType) file=\(draft.fileName)")
        let requestProperties: DiagnosticProperties = [
            "issue_tag": .string("ProfileAvatarUpload"),
            "path": .string(path),
            "media_kind": .string(mediaKind),
            "content_bytes": .int(draft.content.count),
            "mime_type": .string(draft.mimeType),
            "file_name": .string(draft.fileName),
            "source_client": .string(draft.sourceClient)
        ]
        await Diagnostics.track(
            "profile.media_upload.repository_request",
            properties: requestProperties
        )
        do {
            let response: MHBAPIResponse<CurrentUserProfile> = try await client.postMultipart(
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
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
            print("[DEBUG:ProfileAvatarUpload] profile repository upload succeeded path=\(path) kind=\(mediaKind) code=\(response.code) elapsed_ms=\(elapsedMs)")
            let successProperties: DiagnosticProperties = [
                "issue_tag": .string("ProfileAvatarUpload"),
                "path": .string(path),
                "media_kind": .string(mediaKind),
                "response_code": .string(response.code),
                "duration_ms": .int(elapsedMs)
            ]
            await Diagnostics.track(
                "profile.media_upload.repository_succeeded",
                properties: successProperties
            )
            return response
        } catch {
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
            print("[DEBUG:ProfileAvatarUpload] profile repository upload failed path=\(path) kind=\(mediaKind) error_kind=\(error.diagnosticsSummary) elapsed_ms=\(elapsedMs)")
            let failureProperties: DiagnosticProperties = [
                "issue_tag": .string("ProfileAvatarUpload"),
                "path": .string(path),
                "media_kind": .string(mediaKind),
                "error_kind": .string(error.diagnosticsSummary),
                "duration_ms": .int(elapsedMs)
            ]
            await Diagnostics.track(
                "profile.media_upload.repository_failed",
                properties: failureProperties
            )
            throw error
        }
    }
}

import Foundation

// DefaultPetAlbumRepository 默认用户级宠物相册仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 用户相册空间接口
// - 在请求中传递当前用户上下文
struct DefaultPetAlbumRepository: PetAlbumRepository {
    let client: MHBHTTPClient

    init(
        client: MHBHTTPClient = MHBHTTPClient.authenticated()
    ) {
        self.client = client
    }

    func listAlbums(
        currentUserID: String,
        limit: Int,
        cursor: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumListData> {
        try await client.get(
            path: "/api/v1/pet-albums",
            queryItems: paginationQueryItems(limit: limit, cursor: cursor),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func createAlbum(
        draft: PetAlbumCreateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData> {
        try await client.post(
            path: "/api/v1/pet-albums",
            body: PetAlbumDTO.CreateAlbumRequest(draft: draft),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func loadAlbum(
        albumID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumDetailData> {
        try await client.get(
            path: "/api/v1/pet-albums/\(albumID)",
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func updateAlbum(
        albumID: String,
        draft: PetAlbumCreateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData> {
        try await client.patch(
            path: "/api/v1/pet-albums/\(albumID)",
            body: PetAlbumDTO.UpdateAlbumRequest(draft: draft),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func updateAlbumPinned(
        albumID: String,
        isPinned: Bool,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData> {
        try await client.patch(
            path: "/api/v1/pet-albums/\(albumID)",
            body: PetAlbumDTO.UpdatePinnedRequest(isPinned: isPinned),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func archiveAlbum(
        albumID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData> {
        try await client.delete(
            path: "/api/v1/pet-albums/\(albumID)",
            body: MHBEmptyRequest(),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func listAssets(
        albumID: String,
        currentUserID: String,
        limit: Int,
        cursor: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AssetListData> {
        try await client.get(
            path: "/api/v1/pet-albums/\(albumID)/assets",
            queryItems: paginationQueryItems(limit: limit, cursor: cursor),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func removeAsset(
        albumAssetID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumDetailData> {
        try await client.delete(
            path: "/api/v1/pet-album-assets/\(albumAssetID)",
            body: MHBEmptyRequest(),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    private func userHeaders(currentUserID: String) throws(MHBAPIError) -> [String: String] {
        guard !currentUserID.isEmpty else {
            throw .business(
                code: "auth.session_expired",
                message: "登录状态已过期，请重新登录",
                statusCode: 401
            )
        }
        return ["x-maohuoban-user-id": currentUserID]
    }

    private func paginationQueryItems(limit: Int, cursor: String?) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return items
    }
}

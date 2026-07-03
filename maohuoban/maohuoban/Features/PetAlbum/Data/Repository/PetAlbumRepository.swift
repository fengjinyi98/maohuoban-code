import Foundation

// PetAlbumRepository 宠物相册仓库协议
// 核心职责：
// - 定义相册列表、详情和变更接口
// - 隔离 HTTP DTO 与展示状态
protocol PetAlbumRepository {
    func listAlbums(
        petID: String,
        currentUserID: String,
        limit: Int,
        cursor: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumListData>

    func createAlbum(
        petID: String,
        draft: PetAlbumCreateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData>

    func loadAlbum(
        albumID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumDetailData>

    func updateAlbum(
        albumID: String,
        draft: PetAlbumCreateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData>

    func updateAlbumPinned(
        albumID: String,
        isPinned: Bool,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData>

    func archiveAlbum(
        albumID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumData>

    func listAssets(
        albumID: String,
        currentUserID: String,
        limit: Int,
        cursor: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AssetListData>

    func removeAsset(
        albumAssetID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumDetailData>
}

import Foundation

// PetAlbumRepository 用户级宠物相册仓库协议
// 核心职责：
// - 定义用户相册空间的列表、详情和变更接口
// - 隔离 HTTP DTO 与展示状态
// - 将宠物上下文保留在入口层，避免作为相册数据源边界
protocol PetAlbumRepository {
    func listAlbums(
        currentUserID: String,
        limit: Int,
        cursor: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetAlbumDTO.AlbumListData>

    func createAlbum(
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

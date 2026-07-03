import Foundation
import Observation

// PetAlbumStore 用户级宠物相册展示状态
// 核心职责：
// - 作为用户相册空间列表、创建、详情页的单一状态源
// - 通过仓库执行后端读写并更新展示状态
// - 只把入口宠物作为来源上下文，不作为相册归属或数据源边界
@MainActor
@Observable
final class PetAlbumStore {
    private(set) var albums: [PetAlbumSummary] = []
    private(set) var assetsByAlbumID: [String: [PetAlbumAsset]] = [:]
    private(set) var isLoadingAlbums = false
    private(set) var loadingAssetAlbumIDs: Set<String> = []
    private(set) var mutationInFlight = false
    private(set) var errorMessage: String?
    private(set) var nextAlbumCursor: String?
    private(set) var nextAssetCursorByAlbumID: [String: String] = [:]

    @ObservationIgnored private let repository: PetAlbumRepository
    @ObservationIgnored private let context: PetAlbumEntryContext
    @ObservationIgnored private let currentUserID: String?

    var petName: String? {
        context.petName
    }

    var sourcePetID: String? {
        context.petID
    }

    init(
        context: PetAlbumEntryContext = PetAlbumEntryContext(),
        currentUserID: String? = nil,
        repository: PetAlbumRepository = DefaultPetAlbumRepository(),
        albums: [PetAlbumSummary] = [],
        assetsByAlbumID: [String: [PetAlbumAsset]] = [:]
    ) {
        self.context = context
        self.currentUserID = currentUserID
        self.repository = repository
        self.albums = albums
        self.assetsByAlbumID = assetsByAlbumID
    }

    func album(id: String) -> PetAlbumSummary? {
        albums.first { $0.id == id }
    }

    func assets(for albumID: String) -> [PetAlbumAsset] {
        assetsByAlbumID[albumID] ?? []
    }

    func loadAlbums(force: Bool = false) async {
        guard force || albums.isEmpty else { return }
        guard let currentUserID else {
            errorMessage = "请先登录"
            return
        }

        isLoadingAlbums = true
        errorMessage = nil
        do {
            let response = try await repository.listAlbums(
                currentUserID: currentUserID,
                limit: 30,
                cursor: nil
            )
            guard let data = response.data else {
                throw MHBAPIError.invalidResponse
            }
            albums = data.items.map { $0.summary() }
            nextAlbumCursor = data.nextCursor
        } catch {
            errorMessage = Self.toastMessage(for: error)
        }
        isLoadingAlbums = false
    }

    func loadAssets(for albumID: String, force: Bool = false) async {
        guard force || assetsByAlbumID[albumID] == nil else { return }
        guard let currentUserID else {
            errorMessage = "请先登录"
            return
        }

        loadingAssetAlbumIDs.insert(albumID)
        errorMessage = nil
        do {
            let response = try await repository.listAssets(
                albumID: albumID,
                currentUserID: currentUserID,
                limit: 60,
                cursor: nil
            )
            guard let data = response.data else {
                throw MHBAPIError.invalidResponse
            }
            assetsByAlbumID[albumID] = data.items.map { $0.asset() }
            nextAssetCursorByAlbumID[albumID] = data.nextCursor
            updateAlbum(albumID: albumID) { album in
                album.replacing(photoCount: data.items.count)
            }
        } catch {
            errorMessage = Self.toastMessage(for: error)
        }
        loadingAssetAlbumIDs.remove(albumID)
    }

    func createAlbum(draft: PetAlbumCreateDraft) async -> Bool {
        guard let currentUserID else {
            errorMessage = "请先登录"
            return false
        }

        mutationInFlight = true
        errorMessage = nil
        defer { mutationInFlight = false }

        do {
            let response = try await repository.createAlbum(
                draft: draft,
                currentUserID: currentUserID
            )
            guard let album = response.data else {
                throw MHBAPIError.invalidResponse
            }
            albums.insert(album.summary(), at: 0)
            PetAlbumMutationSignal.post()
            return true
        } catch {
            errorMessage = Self.toastMessage(for: error)
        }
        return false
    }

    func updateAlbum(albumID: String, draft: PetAlbumCreateDraft) async -> Bool {
        guard let currentUserID else {
            errorMessage = "请先登录"
            return false
        }

        mutationInFlight = true
        errorMessage = nil
        defer { mutationInFlight = false }

        do {
            let response = try await repository.updateAlbum(
                albumID: albumID,
                draft: draft,
                currentUserID: currentUserID
            )
            guard let album = response.data else {
                throw MHBAPIError.invalidResponse
            }
            replaceAlbum(album.summary())
            PetAlbumMutationSignal.post()
            return true
        } catch {
            errorMessage = Self.toastMessage(for: error)
        }
        return false
    }

    func deleteAlbum(id albumID: String) async {
        guard let currentUserID else {
            errorMessage = "请先登录"
            return
        }

        mutationInFlight = true
        errorMessage = nil
        defer { mutationInFlight = false }

        do {
            _ = try await repository.archiveAlbum(
                albumID: albumID,
                currentUserID: currentUserID
            )
            albums.removeAll { $0.id == albumID }
            assetsByAlbumID[albumID] = nil
            PetAlbumMutationSignal.post()
        } catch {
            errorMessage = Self.toastMessage(for: error)
        }
    }

    func deleteAsset(id assetID: String, in albumID: String) async {
        guard let currentUserID else {
            errorMessage = "请先登录"
            return
        }

        mutationInFlight = true
        errorMessage = nil
        defer { mutationInFlight = false }

        do {
            _ = try await repository.removeAsset(
                albumAssetID: assetID,
                currentUserID: currentUserID
            )
            var assets = assetsByAlbumID[albumID] ?? []
            assets.removeAll { $0.id == assetID }
            assetsByAlbumID[albumID] = assets
            updateAlbum(albumID: albumID) { album in
                album.replacing(photoCount: assets.count)
            }
            PetAlbumMutationSignal.post()
        } catch {
            errorMessage = Self.toastMessage(for: error)
        }
    }

    func togglePinned(albumID: String) async {
        guard let album = album(id: albumID) else {
            return
        }

        guard let currentUserID else {
            errorMessage = "请先登录"
            return
        }

        mutationInFlight = true
        errorMessage = nil
        defer { mutationInFlight = false }

        do {
            let response = try await repository.updateAlbumPinned(
                albumID: albumID,
                isPinned: !album.isPinned,
                currentUserID: currentUserID
            )
            guard let album = response.data else {
                throw MHBAPIError.invalidResponse
            }
            replaceAlbum(album.summary())
            PetAlbumMutationSignal.post()
        } catch {
            errorMessage = Self.toastMessage(for: error)
        }
    }

    private func updateAlbum(
        albumID: String,
        transform: (PetAlbumSummary) -> PetAlbumSummary
    ) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else {
            return
        }

        albums[index] = transform(albums[index])
    }

    private func replaceAlbum(_ album: PetAlbumSummary) {
        guard let index = albums.firstIndex(where: { $0.id == album.id }) else {
            albums.insert(album, at: 0)
            return
        }
        albums[index] = album
    }

    private static func toastMessage(for error: any Error) -> String {
        if let apiError = error as? MHBAPIError {
            return apiError.toastMessage
        }
        return MHBAPIError.transport(error.localizedDescription).toastMessage
    }
}

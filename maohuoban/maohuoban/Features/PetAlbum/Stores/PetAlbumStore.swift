import Foundation
import Observation

// PetAlbumStore 宠物相册展示状态
// 核心职责：
// - 作为相册模块列表、创建、详情页的单一状态源
// - 通过仓库执行后端读写并更新展示状态
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

    var petID: String? {
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
        guard let petID, let currentUserID else {
            errorMessage = "请先选择宠物并登录"
            return
        }

        isLoadingAlbums = true
        errorMessage = nil
        do {
            let response = try await repository.listAlbums(
                petID: petID,
                currentUserID: currentUserID,
                limit: 30,
                cursor: nil
            )
            guard let data = response.data else {
                throw MHBAPIError.invalidResponse
            }
            albums = data.items.map { $0.summary(petName: context.petName) }
            nextAlbumCursor = data.nextCursor
        } catch let error as MHBAPIError {
            errorMessage = error.toastMessage
        } catch {
            errorMessage = MHBAPIError.transport(error.localizedDescription).toastMessage
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
        } catch let error as MHBAPIError {
            errorMessage = error.toastMessage
        } catch {
            errorMessage = MHBAPIError.transport(error.localizedDescription).toastMessage
        }
        loadingAssetAlbumIDs.remove(albumID)
    }

    func createAlbum(draft: PetAlbumCreateDraft) async -> Bool {
        guard let petID, let currentUserID else {
            errorMessage = "请先选择宠物并登录"
            return false
        }

        mutationInFlight = true
        errorMessage = nil
        defer { mutationInFlight = false }

        do {
            let response = try await repository.createAlbum(
                petID: petID,
                draft: draft,
                currentUserID: currentUserID
            )
            guard let album = response.data else {
                throw MHBAPIError.invalidResponse
            }
            albums.insert(album.summary(petName: context.petName), at: 0)
            return true
        } catch let error as MHBAPIError {
            errorMessage = error.toastMessage
        } catch {
            errorMessage = MHBAPIError.transport(error.localizedDescription).toastMessage
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
            replaceAlbum(album.summary(petName: context.petName))
            return true
        } catch let error as MHBAPIError {
            errorMessage = error.toastMessage
        } catch {
            errorMessage = MHBAPIError.transport(error.localizedDescription).toastMessage
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
        } catch let error as MHBAPIError {
            errorMessage = error.toastMessage
        } catch {
            errorMessage = MHBAPIError.transport(error.localizedDescription).toastMessage
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
        } catch let error as MHBAPIError {
            errorMessage = error.toastMessage
        } catch {
            errorMessage = MHBAPIError.transport(error.localizedDescription).toastMessage
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
            replaceAlbum(album.summary(petName: context.petName))
        } catch let error as MHBAPIError {
            errorMessage = error.toastMessage
        } catch {
            errorMessage = MHBAPIError.transport(error.localizedDescription).toastMessage
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
}

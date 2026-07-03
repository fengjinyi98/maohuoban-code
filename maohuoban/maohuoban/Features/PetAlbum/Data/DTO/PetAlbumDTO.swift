import Foundation

// PetAlbumDTO 用户级宠物相册接口 DTO 命名空间
// 核心职责：
// - 承接后端用户相册 JSON 响应和请求体
// - 提供 DTO 到展示模型的映射
// - 将 pet_id 解析为可选来源宠物字段
enum PetAlbumDTO {
    struct AlbumListData: Decodable {
        let items: [AlbumData]
        let nextCursor: String?

        enum CodingKeys: String, CodingKey {
            case items
            case nextCursor = "next_cursor"
        }
    }

    struct AlbumDetailData: Decodable {
        let album: AlbumData
    }

    struct AlbumData: Decodable, Equatable {
        let id: String
        let petID: String?
        let ownerUserID: String
        let title: String
        let description: String?
        let isPrivate: Bool
        let isPinned: Bool
        let coverAssetID: String?
        let coverURL: String?
        let photoCount: Int
        let archivedAt: String?
        let createdAt: String
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case petID = "pet_id"
            case ownerUserID = "owner_user_id"
            case title
            case description
            case isPrivate = "is_private"
            case isPinned = "is_pinned"
            case coverAssetID = "cover_asset_id"
            case coverURL = "cover_url"
            case photoCount = "photo_count"
            case archivedAt = "archived_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }

        func summary() -> PetAlbumSummary {
            return PetAlbumSummary(
                id: id,
                title: title,
                petName: "全部宠物",
                updatedText: Self.displayText(from: updatedAt),
                photoCount: photoCount,
                coverImageAssetName: coverURL ?? "photo.on.rectangle.angled",
                isPrivate: isPrivate,
                isPinned: isPinned
            )
        }

        private static func displayText(from utcString: String) -> String {
            guard let date = MHBUTCDateDisplayFormatter.date(fromUTCString: utcString) else {
                return "刚刚更新"
            }
            return MHBUTCDateDisplayFormatter.localShortText(from: date)
        }
    }

    struct AssetListData: Decodable {
        let items: [AssetData]
        let nextCursor: String?

        enum CodingKeys: String, CodingKey {
            case items
            case nextCursor = "next_cursor"
        }
    }

    struct AssetData: Decodable, Equatable {
        let id: String
        let albumID: String
        let petID: String?
        let assetID: String
        let assetURL: String
        let addedByUserID: String
        let caption: String?
        let width: Int?
        let height: Int?
        let sortTakenAt: String
        let removedAt: String?
        let createdAt: String
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case albumID = "album_id"
            case petID = "pet_id"
            case assetID = "asset_id"
            case assetURL = "asset_url"
            case addedByUserID = "added_by_user_id"
            case caption
            case width
            case height
            case sortTakenAt = "sort_taken_at"
            case removedAt = "removed_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }

        func asset(localIdentifier: String? = nil) -> PetAlbumAsset {
            PetAlbumAsset(
                id: id,
                albumID: albumID,
                imageAssetName: assetURL,
                pixelSize: PetAlbumImageSize(width: width, height: height),
                source: .userUpload,
                caption: caption,
                localIdentifier: localIdentifier
            )
        }
    }

    struct CreateAlbumRequest: Encodable {
        let title: String
        let description: String?
        let isPrivate: Bool
        let isPinned: Bool
        let coverAssetID: String?

        init(draft: PetAlbumCreateDraft) {
            title = draft.normalizedName
            description = nil
            isPrivate = draft.isPrivate
            isPinned = false
            coverAssetID = draft.coverAssetID
        }

        enum CodingKeys: String, CodingKey {
            case title
            case description
            case isPrivate = "is_private"
            case isPinned = "is_pinned"
            case coverAssetID = "cover_asset_id"
        }
    }

    struct UpdateAlbumRequest: Encodable {
        let title: String
        let description: String?
        let isPrivate: Bool

        init(draft: PetAlbumCreateDraft) {
            title = draft.normalizedName
            description = nil
            isPrivate = draft.isPrivate
        }

        enum CodingKeys: String, CodingKey {
            case title
            case description
            case isPrivate = "is_private"
        }
    }

    struct UpdatePinnedRequest: Encodable {
        let isPinned: Bool

        enum CodingKeys: String, CodingKey {
            case isPinned = "is_pinned"
        }
    }

    struct AddAssetRequest: Encodable {
        let assetID: String
        let caption: String?

        enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
            case caption
        }
    }
}

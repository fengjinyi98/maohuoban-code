import Foundation

// ProfileRoute 我的页导航路由
// 核心职责：
// - 描述我的 Tab 内部系统导航目标
// - 为我的动态、关注粉丝、收藏夹、设置、宠物档案、相册和话题页面提供稳定 Hashable 值
enum ProfileRoute: Hashable {
    case myPets
    case createPet
    case editPetProfile(PetProfileEditContext)
    case posts
    case following
    case followers
    case replies
    case favoriteFolders
    case createFavoriteFolder
    case favoriteFolderContent(folderID: String)
    case badges(selectedBadgeID: String?)
    case feedDetail(postID: String)
    case petAlbumList
    case createPetAlbum
    case petAlbumDetail(albumID: String)
    case followedTopics
    case topicDetail(topicID: String)
    case topicFeedDetail(postID: String)
    case topicComposer(seedTopicID: String?)
    case settings
    case accountSecurity
    case generalSettings
    case notificationSettings
    case privacySettings
    case storageSpace
    case addressList
    case accountManagement
    case setPassword
    case realNameAuth
    case officialVerification
    case deviceManagement
    case deviceDetail(deviceID: String)
    case darkMode
    case onlineStatus
    case dmPrivacy
    case collectionPrivacy
    case evaluationPrivacy
    case findMeWay
    case relationshipPrivacy
    case blacklist
    case systemPermissions
    case personalization
}

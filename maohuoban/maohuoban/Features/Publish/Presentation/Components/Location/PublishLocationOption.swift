import Foundation

// PublishLocationOption 地点候选模型
// 核心职责：
// - 承载地点选择器的展示文案
// - 为列表选中态和草稿回写提供稳定标识
struct PublishLocationOption: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let distance: String
    let location: PublishLocation

    init(searchResult: MHBLocationSearchResult) {
        self.id = searchResult.id
        self.title = searchResult.title
        self.subtitle = searchResult.subtitle
        self.distance = searchResult.distanceText
        self.location = PublishLocation(
            displayName: searchResult.title,
            poiName: searchResult.title,
            formattedAddress: searchResult.subtitle,
            country: searchResult.country,
            province: searchResult.province,
            city: searchResult.city,
            district: searchResult.district,
            latitude: searchResult.latitude,
            longitude: searchResult.longitude
        )
    }
}

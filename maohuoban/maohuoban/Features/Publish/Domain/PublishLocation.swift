import Foundation

// PublishLocation 发布地点模型
// 核心职责：
// - 保存发布时的结构化地点信息
// - 为地点展示与后续接口序列化提供统一模型
struct PublishLocation: Sendable, Equatable, Hashable {
    let displayName: String
    let poiName: String?
    let formattedAddress: String?
    let country: String?
    let province: String?
    let city: String?
    let district: String?
    let latitude: Double?
    let longitude: Double?

    init(
        displayName: String,
        poiName: String? = nil,
        formattedAddress: String? = nil,
        country: String? = nil,
        province: String? = nil,
        city: String? = nil,
        district: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.displayName = displayName
        self.poiName = poiName
        self.formattedAddress = formattedAddress
        self.country = country
        self.province = province
        self.city = city
        self.district = district
        self.latitude = latitude
        self.longitude = longitude
    }
}

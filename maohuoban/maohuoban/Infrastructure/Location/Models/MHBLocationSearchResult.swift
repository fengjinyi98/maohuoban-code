import Foundation

// MHBLocationSearchResult 地点搜索结果
// 核心职责：
// - 承载地点搜索列表展示字段和结构化坐标信息
// - 为发布页地点选择与后续序列化提供稳定结果模型
struct MHBLocationSearchResult: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let distanceText: String
    let distanceMeters: Double?
    let country: String?
    let province: String?
    let city: String?
    let district: String?
    let latitude: Double?
    let longitude: Double?
}

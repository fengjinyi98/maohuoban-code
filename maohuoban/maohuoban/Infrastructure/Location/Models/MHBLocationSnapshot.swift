import Foundation

// MHBLocationSnapshot 设备位置快照
// 核心职责：
// - 保存定位解析后的结构化行政区字段
// - 提供首页和后续业务复用的展示名称
struct MHBLocationSnapshot: Equatable, Sendable {
    let country: String?
    let province: String?
    let city: String?
    let district: String?
    let latitude: Double?
    let longitude: Double?

    var displayName: String? {
        if isMunicipality {
            return Self.nonEmpty(district) ?? Self.nonEmpty(city) ?? Self.nonEmpty(province)
        }
        return Self.nonEmpty(city) ?? Self.nonEmpty(province) ?? Self.nonEmpty(district)
    }

    private var isMunicipality: Bool {
        let names = [
            Self.nonEmpty(province),
            Self.nonEmpty(city)
        ]
        let municipalities: Set<String> = ["北京", "上海", "天津", "重庆"]
        return names.contains { name in
            guard let name else { return false }
            return municipalities.contains(name)
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

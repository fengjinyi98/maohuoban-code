import CoreLocation
import Foundation
import MapKit

// MHBLocationSearchScope 地点搜索范围
// 核心职责：
// - 区分当前位置附近搜索与全国范围搜索
enum MHBLocationSearchScope: Sendable, Equatable {
    case nearby
    case nationwide
}

// MHBLocationSearchService 地点搜索服务
// 核心职责：
// - 基于 MapKit Local Search 搜索当前位置附近地点
// - 将地图结果转换为发布页可消费的结构化地点结果
struct MHBLocationSearchService: Sendable {
    func nearby(around location: CLLocation?) async -> [MHBLocationSearchResult] {
        guard let location else {
            return []
        }

        do {
            let request = MKLocalPointsOfInterestRequest(
                center: location.coordinate,
                radius: min(3000, MKLocalPointsOfInterestRequest.maxRadius)
            )
            let response = try await MKLocalSearch(request: request).start()
            let nearbyItems = response.mapItems.compactMap { mapItem in
                makeSearchResult(from: mapItem, referenceLocation: location)
            }
            if nearbyItems.isEmpty == false {
                return sort(results: nearbyItems)
            }
        } catch {
            return []
        }
        return []
    }

    func search(
        query: String,
        near location: CLLocation?,
        scope: MHBLocationSearchScope
    ) async -> [MHBLocationSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            return []
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery
        request.resultTypes = [.pointOfInterest, .address]

        if scope == .nearby, let location {
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 8000,
                longitudinalMeters: 8000
            )
            request.regionPriority = .required
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            let results = response.mapItems.compactMap { mapItem in
                makeSearchResult(from: mapItem, referenceLocation: location)
            }
            return sort(results: results)
        } catch {
            return []
        }
    }

    private func makeSearchResult(
        from mapItem: MKMapItem,
        referenceLocation: CLLocation?
    ) -> MHBLocationSearchResult? {
        let itemLocation = mapItem.location

        let fullAddress = mapItem.addressRepresentations?.fullAddress(
            includingRegion: true,
            singleLine: true
        ) ?? mapItem.address?.fullAddress
        let addressComponents = MHBLocationSearchAddressComponents.parse(fullAddress)
        let distanceMeters = referenceLocation.flatMap { center in
            center.distance(from: itemLocation)
        }
        let distanceText = distanceMeters.map(Self.distanceText(from:)) ?? ""
        let title = mapItem.name ?? fullAddress ?? "未知地点"
        let resolvedSubtitle = fullAddress ?? addressComponents.displayText ?? ""
        let city = Self.sanitizedAdministrativeName(mapItem.addressRepresentations?.cityName)
            ?? addressComponents.city
        let province = addressComponents.province
        let country = Self.sanitizedOptionalText(mapItem.addressRepresentations?.regionName)
            ?? addressComponents.country

        return MHBLocationSearchResult(
            id: Self.makeIdentifier(
                coordinate: itemLocation.coordinate,
                title: title,
                subtitle: resolvedSubtitle
            ),
            title: title,
            subtitle: resolvedSubtitle,
            distanceText: distanceText,
            distanceMeters: distanceMeters,
            country: country,
            province: province,
            city: city,
            district: addressComponents.district,
            latitude: itemLocation.coordinate.latitude,
            longitude: itemLocation.coordinate.longitude
        )
    }

    private func sort(results: [MHBLocationSearchResult]) -> [MHBLocationSearchResult] {
        results.sorted { lhs, rhs in
            let lhsDistance = lhs.distanceMeters ?? .greatestFiniteMagnitude
            let rhsDistance = rhs.distanceMeters ?? .greatestFiniteMagnitude

            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            if lhs.title != rhs.title {
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            if lhs.subtitle != rhs.subtitle {
                return lhs.subtitle.localizedStandardCompare(rhs.subtitle) == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }

    private static func distanceText(from meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        }
        return "\(Int(meters.rounded()))m"
    }

    private static func makeIdentifier(
        coordinate: CLLocationCoordinate2D,
        title: String,
        subtitle: String
    ) -> String {
        [
            "\(coordinate.latitude),\(coordinate.longitude)",
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        .joined(separator: "|")
    }

    fileprivate static func sanitizedAdministrativeName(_ value: String?) -> String? {
        guard var name = sanitizedOptionalText(value) else { return nil }
        let suffixes = ["市辖区", "地区", "自治州", "自治区", "盟", "省", "市"]

        for suffix in suffixes where name.hasSuffix(suffix) {
            let trimmed = String(name.dropLast(suffix.count))
            if trimmed.isEmpty == false {
                name = trimmed
            }
            break
        }

        return name
    }

    fileprivate static func sanitizedDistrictName(_ value: String?) -> String? {
        guard let name = sanitizedOptionalText(value), name != "市辖区" else {
            return nil
        }
        return name
    }

    fileprivate static func sanitizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MHBLocationSearchAddressComponents 地点搜索地址组件
// 核心职责：
// - 从 MapKit 格式化地址中解析行政区字段
// - 为地点搜索结果补齐后续发布所需结构化字段
private struct MHBLocationSearchAddressComponents {
    let country: String?
    let province: String?
    let city: String?
    let district: String?

    var displayText: String? {
        [
            district,
            city,
            province,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .nilIfEmpty
    }

    static func parse(_ value: String?) -> Self {
        guard let address = normalizedAddressText(value), address.hasPrefix("中国") else {
            return Self(country: nil, province: nil, city: nil, district: nil)
        }

        var remaining = String(address.dropFirst("中国".count))
        var country: String? = "中国"
        var province: String?
        var city: String?
        var district: String?

        if let municipality = extractMunicipality(from: remaining) {
            province = MHBLocationSearchService.sanitizedAdministrativeName(municipality)
            city = province
            remaining = String(remaining.dropFirst(municipality.count))
            district = extractAdministrativeComponent(
                from: remaining,
                suffixes: ["新区", "自治县", "区", "县", "市", "旗"]
            ).flatMap(MHBLocationSearchService.sanitizedDistrictName)
        } else if let provinceComponent = extractAdministrativeComponent(
            from: remaining,
            suffixes: ["特别行政区", "自治区", "省"]
        ) {
            province = MHBLocationSearchService.sanitizedAdministrativeName(provinceComponent)
            remaining = String(remaining.dropFirst(provinceComponent.count))

            if let cityComponent = extractAdministrativeComponent(
                from: remaining,
                suffixes: ["自治州", "地区", "盟", "市"]
            ) {
                city = MHBLocationSearchService.sanitizedAdministrativeName(cityComponent)
                remaining = String(remaining.dropFirst(cityComponent.count))
            }

            district = extractAdministrativeComponent(
                from: remaining,
                suffixes: ["新区", "自治县", "区", "县", "市", "旗"]
            ).flatMap(MHBLocationSearchService.sanitizedDistrictName)
        }

        if country == nil, province != nil || city != nil || district != nil {
            country = "中国"
        }

        return Self(
            country: country,
            province: province,
            city: city,
            district: district
        )
    }

    private static func extractMunicipality(from value: String) -> String? {
        ["北京市", "上海市", "天津市", "重庆市"].first { value.hasPrefix($0) }
    }

    private static func extractAdministrativeComponent(from value: String, suffixes: [String]) -> String? {
        let matches = suffixes.compactMap { suffix -> Range<String.Index>? in
            value.range(of: suffix)
        }
        guard let match = matches.min(by: { $0.upperBound < $1.upperBound }) else {
            return nil
        }
        return String(value[..<match.upperBound])
    }

    private static func normalizedAddressText(_ value: String?) -> String? {
        guard let value else { return nil }
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",，、"))
        let normalized = value
            .components(separatedBy: separators)
            .joined()
        return normalized.isEmpty ? nil : normalized
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

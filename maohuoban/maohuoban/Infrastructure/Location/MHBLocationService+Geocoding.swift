import CoreLocation
import Foundation
import MapKit

// MHBLocationService+Geocoding 反向地理编码
// 核心职责：
// - 将坐标解析为国家、省、市、区结构
// - 清洗行政区常见后缀以获得稳定展示名称
extension MHBLocationService {
    // reverseGeocode 解析当前位置坐标
    // 核心职责：
    // - 使用 iOS 26+ MapKit 反向地理编码接口
    // - 将结果映射为首页和业务可复用的位置快照
    func reverseGeocode(location: CLLocation) async {
        MHBLocationDiagnostics.geocodeStarted(location)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            errorMessage = "当前位置无效"
            MHBLocationDiagnostics.geocodeRequestInvalid(location)
            return
        }

        do {
            request.preferredLocale = Locale(identifier: "zh_Hans_CN")
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else {
                errorMessage = "未解析到当前位置"
                MHBLocationDiagnostics.geocodeEmptyResult()
                return
            }

            let components = makeChinaAddressComponents(from: mapItem)
            let locationSnapshot = MHBLocationSnapshot(
                country: components.country,
                province: components.province,
                city: components.city,
                district: components.district,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            snapshot = locationSnapshot
            MHBLocationDiagnostics.geocodeSucceeded(
                mapItemsCount: mapItems.count,
                addressSummary: makeDiagnosticSummary(from: mapItem),
                snapshot: locationSnapshot
            )
        } catch {
            errorMessage = "地址解析失败: \(error.localizedDescription)"
            MHBLocationDiagnostics.geocodeFailed(error)
        }
    }

    // makeChinaAddressComponents 转换地图地址
    // 核心职责：
    // - 从 MapKit 地址表示提取中国行政区字段
    // - 保留直辖市区级展示所需字段
    private func makeChinaAddressComponents(from mapItem: MKMapItem) -> MHBChinaAddressComponents {
        let representations = mapItem.addressRepresentations
        let fullAddress = representations?.fullAddress(includingRegion: true, singleLine: true)
            ?? mapItem.address?.fullAddress
        let parsed = parseChinaAddress(fullAddress)
        let city = sanitizedAdministrativeName(representations?.cityName) ?? parsed.city
        let country = sanitizedOptionalText(representations?.regionName) ?? parsed.country

        return MHBChinaAddressComponents(
            country: country,
            province: parsed.province,
            city: city,
            district: parsed.district
        )
    }

    // makeDiagnosticSummary 生成地址诊断摘要
    // 核心职责：
    // - 提取地址解析所需的关键可观测字段
    // - 避免记录完整街道地址
    private func makeDiagnosticSummary(from mapItem: MKMapItem) -> MHBLocationAddressDiagnosticSummary {
        let representations = mapItem.addressRepresentations
        let fullAddress = representations?.fullAddress(includingRegion: true, singleLine: true)
            ?? mapItem.address?.fullAddress

        return MHBLocationAddressDiagnosticSummary(
            hasAddressRepresentations: representations != nil,
            prefixKind: addressPrefixKind(fullAddress),
            fullAddressLength: fullAddress?.count ?? 0,
            representationCity: sanitizedOptionalText(representations?.cityName),
            representationRegion: sanitizedOptionalText(representations?.regionName)
        )
    }

    // parseChinaAddress 解析中文完整地址
    // 核心职责：
    // - 从格式化地址中拆出省、市、区
    // - 支持直辖市直接解析区名
    private func parseChinaAddress(_ value: String?) -> MHBChinaAddressComponents {
        guard let address = normalizedAddressText(value), address.hasPrefix("中国") else {
            return MHBChinaAddressComponents()
        }

        var remaining = String(address.dropFirst("中国".count))
        var country: String? = "中国"
        var province: String?
        var city: String?
        var district: String?

        if let municipality = extractMunicipality(from: remaining) {
            province = sanitizedAdministrativeName(municipality)
            city = province
            remaining = String(remaining.dropFirst(municipality.count))
            district = extractAdministrativeComponent(
                from: remaining,
                suffixes: ["新区", "自治县", "区", "县", "市", "旗"]
            ).flatMap(sanitizedDistrictName)
        } else if let provinceComponent = extractAdministrativeComponent(
            from: remaining,
            suffixes: ["特别行政区", "自治区", "省"]
        ) {
            province = sanitizedAdministrativeName(provinceComponent)
            remaining = String(remaining.dropFirst(provinceComponent.count))

            if let cityComponent = extractAdministrativeComponent(
                from: remaining,
                suffixes: ["自治州", "地区", "盟", "市"]
            ) {
                city = sanitizedAdministrativeName(cityComponent)
                remaining = String(remaining.dropFirst(cityComponent.count))
            }

            district = extractAdministrativeComponent(
                from: remaining,
                suffixes: ["新区", "自治县", "区", "县", "市", "旗"]
            ).flatMap(sanitizedDistrictName)
        }

        if country == nil, province != nil || city != nil || district != nil {
            country = "中国"
        }

        return MHBChinaAddressComponents(
            country: country,
            province: province,
            city: city,
            district: district
        )
    }

    // extractMunicipality 提取直辖市
    // 核心职责：
    // - 识别中文完整地址中的直辖市前缀
    // - 为后续区级展示保留解析边界
    private func extractMunicipality(from value: String) -> String? {
        ["北京市", "上海市", "天津市", "重庆市"].first { value.hasPrefix($0) }
    }

    private func addressPrefixKind(_ value: String?) -> String {
        guard let address = normalizedAddressText(value) else {
            return "empty"
        }
        if address.hasPrefix("中国") {
            return "china"
        }
        if extractMunicipality(from: address) != nil {
            return "municipality"
        }
        if extractAdministrativeComponent(from: address, suffixes: ["特别行政区", "自治区", "省"]) != nil {
            return "province"
        }
        return "other"
    }

    // extractAdministrativeComponent 提取行政区片段
    // 核心职责：
    // - 按最早出现的行政后缀截取地址片段
    // - 兼容省、市、区多级解析
    private func extractAdministrativeComponent(from value: String, suffixes: [String]) -> String? {
        let matches = suffixes.compactMap { suffix -> Range<String.Index>? in
            value.range(of: suffix)
        }
        guard let match = matches.min(by: { $0.upperBound < $1.upperBound }) else {
            return nil
        }
        return String(value[..<match.upperBound])
    }

    private func sanitizedAdministrativeName(_ value: String?) -> String? {
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

    private func sanitizedDistrictName(_ value: String?) -> String? {
        guard let name = sanitizedOptionalText(value), name != "市辖区" else {
            return nil
        }
        return name
    }

    // normalizedAddressText 标准化地址文本
    // 核心职责：
    // - 移除格式化地址中的空白和分隔符
    // - 为中文行政区解析提供稳定输入
    private func normalizedAddressText(_ value: String?) -> String? {
        guard let value else { return nil }
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",，、"))
        let normalized = value
            .components(separatedBy: separators)
            .joined()
        return normalized.isEmpty ? nil : normalized
    }

    private func sanitizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MHBChinaAddressComponents 中国地址组件
// 核心职责：
// - 承载 MapKit 格式化地址解析结果
// - 降低反向编码服务内部参数传递复杂度
private struct MHBChinaAddressComponents {
    let country: String?
    let province: String?
    let city: String?
    let district: String?

    init(
        country: String? = nil,
        province: String? = nil,
        city: String? = nil,
        district: String? = nil
    ) {
        self.country = country
        self.province = province
        self.city = city
        self.district = district
    }
}

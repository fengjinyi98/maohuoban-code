import Foundation

// ProfileUserEditRegionDictionary 用户资料地区字典
// 核心职责：
// - 承载前端本地地区选择所需的省市区树
// - 为后续替换后端地区字典保留稳定结构
struct ProfileUserEditRegionDictionary: Equatable {
    // Country 国家节点
    // 核心职责：
    // - 表达地区字典中的国家层级
    // - 聚合省级节点集合
    struct Country: Equatable, Hashable, Identifiable {
        let code: String
        let name: String
        let provinces: [Province]

        var id: String { code }
    }

    // Province 省级节点
    // 核心职责：
    // - 表达地区字典中的省级层级
    // - 聚合城市节点集合
    struct Province: Equatable, Hashable, Identifiable {
        let code: String
        let name: String
        let cities: [City]

        var id: String { code }
    }

    // City 城市节点
    // 核心职责：
    // - 表达地区字典中的城市层级
    // - 聚合区县节点集合
    struct City: Equatable, Hashable, Identifiable {
        let code: String
        let name: String
        let districts: [District]

        var id: String { code }
    }

    // District 区县节点
    // 核心职责：
    // - 表达地区字典中的区县层级
    // - 作为地区选择的最终叶子节点
    struct District: Equatable, Hashable, Identifiable {
        let code: String
        let name: String

        var id: String { code }
    }

    let countries: [Country]

    static let frontEndFallback = ProfileUserEditRegionDictionary(
        countries: [
            Country(
                code: "CN",
                name: "中国",
                provinces: [
                    Province(
                        code: "310000",
                        name: "上海市",
                        cities: [
                            City(
                                code: "310100",
                                name: "上海市",
                                districts: [
                                    District(code: "310115", name: "浦东新区"),
                                    District(code: "310101", name: "黄浦区"),
                                    District(code: "310104", name: "徐汇区")
                                ]
                            )
                        ]
                    ),
                    Province(
                        code: "110000",
                        name: "北京市",
                        cities: [
                            City(
                                code: "110100",
                                name: "北京市",
                                districts: [
                                    District(code: "110105", name: "朝阳区"),
                                    District(code: "110108", name: "海淀区"),
                                    District(code: "110101", name: "东城区")
                                ]
                            )
                        ]
                    ),
                    Province(
                        code: "330000",
                        name: "浙江省",
                        cities: [
                            City(
                                code: "330100",
                                name: "杭州市",
                                districts: [
                                    District(code: "330106", name: "西湖区"),
                                    District(code: "330108", name: "滨江区"),
                                    District(code: "330110", name: "余杭区")
                                ]
                            ),
                            City(
                                code: "330300",
                                name: "温州市",
                                districts: [
                                    District(code: "330302", name: "鹿城区"),
                                    District(code: "330303", name: "龙湾区"),
                                    District(code: "330304", name: "瓯海区")
                                ]
                            )
                        ]
                    ),
                    Province(
                        code: "440000",
                        name: "广东省",
                        cities: [
                            City(
                                code: "440100",
                                name: "广州市",
                                districts: [
                                    District(code: "440106", name: "天河区"),
                                    District(code: "440105", name: "海珠区"),
                                    District(code: "440103", name: "荔湾区")
                                ]
                            ),
                            City(
                                code: "440300",
                                name: "深圳市",
                                districts: [
                                    District(code: "440305", name: "南山区"),
                                    District(code: "440304", name: "福田区"),
                                    District(code: "440306", name: "宝安区")
                                ]
                            )
                        ]
                    )
                ]
            )
        ]
    )
}

// ProfileUserEditRegionSelection 用户资料地区选择草稿
// 核心职责：
// - 承载编辑资料过程中当前选中的国家、省、市、区
// - 为地区选择页和资料编辑页提供统一展示文案
struct ProfileUserEditRegionSelection: Equatable, Hashable, Sendable {
    let countryCode: String
    let countryName: String
    let provinceCode: String?
    let provinceName: String?
    let cityCode: String?
    let cityName: String?
    let districtCode: String?
    let districtName: String?

    init(
        countryCode: String = "CN",
        countryName: String = "中国",
        provinceCode: String? = nil,
        provinceName: String? = nil,
        cityCode: String? = nil,
        cityName: String? = nil,
        districtCode: String? = nil,
        districtName: String? = nil
    ) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.provinceCode = provinceCode
        self.provinceName = provinceName
        self.cityCode = cityCode
        self.cityName = cityName
        self.districtCode = districtCode
        self.districtName = districtName
    }

    var displayText: String {
        let parts: [String]
        if let districtName, districtName.isEmpty == false {
            if isDirectControlledMunicipality {
                parts = [cityName ?? provinceName, districtName].compactMap { $0 }
            } else {
                parts = [provinceName, districtName].compactMap { $0 }
            }
        } else if let cityName, cityName.isEmpty == false {
            if isDirectControlledMunicipality {
                parts = [cityName]
            } else {
                parts = [provinceName, cityName].compactMap { $0 }
            }
        } else {
            parts = [provinceName ?? countryName]
        }

        var deduplicated: [String] = []
        for part in parts where part.isEmpty == false && deduplicated.last != part {
            deduplicated.append(part)
        }
        return deduplicated.joined(separator: " ")
    }

    func selectingProvince(
        _ province: ProfileUserEditRegionDictionary.Province,
        in country: ProfileUserEditRegionDictionary.Country
    ) -> Self {
        .init(
            countryCode: country.code,
            countryName: country.name,
            provinceCode: province.code,
            provinceName: province.name
        )
    }

    func selectingCity(_ city: ProfileUserEditRegionDictionary.City) -> Self {
        .init(
            countryCode: countryCode,
            countryName: countryName,
            provinceCode: provinceCode,
            provinceName: provinceName,
            cityCode: city.code,
            cityName: city.name
        )
    }

    func selectingDistrict(_ district: ProfileUserEditRegionDictionary.District) -> Self {
        .init(
            countryCode: countryCode,
            countryName: countryName,
            provinceCode: provinceCode,
            provinceName: provinceName,
            cityCode: cityCode,
            cityName: cityName,
            districtCode: district.code,
            districtName: district.name
        )
    }

    private var isDirectControlledMunicipality: Bool {
        guard let provinceName else { return false }
        return Self.directControlledMunicipalityNames.contains(provinceName)
    }

    private static let directControlledMunicipalityNames: Set<String> = [
        "北京市",
        "天津市",
        "上海市",
        "重庆市"
    ]
}

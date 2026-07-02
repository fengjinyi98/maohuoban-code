import XCTest
@testable import maohuoban

// ProfileUserEditDraftTests 用户资料编辑草稿测试
// 核心职责：
// - 固化用户资料编辑页的前端本地草稿展示规则
// - 约束性别、地区和生日字段的纯展示映射
@MainActor
final class ProfileUserEditDraftTests: XCTestCase {
    func testGenderOptionMapsStoredValuesToDisplayTitle() {
        XCTAssertEqual(ProfileUserEditGenderOption.displayTitle(for: "female"), "女")
        XCTAssertEqual(ProfileUserEditGenderOption.fromStoredValue("男")?.rawValue, "male")
        XCTAssertEqual(ProfileUserEditGenderOption.displayTitle(for: "unknown"), "保密")
    }

    func testRegularProvinceRegionDisplayUsesProvinceAndDistrict() {
        let selection = ProfileUserEditRegionSelection(
            countryName: "中国",
            provinceName: "浙江省",
            cityName: "温州市",
            districtName: "鹿城区"
        )

        XCTAssertEqual(selection.displayText, "浙江省 鹿城区")
    }

    func testDirectControlledMunicipalityDisplayUsesCityAndDistrict() {
        let selection = ProfileUserEditRegionSelection(
            countryName: "中国",
            provinceName: "北京市",
            cityName: "北京市",
            districtName: "朝阳区"
        )

        XCTAssertEqual(selection.displayText, "北京市 朝阳区")
    }

    func testBirthdayDateCodecRoundTripsChinaDateText() throws {
        let date = try XCTUnwrap(ProfileUserEditBirthdayDateCodec.date(from: "1999-12-31"))

        XCTAssertEqual(ProfileUserEditBirthdayDateCodec.string(from: date), "1999-12-31")
        XCTAssertNil(ProfileUserEditBirthdayDateCodec.date(from: ""))
    }
}

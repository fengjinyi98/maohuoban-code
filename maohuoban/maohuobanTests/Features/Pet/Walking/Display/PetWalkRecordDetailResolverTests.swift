import XCTest
@testable import maohuoban

// PetWalkRecordDetailResolverTests 遛弯记录详情解析测试
// 核心职责：
// - 固化全部记录列表中遛弯条目到遛弯详情页的数据映射
// - 防止夜间散步记录回退到通用记录占位页
final class PetWalkRecordDetailResolverTests: XCTestCase {
    func testNightWalkRecordResolvesToWalkHistoryDetailRecord() {
        let record = PetWalkRecordDetailResolver.record(for: "record-2026-05-walk")

        XCTAssertEqual(record?.id, "record-2026-05-walk")
        XCTAssertEqual(record?.petID, "pet-mochi")
        XCTAssertEqual(record?.dateText, "5月20日")
        XCTAssertEqual(record?.timeRangeText, "20:20 - 20:52")
        XCTAssertEqual(record?.durationMinutes, 32)
        XCTAssertEqual(record?.distanceKilometers ?? 0, 2.3, accuracy: 0.01)
        XCTAssertEqual(record?.routePreview, .curve)
    }
}

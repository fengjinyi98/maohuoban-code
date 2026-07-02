import CoreLocation
import XCTest
@testable import maohuoban

// PetWalkRouteRecorderTests 遛弯轨迹记录测试
// 核心职责：
// - 固化遛弯轨迹累计规则
// - 防止暂停和低精度定位污染运动指标
final class PetWalkRouteRecorderTests: XCTestCase {
    @MainActor
    func testRecordingAccumulatesDistanceFromAcceptedPoints() {
        var recorder = PetWalkRouteRecorder()
        let startedAt = Date(timeIntervalSince1970: 0)

        recorder.start(at: startedAt)
        recorder.append(
            makePoint(latitude: 31.2304, longitude: 121.4737, timestamp: startedAt)
        )
        recorder.append(
            makePoint(latitude: 31.2314, longitude: 121.4737, timestamp: startedAt.addingTimeInterval(120))
        )

        XCTAssertEqual(recorder.points.count, 2)
        XCTAssertEqual(recorder.metrics.elapsedSeconds, 120, accuracy: 0.1)
        XCTAssertGreaterThan(recorder.metrics.distanceMeters, 100)
    }

    @MainActor
    func testPausedSessionDoesNotAccumulateNewPoints() {
        var recorder = PetWalkRouteRecorder()
        let startedAt = Date(timeIntervalSince1970: 0)

        recorder.start(at: startedAt)
        recorder.append(
            makePoint(latitude: 31.2304, longitude: 121.4737, timestamp: startedAt)
        )
        recorder.pause(at: startedAt.addingTimeInterval(60))
        recorder.append(
            makePoint(latitude: 31.2324, longitude: 121.4737, timestamp: startedAt.addingTimeInterval(120))
        )

        XCTAssertEqual(recorder.points.count, 1)
        XCTAssertEqual(recorder.metrics.elapsedSeconds, 60, accuracy: 0.1)
    }

    @MainActor
    func testLowAccuracyPointIsIgnored() {
        var recorder = PetWalkRouteRecorder()
        let startedAt = Date(timeIntervalSince1970: 0)

        recorder.start(at: startedAt)
        recorder.append(
            makePoint(
                latitude: 31.2304,
                longitude: 121.4737,
                horizontalAccuracy: 80,
                timestamp: startedAt
            )
        )

        XCTAssertTrue(recorder.points.isEmpty)
        XCTAssertEqual(recorder.metrics.distanceMeters, 0, accuracy: 0.1)
    }

    private func makePoint(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        horizontalAccuracy: CLLocationAccuracy = 8,
        timestamp: Date
    ) -> PetWalkRoutePoint {
        PetWalkRoutePoint(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            horizontalAccuracy: horizontalAccuracy,
            timestamp: timestamp
        )
    }
}

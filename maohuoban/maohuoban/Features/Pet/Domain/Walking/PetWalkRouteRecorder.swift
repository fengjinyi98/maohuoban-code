import CoreLocation
import Foundation

// PetWalkSessionPhase 遛弯会话状态
// 核心职责：
// - 表达遛弯记录的操作阶段
// - 为页面按钮状态和轨迹累计规则提供统一来源
enum PetWalkSessionPhase: Equatable {
    case ready
    case tracking
    case paused
    case finished
}

// PetWalkRoutePoint 遛弯轨迹点
// 核心职责：
// - 保存一次可用于轨迹绘制的定位采样
// - 携带精度和时间戳用于过滤与指标计算
struct PetWalkRoutePoint: Equatable {
    let coordinate: CLLocationCoordinate2D
    let horizontalAccuracy: CLLocationAccuracy
    let timestamp: Date

    static func == (lhs: PetWalkRoutePoint, rhs: PetWalkRoutePoint) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.horizontalAccuracy == rhs.horizontalAccuracy
            && lhs.timestamp == rhs.timestamp
    }
}

// PetWalkMetrics 遛弯指标
// 核心职责：
// - 汇总轨迹距离、累计时长和热量估算
// - 为遛弯地图面板提供稳定展示数据
struct PetWalkMetrics: Equatable {
    var distanceMeters: CLLocationDistance = 0
    var elapsedSeconds: TimeInterval = 0

    var distanceKilometers: Double {
        distanceMeters / 1_000
    }

    var estimatedCalories: Int {
        max(0, Int((distanceKilometers * 55).rounded()))
    }
}

// PetWalkRouteRecorder 遛弯轨迹记录器
// 核心职责：
// - 过滤低精度定位采样
// - 在 tracking 阶段累计轨迹、距离和时长
struct PetWalkRouteRecorder: Equatable {
    private(set) var phase: PetWalkSessionPhase = .ready
    private(set) var points: [PetWalkRoutePoint] = []
    private(set) var metrics = PetWalkMetrics()

    private var startedAt: Date?
    private var pausedAt: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastAcceptedPoint: PetWalkRoutePoint?

    mutating func start(at date: Date = Date()) {
        phase = .tracking
        startedAt = date
        pausedAt = nil
        pausedDuration = 0
        points = []
        metrics = PetWalkMetrics()
        lastAcceptedPoint = nil
    }

    mutating func pause(at date: Date = Date()) {
        guard phase == .tracking else { return }
        updateElapsed(at: date)
        phase = .paused
        pausedAt = date
    }

    mutating func resume(at date: Date = Date()) {
        guard phase == .paused else { return }
        if let pausedAt {
            pausedDuration += date.timeIntervalSince(pausedAt)
        }
        pausedAt = nil
        phase = .tracking
        updateElapsed(at: date)
    }

    mutating func finish(at date: Date = Date()) {
        updateElapsed(at: date)
        phase = .finished
        pausedAt = nil
    }

    mutating func append(_ point: PetWalkRoutePoint) {
        guard phase == .tracking, accepts(point) else { return }

        if let lastAcceptedPoint {
            let previousLocation = CLLocation(
                latitude: lastAcceptedPoint.coordinate.latitude,
                longitude: lastAcceptedPoint.coordinate.longitude
            )
            let currentLocation = CLLocation(
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude
            )
            metrics.distanceMeters += currentLocation.distance(from: previousLocation)
        }

        points.append(point)
        lastAcceptedPoint = point
        updateElapsed(at: point.timestamp)
    }

    mutating func updateElapsed(at date: Date = Date()) {
        guard let startedAt else { return }
        let rawElapsed = date.timeIntervalSince(startedAt) - pausedDuration
        metrics.elapsedSeconds = max(0, rawElapsed)
    }

    func metrics(at date: Date = Date()) -> PetWalkMetrics {
        guard phase == .tracking, let startedAt else {
            return metrics
        }

        var currentMetrics = metrics
        let rawElapsed = date.timeIntervalSince(startedAt) - pausedDuration
        currentMetrics.elapsedSeconds = max(metrics.elapsedSeconds, rawElapsed)
        return currentMetrics
    }

    private func accepts(_ point: PetWalkRoutePoint) -> Bool {
        guard point.horizontalAccuracy >= 0 && point.horizontalAccuracy <= 30 else {
            return false
        }

        guard let startedAt else { return false }
        return point.timestamp >= startedAt.addingTimeInterval(-1)
    }
}

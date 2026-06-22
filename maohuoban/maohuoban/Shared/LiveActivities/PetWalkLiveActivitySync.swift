import Foundation

// PetWalkLiveActivityPhaseMapping 遛弯实时事件状态映射
// 核心职责：
// - 将 App 内部遛弯阶段转换为实时事件展示状态
// - 隔离 Widget 共享模型对业务 Domain 类型的依赖
extension PetWalkLiveActivityStatus {
    nonisolated init(phase: PetWalkSessionPhase) {
        switch phase {
        case .ready, .tracking:
            self = .tracking
        case .paused:
            self = .paused
        case .finished:
            self = .finished
        }
    }
}

// PetWalkLiveActivityContentFactory 遛弯实时事件内容工厂
// 核心职责：
// - 统一从遛弯业务指标生成 ActivityKit ContentState
// - 确保 App 与 Widget 使用一致的距离、时长和千卡文案
extension PetWalkActivityAttributes.ContentState {
    nonisolated static func make(
        petName: String,
        petAvatarURLString: String? = nil,
        phase: PetWalkSessionPhase,
        metrics: PetWalkMetrics,
        updatedAt: Date = Date()
    ) -> PetWalkActivityAttributes.ContentState {
        PetWalkActivityAttributes.ContentState(
            petName: petName,
            petAvatarURLString: petAvatarURLString,
            status: PetWalkLiveActivityStatus(phase: phase),
            distanceText: PetWalkLiveActivityFormatters.distanceText(from: metrics.distanceKilometers),
            distanceValueText: PetWalkLiveActivityFormatters.distanceValueText(from: metrics.distanceKilometers),
            distanceUnitText: PetWalkLiveActivityFormatters.distanceUnitText,
            elapsedText: PetWalkLiveActivityFormatters.elapsedText(from: metrics.elapsedSeconds),
            caloriesText: PetWalkLiveActivityFormatters.caloriesText(from: metrics.estimatedCalories),
            updatedAt: updatedAt
        )
    }
}

// PetWalkLiveActivitySnapshot 遛弯实时事件同步快照
// 核心职责：
// - 捕获一次可同步到 ActivityKit 的遛弯状态
// - 为同步规划器和控制器提供稳定输入
nonisolated struct PetWalkLiveActivitySnapshot: Equatable {
    let sessionID: String
    let petName: String
    let petAvatarURLString: String?
    let phase: PetWalkSessionPhase
    let metrics: PetWalkMetrics
    let updatedAt: Date

    var attributes: PetWalkActivityAttributes {
        PetWalkActivityAttributes(sessionID: sessionID)
    }

    var state: PetWalkActivityAttributes.ContentState {
        PetWalkActivityAttributes.ContentState.make(
            petName: petName,
            petAvatarURLString: petAvatarURLString,
            phase: phase,
            metrics: metrics,
            updatedAt: updatedAt
        )
    }
}

// PetWalkLiveActivityCommand 遛弯实时事件同步命令
// 核心职责：
// - 表达同步层需要执行的 ActivityKit 操作
// - 携带每次操作所需的 Attributes 和 ContentState
nonisolated struct PetWalkLiveActivityCommand: Equatable {
    let kind: Kind
    let attributes: PetWalkActivityAttributes
    let state: PetWalkActivityAttributes.ContentState

    enum Kind: Equatable {
        case start
        case update
        case end
    }
}

// PetWalkLiveActivitySyncPlanner 遛弯实时事件同步规划器
// 核心职责：
// - 将遛弯状态转换为 start、update、end 命令
// - 防止结束后的重复 end 和 ready 阶段误启动
nonisolated struct PetWalkLiveActivitySyncPlanner {
    private var isActivityActive = false

    mutating func nextCommand(for snapshot: PetWalkLiveActivitySnapshot) -> PetWalkLiveActivityCommand? {
        switch snapshot.phase {
        case .ready:
            return nil
        case .tracking, .paused:
            let commandKind: PetWalkLiveActivityCommand.Kind = isActivityActive ? .update : .start
            isActivityActive = true
            return PetWalkLiveActivityCommand(
                kind: commandKind,
                attributes: snapshot.attributes,
                state: snapshot.state
            )
        case .finished:
            guard isActivityActive else { return nil }
            isActivityActive = false
            return PetWalkLiveActivityCommand(
                kind: .end,
                attributes: snapshot.attributes,
                state: snapshot.state
            )
        }
    }
}

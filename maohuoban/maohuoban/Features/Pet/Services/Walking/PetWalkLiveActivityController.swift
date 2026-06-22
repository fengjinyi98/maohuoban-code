import ActivityKit
import Foundation

// PetWalkLiveActivityController 遛弯实时事件控制器
// 核心职责：
// - 封装 ActivityKit 的启动、更新和结束调用
// - 让遛弯 Store 只提交业务快照，不感知系统实时事件细节
actor PetWalkLiveActivityController {
    private var planner = PetWalkLiveActivitySyncPlanner()
    private var activityID: String?

    func sync(snapshot: PetWalkLiveActivitySnapshot) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let command = planner.nextCommand(for: snapshot) else { return }

        switch command.kind {
        case .start:
            await start(command)
        case .update:
            await update(command)
        case .end:
            await end(command)
        }
    }

    private func start(_ command: PetWalkLiveActivityCommand) async {
        let content = ActivityContent(state: command.state, staleDate: nil)

        do {
            let activity = try Activity<PetWalkActivityAttributes>.request(
                attributes: command.attributes,
                content: content,
                pushType: nil
            )
            activityID = activity.id
        } catch {
            activityID = nil
        }
    }

    private func update(_ command: PetWalkLiveActivityCommand) async {
        let currentActivityID = activityID
        guard let activity = Self.currentActivity(id: currentActivityID) else {
            await start(command)
            return
        }

        await activity.update(ActivityContent(state: command.state, staleDate: nil))
    }

    private func end(_ command: PetWalkLiveActivityCommand) async {
        let currentActivityID = activityID
        guard let activity = Self.currentActivity(id: currentActivityID) else { return }

        await activity.end(
            ActivityContent(state: command.state, staleDate: nil),
            dismissalPolicy: .default
        )
        activityID = nil
    }

    private nonisolated static func currentActivity(
        id activityID: String?
    ) -> Activity<PetWalkActivityAttributes>? {
        guard let activityID else { return nil }
        return Activity<PetWalkActivityAttributes>.activities.first { $0.id == activityID }
    }
}

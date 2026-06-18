import SwiftUI

// PetWriteToastEvent 宠物写入 Toast 事件
// 核心职责：
// - 表达宠物写入状态对应的 Toast 类型和文案
// - 为页面桥接和单元测试提供稳定事件模型
enum PetWriteToastEvent: Equatable {
    case success(String)
    case warning(String)
    case danger(String)
}

// PetWriteToastResolver 宠物写入 Toast 映射器
// 核心职责：
// - 将写入阶段转换为可展示的 Toast 事件
// - 保持页面桥接层不散落状态判断
enum PetWriteToastResolver {
    static func events(
        phase: PetWritePhase,
        successMessage: String?
    ) -> [PetWriteToastEvent] {
        var events: [PetWriteToastEvent] = []

        switch phase {
        case .idle, .submitting:
            break
        case .createdPet,
             .recordedEvent,
             .importedTradePet,
             .updatedPet,
             .deletedPet:
            events.append(.success(successMessage ?? "已保存"))
        case let .failed(message):
            events.append(.danger(message))
        }

        return events
    }
}

// PetWriteToastBridge 宠物写入 Toast 桥接
// 核心职责：
// - 在 SwiftUI 状态变化事件边界触发 Toast 副作用
// - 复用统一映射规则服务多个宠物写入页面
private struct PetWriteToastBridge: ViewModifier {
    let phase: PetWritePhase
    let successMessage: String?
    let toast: MHBToastPresenter

    init(
        phase: PetWritePhase,
        successMessage: String?,
        toast: MHBToastPresenter = MHBToastPresenter()
    ) {
        self.phase = phase
        self.successMessage = successMessage
        self.toast = toast
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: phase) { _, newPhase in
                let events = PetWriteToastResolver.events(
                    phase: newPhase,
                    successMessage: successMessage
                )
                show(events)
            }
    }

    private func show(_ events: [PetWriteToastEvent]) {
        for event in events {
            switch event {
            case let .success(message):
                toast.success(message)
            case let .warning(message):
                toast.warning(message)
            case let .danger(message):
                toast.danger(message)
            }
        }
    }
}

extension View {
    func petWriteToastBridge(
        phase: PetWritePhase,
        successMessage: String?
    ) -> some View {
        modifier(
            PetWriteToastBridge(
                phase: phase,
                successMessage: successMessage
            )
        )
    }
}

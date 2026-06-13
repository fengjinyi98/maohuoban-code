// MHBToastTests.swift Toast组件与管理器测试
// 核心职责：
// - 验证 MHBToast 数据模型的正确初始化与相等性
// - 验证 MHBToastManager 状态流转与自动关闭机制

import Testing
import Foundation
@testable import MaohuobanDesignSystem

@Suite("毛伙伴 Toast 基础设施测试")
struct MHBToastTests {

    @Test("Toast 数据模型默认初始化值正确")
    func toastModelDefaultValues() {
        let toast = MHBToast(title: "提示标题")
        #expect(toast.title == "提示标题")
        #expect(toast.message == "")
        #expect(toast.symbol == "info.circle.fill")
    }

    @Test("Toast 动作按钮相等性判断基于文案")
    func toastActionEquality() {
        let action1 = MHBToastAction(label: "确定", handler: {})
        let action2 = MHBToastAction(label: "确定", handler: {})
        let action3 = MHBToastAction(label: "取消", handler: {})

        #expect(action1 == action2)
        #expect(action1 != action3)
    }

    @MainActor
    @Test("Toast 管理器状态流转逻辑正确")
    func toastManagerLifecycle() {
        let manager = MHBToastManager()
        #expect(manager.activeToast == nil)

        // 1. 展示 Toast
        let toast = MHBToast(title: "成功提示", type: .success)
        manager.show(toast)
        #expect(manager.activeToast == toast)

        // 2. 更新 Toast
        let updatedToast = MHBToast(id: toast.id, title: "成功完成", type: .success)
        manager.show(updatedToast)
        #expect(manager.activeToast?.title == "成功完成")

        // 3. 手动清除
        manager.dismiss()
        #expect(manager.activeToast == nil)
    }

    @MainActor
    @Test("Toast 自动关闭定时任务生效")
    func toastManagerAutoDismiss() async throws {
        let manager = MHBToastManager()
        let toast = MHBToast(title: "短暂提示")

        manager.show(toast)
        #expect(manager.activeToast == toast)

        // 等待定时器执行（MHBToastManager 默认 3 秒自动关闭）
        for _ in 0..<20 {
            if manager.activeToast == nil { break }
            try await Task.sleep(for: .seconds(0.2))
        }

        #expect(manager.activeToast == nil)
    }

    @MainActor
    @Test("Toast 支持单条消息自定义关闭时长")
    func toastManagerUsesCustomDuration() async throws {
        let manager = MHBToastManager()
        let toast = MHBToast(title: "短时提示", duration: 0.2)

        manager.show(toast)
        #expect(manager.activeToast == toast)

        for _ in 0..<15 {
            if manager.activeToast == nil { break }
            try await Task.sleep(for: .seconds(0.05))
        }

        #expect(manager.activeToast == nil)
    }
}

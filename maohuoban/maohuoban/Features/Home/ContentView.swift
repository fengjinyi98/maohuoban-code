//
//  ContentView.swift
//  maohuoban
//
//  Created by fengjinyi on 2026/6/8.
//

import SwiftUI
import MaohuobanDiagnostics
import MaohuobanDesignSystem

// MHBTestButtonLabel 测试按钮标签子视图
// 核心职责：
// - 为 Toast 测试控制台按钮提供高阶风格外观
struct MHBTestButtonLabel: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.12), in: .circle)

            Text(title)
                .font(MHBTheme.Typography.body)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelQuaternary.color)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.separator.color, in: .rect(cornerRadius: MHBTheme.Radius.medium))
    }
}

// ContentView 首页占位根视图
// 核心职责：
// - 验证 App 已接入毛伙伴设计系统
// - 提供 Toast 各种特性的手动触发和真机/模拟器测试入口
struct ContentView: View {
    var onLogout: (() -> Void)?

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: MHBTheme.Spacing.s5) {
                    // 介绍卡片
                    VStack(spacing: MHBTheme.Spacing.s3) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(MHBTheme.ColorToken.primary.color)
                            .imageScale(.large)
                        Text("毛伙伴")
                            .font(MHBTheme.Typography.largeTitle)
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            .accessibilityIdentifier("home.title")
                        Text("让每只毛孩子都拥有自己的主页、时间线和伙伴关系")
                            .font(MHBTheme.Typography.body)
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, MHBTheme.Spacing.s6)
                    }
                    .padding(MHBTheme.Spacing.s6)
                    .background(MHBTheme.ColorToken.card.color, in: .rect(cornerRadius: MHBTheme.Radius.extraExtraLarge))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.extraExtraLarge)
                            .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
                    }

                    // 控制台测试卡片
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                        Text("Toast 基础设施测试")
                            .font(MHBTheme.Typography.headline)
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            .padding(.bottom, MHBTheme.Spacing.s1)

                        VStack(spacing: MHBTheme.Spacing.s3) {
                            if let onLogout {
                                Button(action: onLogout) {
                                    MHBTestButtonLabel(
                                        title: "退出登录",
                                        icon: "rectangle.portrait.and.arrow.right",
                                        color: MHBTheme.ColorToken.danger.color
                                    )
                                }
                                .accessibilityIdentifier("home.logoutButton")
                            }

                            Button(action: triggerSuccessToast) {
                                MHBTestButtonLabel(
                                    title: "成功提示 (Success)",
                                    icon: "checkmark.circle.fill",
                                    color: MHBTheme.ColorToken.success.color
                                )
                            }

                            Button(action: triggerMorphingToast) {
                                MHBTestButtonLabel(
                                    title: "平滑形变 (Loading -> Success)",
                                    icon: "arrow.triangle.2.circlepath",
                                    color: MHBTheme.ColorToken.primary.color
                                )
                            }

                            Button(action: triggerWarningToastWithAction) {
                                MHBTestButtonLabel(
                                    title: "警告提示带操作 (Warning Action)",
                                    icon: "exclamationmark.triangle.fill",
                                    color: MHBTheme.ColorToken.warning.color
                                )
                            }

                            Button(action: triggerDangerToast) {
                                MHBTestButtonLabel(
                                    title: "危险错误 (Danger)",
                                    icon: "xmark.circle.fill",
                                    color: MHBTheme.ColorToken.danger.color
                                )
                            }
                        }
                    }
                    .padding(MHBTheme.Spacing.s5)
                    .background(MHBTheme.ColorToken.card.color, in: .rect(cornerRadius: MHBTheme.Radius.extraExtraLarge))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.extraExtraLarge)
                            .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
                    }
                }
                .padding(MHBTheme.Spacing.s6)
            }
        }
        .diagnosticsScreen("home", metadata: ["screen_type": "root"])
        .accessibilityIdentifier("home.root")
    }

    private func triggerSuccessToast() {
        MHBToastManager.shared.show(
            MHBToast(
                title: "同步成功",
                description: "您的宠物档案更新已成功同步至云端。",
                type: .success
            )
        )
    }

    private func triggerMorphingToast() {
        let toastId = UUID()
        MHBToastManager.shared.show(
            MHBToast(
                id: toastId,
                title: "正在上传宠物照片...",
                type: .loading,
                duration: nil
            )
        )

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            MHBToastManager.shared.show(
                MHBToast(
                    id: toastId,
                    title: "照片上传成功",
                    description: "照片已成功裁剪并保存至服务器。",
                    type: .success,
                    duration: 3.0
                )
            )
        }
    }

    private func triggerWarningToastWithAction() {
        MHBToastManager.shared.show(
            MHBToast(
                title: "云空间已满 90%",
                description: "存储额度即将耗尽，多出的照片将暂停备份。",
                type: .warning,
                duration: 5.0,
                action: MHBToastAction(label: "去扩容") {
                    print("用户点击了去扩容按钮")
                }
            )
        )
    }

    private func triggerDangerToast() {
        MHBToastManager.shared.show(
            MHBToast(
                title: "网络请求超时",
                description: "无法连接至毛伙伴服务器，请稍后重试。",
                type: .danger
            )
        )
    }
}

#Preview {
    ContentView()
}

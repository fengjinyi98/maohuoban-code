//
//  LaunchScreenView.swift
//  maohuoban
//
//  Created by fengjinyi on 2026/6/13.
//

import SwiftUI
import MaohuobanDesignSystem

// LaunchScreenView 启动图视图
// 核心职责：
// - 呈现高保真 App 启动界面（Logo、Slogan 以及带淡出渐变的心形分割线）
// - 支持阶段式的淡入与微动动画，使启动体验更为精致
// - 在加载完成后将 `isCompleted` 状态设为 true，平滑过渡到主视图
struct LaunchScreenView: View {
    @Binding var isCompleted: Bool

    // 动画控制状态
    @State private var logoOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.85
    @State private var sloganOpacity: Double = 0.0
    @State private var sloganScale: CGFloat = 0.95

    var body: some View {
        ZStack {
            // 背景底色 (Token)
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            // 底部环境光脉冲渐变，增加视觉深度
            RadialGradient(
                colors: [
                    MHBTheme.ColorToken.primary.color.opacity(0.12),
                    MHBTheme.ColorToken.primary.color.opacity(0.0)
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: 450
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 1. 品牌 Logo (从 Assets.xcassets 读取 LaunchLogo)
                Image("LaunchLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 80)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Spacer()
                    .frame(height: MHBTheme.Spacing.s8)

                // Slogan 与分割线容器
                VStack(spacing: MHBTheme.Spacing.s4) {
                    // 2. 品牌 Slogan
                    Text("让每只毛孩子 · 拥有自己的主页")
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .tracking(0.5)

                    // 3. 心形渐变分割线 (中间为心形，两端向外渐变淡出)
                    HStack(spacing: MHBTheme.Spacing.s3) {
                        // 左侧渐变淡出线条
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        MHBTheme.ColorToken.primary.color.opacity(0.0),
                                        MHBTheme.ColorToken.primary.color.opacity(0.4)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)

                        // 中间心形符号 (Token 主色)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(MHBTheme.ColorToken.primary.color)

                        // 右侧渐变淡出线条
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        MHBTheme.ColorToken.primary.color.opacity(0.4),
                                        MHBTheme.ColorToken.primary.color.opacity(0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                    }
                    .frame(width: 200)
                }
                .scaleEffect(sloganScale)
                .opacity(sloganOpacity)

                Spacer()
            }
        }
        .onAppear {
            startLaunchAnimation()
        }
    }

    // 执行阶段式启动动画与延时回调
    private func startLaunchAnimation() {
        // 第一阶段：Logo 缩放并淡入
        withAnimation(.easeOut(duration: 0.65)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }

        // 第二阶段：Slogan 与心形分割线稍微滞后淡入
        withAnimation(.easeOut(duration: 0.55).delay(0.25)) {
            sloganOpacity = 1.0
            sloganScale = 1.0
        }

        // 第三阶段：加载完毕后（1.8秒后），触发回调进入主页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            isCompleted = true
        }
    }
}

#Preview {
    LaunchScreenView(isCompleted: .constant(false))
}

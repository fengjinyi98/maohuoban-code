//
//  ContentView.swift
//  maohuoban
//
//  Created by fengjinyi on 2026/6/8.
//

import SwiftUI
import MaohuobanDiagnostics
import MaohuobanDesignSystem

// ContentView 首页占位根视图
// 核心职责：
// - 验证 App 已接入毛伙伴设计系统
// - 为后续宠物主体首页提供最小承载层
struct ContentView: View {
    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            VStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .imageScale(.large)
                Text("毛伙伴")
                    .font(MHBTheme.Typography.largeTitle)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
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
            .padding(MHBTheme.Spacing.s6)
        }
        .diagnosticsScreen("home", metadata: ["screen_type": "root"])
    }
}

#Preview {
    ContentView()
}

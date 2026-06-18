import SwiftUI
import MaohuobanDesignSystem

// AuthCodeBoxes 验证码数字框
// 核心职责：
// - 展示 6 位验证码输入状态
// - 通过稳定格子尺寸避免输入时布局跳动
struct AuthCodeBoxes: View {
    let code: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(0..<6, id: \.self) { index in
                AuthCodeBox(character: character(at: index), isActive: code.count == index)
            }
        }
    }

    private func character(at index: Int) -> String {
        guard index < code.count else { return "" }
        let offset = code.index(code.startIndex, offsetBy: index)
        return String(code[offset])
    }
}

// AuthCodeBox 单个验证码格子
// 核心职责：
// - 渲染验证码单个数字或当前焦点
// - 保持固定宽高比例
struct AuthCodeBox: View {
    let character: String
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.small)
                .fill(isActive ? MHBTheme.ColorToken.cardSolid.color : MHBTheme.ColorToken.separatorSoft.color)
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.small)
                        .stroke(isActive ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color, lineWidth: 1)
                }
                .shadow(color: isActive ? MHBTheme.ColorToken.primary.color.opacity(0.1) : .clear, radius: 6, x: 0, y: 0)

            Text(character)
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }
}

// AuthRecoverySecurityCard 忘记密码安全提示卡
// 核心职责：
// - 对齐设计稿中的安全图形区域
// - 表达重置密码流程的安全感
struct AuthRecoverySecurityCard: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text("重置密码安全验证")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color, in: .rect(cornerRadius: MHBTheme.Radius.extraLarge))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 0.5)
        }
        .padding(.top, MHBTheme.Spacing.s8)
    }
}

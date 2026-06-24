import SwiftUI
import MaohuobanDesignSystem

// PetWalkMapControls 地图浮动控件
// 核心职责：
// - 在地图上提供记录状态和回到当前定位入口
// - 根据 sheet 展示状态和安全区域调整按钮位置
struct PetWalkMapControls: View {
    let phase: PetWalkSessionPhase
    let gpsStatusText: String
    let isSheetPresented: Bool
    let activeDetent: PresentationDetent
    let effectiveBottomInset: CGFloat
    let screenHeight: CGFloat
    let onRecenter: () -> Void

    var body: some View {
        let paddingBottom: CGFloat = {
            if isSheetPresented {
                if activeDetent == .medium {
                    return screenHeight * 0.45 + 20
                } else {
                    return 260 + effectiveBottomInset + 44
                }
            } else {
                return 84 + MHBTheme.Spacing.s5 + effectiveBottomInset + 20
            }
        }()

        VStack {
            Spacer()

            GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
                ZStack {
                    PetWalkNavigationStatus(
                        phase: phase,
                        gpsStatusText: gpsStatusText
                    )
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.vertical, MHBTheme.Spacing.s2)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .accessibilityIdentifier("pet.walkTracking.navigationStatus")

                    HStack {
                        Spacer()

                        Button(action: onRecenter) {
                            Image(systemName: "scope")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                                .frame(width: 48, height: 48)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 6)
                        .accessibilityLabel("回到当前位置")
                        .accessibilityIdentifier("pet.walkTracking.recenterButton")
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .padding(.bottom, paddingBottom)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: paddingBottom)
    }
}

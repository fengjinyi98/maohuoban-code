import SwiftUI
import MaohuobanDesignSystem

// PetWalkTeardropMarker 遛弯地图宠物水滴标记
// 核心职责：
// - 复用遛弯地图中的倒置水滴头像标记形态
// - 根据宠物性别提供稳定 marker 色彩
struct PetWalkTeardropMarker: View {
    let avatarURL: URL?
    let petSex: PetRecordPetSex

    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(petSex.walkMarkerColor)
                .frame(width: 12, height: 12)
                .opacity(0.9)
                .offset(y: 55)

            ZStack {
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: 27,
                        bottomLeading: 0,
                        bottomTrailing: 27,
                        topTrailing: 27
                    ),
                    style: .continuous
                )
                .fill(petSex.walkMarkerColor)
                .frame(width: 54, height: 54)
                .overlay {
                    UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: 27,
                            bottomLeading: 0,
                            bottomTrailing: 27,
                            topTrailing: 27
                        ),
                        style: .continuous
                    )
                    .stroke(.white, lineWidth: 2)
                }
                .rotationEffect(.degrees(-45))
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: -4, y: 8)

                MHBRemoteImage(url: avatarURL, contentMode: .fill) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(MHBTheme.ColorToken.primaryBackground.color)
                }
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(petSex.walkMarkerColor, lineWidth: 2)
                }
            }
            .frame(width: 58, height: 58)
        }
        .frame(width: 58, height: 70)
        .accessibilityHidden(true)
    }
}

extension PetRecordPetSex {
    var walkMarkerColor: Color {
        let rgb = walkMarkerRGB
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    var walkMarkerRGB: (red: Double, green: Double, blue: Double) {
        switch self {
        case .male:
            (59 / 255, 130 / 255, 246 / 255)
        case .female:
            (244 / 255, 63 / 255, 94 / 255)
        case .unknown:
            (0, 0, 0)
        }
    }
}

import SwiftUI
import MaohuobanDesignSystem

// HomeImmersiveHeaderCapsuleLabel 首页头图胶囊文字按钮标签
// 核心职责：
// - 统一首页头图内轻量操作按钮的尺寸和 Liquid Glass 外观
// - 复用于编辑档案、退出预览等头图浮层操作
struct HomeImmersiveHeaderCapsuleLabel: View {
    let title: String
    var isEnabled = true

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.58))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Color.black.opacity(isEnabled ? 0.18 : 0.12)
                    .clipShape(Capsule())
            }
            .glassEffect(.regular.interactive(), in: .capsule)
    }
}

// HomeImmersiveCalendarIcon 首页沉浸式日历图标
// 核心职责：
// - 渲染空白的日历卡片，并在页面中叠加居中显示当月的具体日期天数
struct HomeImmersiveCalendarIcon: View {
    let day: String

    var body: some View {
        ZStack(alignment: .center) {
            Image("CalendarTemplate")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)

            Text(day)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 76/255, green: 48/255, blue: 48/255)) // #4C3030
                .offset(y: 2.2)
        }
    }
}

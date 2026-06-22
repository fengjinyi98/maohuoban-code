import WidgetKit
import SwiftUI

// MaohuobanWidgetsBundle 毛伙伴 Widget 入口
// 核心职责：
// - 注册毛伙伴 Widget Extension
// - 承载遛弯实时事件 Widget
@main
struct MaohuobanWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PetWalkLiveActivityWidget()
    }
}

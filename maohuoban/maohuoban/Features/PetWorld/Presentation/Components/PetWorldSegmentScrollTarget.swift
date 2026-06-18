import SwiftUI

extension [PetWorldGlassSegmentedControl.Tab] {
    var snapPoints: [CGFloat] {
        var snapPoints: [CGFloat] = []
        var x: CGFloat = 0

        for tab in self {
            snapPoints.append(x + tab.viewSize.width / 2)
            x += tab.viewSize.width
        }

        return snapPoints
    }

    func closestSnapPoint(_ offset: CGFloat) -> CGFloat {
        snapPoints.min { first, second in
            abs(first - offset) < abs(second - offset)
        } ?? offset
    }

    func closestSnapPointIndex(_ offset: CGFloat) -> Int? {
        snapPoints.enumerated().min { first, second in
            abs(first.element - offset) < abs(second.element - offset)
        }?.offset
    }
}

// PetWorldSegmentScrollTarget 宠物世界频道吸附目标
// 核心职责：
// - 将横向滚动结束位置吸附到最近频道中心
// - 限制快速减速时跨过多个频道造成的视觉跳动
struct PetWorldSegmentScrollTarget: ScrollTargetBehavior {
    @Binding var tabs: [PetWorldGlassSegmentedControl.Tab]

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = tabs.closestSnapPoint(target.rect.origin.x)
    }

    func properties(context: PropertiesContext) -> Properties {
        var properties = Properties()
        properties.limitsScrolls = true
        return properties
    }
}

import SwiftUI

// ProfileUserEditDisplay 用户资料编辑展示文案
// 核心职责：
// - 将用户主页展示字段转换为编辑页右侧值
// - 保持当前快速 UI 阶段的文案映射集中
enum ProfileUserEditDisplay {
    nonisolated static func genderText(
        for option: ProfileUserEditGenderOption?,
        isVisible: Bool
    ) -> String {
        guard isVisible else { return "不展示" }
        return option?.displayTitle ?? "未设置"
    }
}

import Foundation

// PetAbnormalSymptom 异常症状类型
// 核心职责：
// - 承载异常记录页的一级症状多选项
// - 为异常事件摘要和具体表现展开提供稳定语义
enum PetAbnormalSymptom: String, CaseIterable, Identifiable, Hashable {
    case appetite
    case energy
    case stool
    case vomit
    case cough
    case skin
    case walk
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appetite: "食欲"
        case .energy: "精神"
        case .stool: "便便"
        case .vomit: "呕吐"
        case .cough: "咳嗽"
        case .skin: "皮肤"
        case .walk: "走路"
        case .other: "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .appetite: "fork.knife.circle.fill"
        case .energy: "face.dashed.fill"
        case .stool: "exclamationmark.triangle.fill"
        case .vomit: "drop.triangle.fill"
        case .cough: "lungs.fill"
        case .skin: "bandage.fill"
        case .walk: "figure.walk.motion"
        case .other: "questionmark.circle.fill"
        }
    }

    var detailOptions: [String] {
        switch self {
        case .appetite:
            ["不吃", "吃很少", "挑食", "喝水异常"]
        case .energy:
            ["没精神", "躲起来", "烦躁", "嗜睡"]
        case .stool:
            ["软便", "拉稀", "便秘", "便血"]
        case .vomit:
            ["吐粮", "吐黄水", "干呕", "频繁呕吐"]
        case .cough:
            ["咳嗽", "打喷嚏", "呼吸急促", "流鼻涕"]
        case .skin:
            ["抓挠", "掉毛", "红肿", "结痂"]
        case .walk:
            ["跛行", "不愿走", "发抖", "站立异常"]
        case .other:
            ["说不清", "行为异常", "外伤", "其他"]
        }
    }
}

// PetAbnormalSeverity 异常严重程度
// 核心职责：
// - 表达用户对异常程度的初步判断
// - 为异常事件摘要和后续追踪提供分层输入
enum PetAbnormalSeverity: String, CaseIterable, Identifiable, Hashable {
    case mild
    case obvious
    case severe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mild: "轻微"
        case .obvious: "明显"
        case .severe: "严重"
        }
    }

    var subtitle: String {
        ""
    }
}

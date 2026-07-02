import Foundation

// PetManagementSortOrder 我的宠物排序规则
// 核心职责：
// - 表达列表当前排序方式
// - 为系统导航栏排序按钮提供可切换状态
enum PetManagementSortOrder: Hashable {
    case companionshipDescending
    case companionshipAscending

    var accessibilityLabel: String {
        switch self {
        case .companionshipDescending: "当前按陪伴天数从多到少排序"
        case .companionshipAscending: "当前按陪伴天数从少到多排序"
        }
    }

    var next: PetManagementSortOrder {
        switch self {
        case .companionshipDescending: .companionshipAscending
        case .companionshipAscending: .companionshipDescending
        }
    }

    func sorted(_ pets: [PetManagementPet]) -> [PetManagementPet] {
        switch self {
        case .companionshipDescending:
            pets.sorted { lhs, rhs in
                if lhs.companionshipDays == rhs.companionshipDays {
                    lhs.name < rhs.name
                } else {
                    lhs.companionshipDays > rhs.companionshipDays
                }
            }
        case .companionshipAscending:
            pets.sorted { lhs, rhs in
                if lhs.companionshipDays == rhs.companionshipDays {
                    lhs.name < rhs.name
                } else {
                    lhs.companionshipDays < rhs.companionshipDays
                }
            }
        }
    }
}

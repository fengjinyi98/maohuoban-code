import SwiftUI
import MaohuobanDesignSystem

import SwiftUI
import MaohuobanDesignSystem

// PetRecordDetailPlaceholderScreen 宠物记录详情占位页
// 核心职责：
// - 当某个记录类型的详情页尚未实现时，展示简洁信息占位
// - 保持占位页统一复用 MHBTabPlaceholderRootScreen
struct PetRecordDetailPlaceholderScreen: View {
    let systemImage: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let accessibilityIdentifier: String

    var body: some View {
        MHBTabPlaceholderRootScreen(
            systemImage: systemImage,
            title: title,
            subtitle: subtitle,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }
}

// PetQuickFactDetailPresentation 快速事实展示模型
// 核心职责：
// - 将快速事实类型转换为小票展示数据
// - 集中维护 mock 宠物和字段行，避免业务详情边界漂移
struct PetQuickFactDetailPresentation {
    struct PetIdentity: Equatable {
        let id: String
        let name: String
        let avatarSource: MHBAvatarSource
    }

    enum RowValue: Equatable {
        case text(String)
        case pet(PetIdentity)
    }

    struct Row: Identifiable {
        let id: String
        let title: String
        let value: RowValue

        init(id: String, title: String, text: String) {
            self.id = id
            self.title = title
            self.value = .text(text)
        }

        init(id: String, title: String, pet: PetIdentity) {
            self.id = id
            self.title = title
            self.value = .pet(pet)
        }
    }

    let title: String
    let timeText: String
    let systemImage: String
    let tint: Color
    let rows: [Row]

    init(kind: PetQuickFactDetailKind) {
        self.title = kind.title
        self.timeText = "2026年6月25日 10:30"
        self.systemImage = kind.systemImage
        self.tint = kind.tint
        self.rows = [
            .init(id: "pet", title: "宠物", pet: Self.mockPet),
            .init(id: "type", title: "记录类型", text: kind.recordTypeTitle),
            .init(id: "content", title: "内容", text: kind.contentText)
        ]
    }

    private static let mockPet = PetIdentity(
        id: "pet-quick-fact-mock",
        name: "测试名字1",
        avatarSource: .asset("HomePetHeroMock")
    )
}

import Foundation

extension MerchantPetStatus {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .family: "家庭"
        case .available: "在售"
        case .reserved: "预定"
        case .sold: "已售"
        case .retained: "留种"
        case .fostered: "寄养"
        case .needsExam: "待体检"
        case .needsRecord: "待补记录"
        case .inactive: "停售"
        }
    }

    var sectionTitle: LocalizedStringResource {
        switch self {
        case .family: "家庭宠物"
        case .available: "在售宠物"
        case .reserved: "已预定宠物"
        case .sold: "已售宠物"
        case .retained: "留种宠物"
        case .fostered: "寄养宠物"
        case .needsExam: "待体检宠物"
        case .needsRecord: "待补记录宠物"
        case .inactive: "停售宠物"
        }
    }
}

extension MerchantPetSourceKind {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .userCreated: "用户创建"
        case .tradeImported: "交易导入"
        case .merchantManaged: "商家管理"
        case .litterBirth: "窝次出生"
        }
    }
}

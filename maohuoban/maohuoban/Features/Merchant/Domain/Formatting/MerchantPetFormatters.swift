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

extension MerchantLitterStatus {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .planned: "计划中"
        case .active: "进行中"
        case .closed: "已结束"
        case .archived: "已归档"
        }
    }
}

extension MerchantPetRelationshipKind {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .sire: "父亲"
        case .dam: "母亲"
        case .sameLitter: "同窝"
        case .sameSource: "同来源"
        case .transferredFrom: "转入来源"
        case .coCaretaker: "共管"
        case .merchantManaged: "商家管理"
        }
    }
}

extension MerchantPetRelationshipSourceKind {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .userRecorded: "用户记录"
        case .merchantRecorded: "商家记录"
        case .systemDerived: "系统推导"
        case .tradeImported: "交易导入"
        }
    }
}

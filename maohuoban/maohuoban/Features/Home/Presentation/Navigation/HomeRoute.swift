import Foundation

// HomeRoute 首页 Tab 路由枚举
// 核心职责：
// - 定义首页 Tab 内所有可 push 的页面路由
// - 关联值携带目标页面所需的最小参数
// - 后续随首页功能迭代扩展 case
enum HomeRoute: Hashable {
    case petAssistant(AIAssistantEntryContext)
    case createPet
    case publishEvent(PublishEntryContext)
    case editPetProfile(PetProfileEditContext)
    case recordDaily(petID: String?)
    case recordHealth(petID: String?)
    case bookHospital(petID: String?, city: String?)
    case importTradePet
    case addMerchantPet(merchantID: String)
    case publishAvailableStatus(merchantID: String)
    case merchantPets(merchantID: String, status: String)
    case merchantLitter(merchantID: String, litterID: String)
    case merchantTask(merchantID: String, reminderID: String)
    case timelineEvent(eventID: String)
    case petAlbumList
    case petAlbumDetail(albumID: String)
}

extension HomeRoute {
    var systemImage: String {
        switch self {
        case .petAssistant: "sparkles"
        case .createPet: "plus.circle.fill"
        case .publishEvent: "photo.on.rectangle.angled"
        case .editPetProfile: "pencil.circle.fill"
        case .recordDaily: "square.and.pencil"
        case .recordHealth: "cross.case.fill"
        case .bookHospital: "stethoscope"
        case .importTradePet: "tray.and.arrow.down.fill"
        case .addMerchantPet: "pawprint.circle.fill"
        case .publishAvailableStatus: "tag.fill"
        case .merchantPets: "pawprint"
        case .merchantLitter: "point.3.connected.trianglepath.dotted"
        case .merchantTask: "checklist"
        case .timelineEvent: "clock.arrow.circlepath"
        case .petAlbumList: "photo.on.rectangle.angled"
        case .petAlbumDetail: "photo"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .petAssistant: "毛球"
        case .createPet: "添加宠物"
        case .publishEvent: "发布动态"
        case .editPetProfile: "编辑档案"
        case .recordDaily: "记录日常"
        case .recordHealth: "健康记录"
        case .bookHospital: "预约医院"
        case .importTradePet: "导入交易宠物"
        case .addMerchantPet: "新增店内宠物"
        case .publishAvailableStatus: "发布可售状态"
        case .merchantPets: "商家宠物筛选"
        case .merchantLitter: "窝次详情"
        case .merchantTask: "待处理任务"
        case .timelineEvent: "事件详情"
        case .petAlbumList: "宠物相册"
        case .petAlbumDetail: "相册详情"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .petAssistant: "当前宠物的私域助手"
        case .createPet: "添加一只新的宠物档案"
        case .publishEvent: "记录一次带图片和正文的宠物事件"
        case .editPetProfile: "更新宠物头像、基础信息和档案备注"
        case .recordDaily: "为当前宠物补充一条日常事件"
        case .recordHealth: "记录体重、疫苗、驱虫或就诊信息"
        case .bookHospital: "进入同城医院预约协作"
        case .importTradePet: "把交易履约宠物导入档案"
        case .addMerchantPet: "录入店内宠物或出生窝次"
        case .publishAvailableStatus: "更新买家可见的在售资料"
        case .merchantPets: "查看指定状态下的在管宠物"
        case .merchantLitter: "查看出生批次、父母和同窝关系"
        case .merchantTask: "处理商家工作台待办"
        case .timelineEvent: "查看宠物事件账本记录"
        case .petAlbumList: "查看宠物照片相册"
        case .petAlbumDetail: "查看单个相册中的照片"
        }
    }
}

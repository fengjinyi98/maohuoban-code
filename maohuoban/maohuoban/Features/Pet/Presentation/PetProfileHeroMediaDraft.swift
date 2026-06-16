import UIKit
import Foundation

// PetProfileHeroMediaDraft 宠物背景媒体本地草稿
// 核心职责：
// - 承载编辑档案页尚未上传到后端的背景图片或视频
// - 为背景预览、缩略图和后续上传流程提供统一输入
enum PetProfileHeroMediaDraft {
    case image(UIImage)
    case video(URL)
}

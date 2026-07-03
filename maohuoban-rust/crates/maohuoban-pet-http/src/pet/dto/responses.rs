use maohuoban_pet_application::pet::{PetAlbumAssetPage, PetAlbumListPage, TradePetImport};
use maohuoban_pet_domain::pet::{
    PetAlbum, PetAlbumAsset, PetEvent, PetMediaUploadResult, PetProfile, PetTimeline,
};
use serde::Serialize;

/// PetProfileData 宠物档案响应数据
/// 核心职责：
/// - 返回客户端展示和后续记录所需宠物字段
/// - 隔离领域模型和 HTTP JSON 结构
#[derive(Debug, Serialize)]
pub(crate) struct PetProfileData {
    #[serde(flatten)]
    profile: PetProfile,
}

/// PetMediaUploadData 宠物媒体上传响应
/// 核心职责：
/// - 返回媒体资产
/// - 返回当前有效绑定
#[derive(Debug, Serialize)]
pub(crate) struct PetMediaUploadData {
    #[serde(flatten)]
    upload: PetMediaUploadResult,
}

impl From<PetMediaUploadResult> for PetMediaUploadData {
    fn from(upload: PetMediaUploadResult) -> Self {
        Self { upload }
    }
}

/// PetAlbumData 宠物相册响应数据
/// 核心职责：
/// - 返回相册基础信息
/// - 隔离领域模型和 HTTP JSON 结构
#[derive(Debug, Serialize)]
pub(crate) struct PetAlbumData {
    #[serde(flatten)]
    album: PetAlbum,
}

impl From<PetAlbum> for PetAlbumData {
    fn from(album: PetAlbum) -> Self {
        Self { album }
    }
}

/// PetAlbumDetailData 宠物相册详情响应
/// 核心职责：
/// - 返回相册详情主体
/// - 为后续追加最近照片预览保留稳定包裹层
#[derive(Debug, Serialize)]
pub(crate) struct PetAlbumDetailData {
    album: PetAlbumData,
}

impl From<PetAlbum> for PetAlbumDetailData {
    fn from(album: PetAlbum) -> Self {
        Self {
            album: PetAlbumData::from(album),
        }
    }
}

/// PetAlbumListData 宠物相册列表响应
/// 核心职责：
/// - 返回分页相册条目
/// - 暴露下一页 cursor
#[derive(Debug, Serialize)]
pub(crate) struct PetAlbumListData {
    items: Vec<PetAlbumData>,
    next_cursor: Option<String>,
}

impl From<PetAlbumListPage> for PetAlbumListData {
    fn from(page: PetAlbumListPage) -> Self {
        Self {
            items: page.items.into_iter().map(PetAlbumData::from).collect(),
            next_cursor: page.next_cursor,
        }
    }
}

/// PetAlbumAssetData 宠物相册照片响应
/// 核心职责：
/// - 返回相册照片条目
/// - 保留媒体资产可访问 URL
#[derive(Debug, Serialize)]
pub(crate) struct PetAlbumAssetData {
    #[serde(flatten)]
    asset: PetAlbumAsset,
}

impl From<PetAlbumAsset> for PetAlbumAssetData {
    fn from(asset: PetAlbumAsset) -> Self {
        Self { asset }
    }
}

/// PetAlbumAssetListData 宠物相册照片列表响应
/// 核心职责：
/// - 返回分页照片条目
/// - 暴露下一页 cursor
#[derive(Debug, Serialize)]
pub(crate) struct PetAlbumAssetListData {
    items: Vec<PetAlbumAssetData>,
    next_cursor: Option<String>,
}

impl From<PetAlbumAssetPage> for PetAlbumAssetListData {
    fn from(page: PetAlbumAssetPage) -> Self {
        Self {
            items: page
                .items
                .into_iter()
                .map(PetAlbumAssetData::from)
                .collect(),
            next_cursor: page.next_cursor,
        }
    }
}

/// PetProfilesData 宠物档案列表响应
/// 核心职责：
/// - 返回当前用户可见宠物档案
/// - 支持前端添加、编辑和多宠切换刷新
#[derive(Debug, Serialize)]
pub(crate) struct PetProfilesData {
    pets: Vec<PetProfileData>,
}

impl From<Vec<PetProfile>> for PetProfilesData {
    fn from(pets: Vec<PetProfile>) -> Self {
        Self {
            pets: pets.into_iter().map(PetProfileData::from).collect(),
        }
    }
}

impl From<PetProfile> for PetProfileData {
    fn from(profile: PetProfile) -> Self {
        Self { profile }
    }
}

/// PetEventData 宠物事件响应数据
/// 核心职责：
/// - 返回追加事件后的稳定字段
/// - 为首页和详情页刷新时间线提供记录版本
#[derive(Debug, Serialize)]
pub(crate) struct PetEventData {
    #[serde(flatten)]
    event: PetEvent,
}

impl From<PetEvent> for PetEventData {
    fn from(event: PetEvent) -> Self {
        Self { event }
    }
}

/// TradePetImportData 交易宠物导入响应
/// 核心职责：
/// - 返回新建宠物档案
/// - 返回同步写入的交易事件
#[derive(Debug, Serialize)]
pub(crate) struct TradePetImportData {
    pet: PetProfileData,
    event: PetEventData,
}

impl From<TradePetImport> for TradePetImportData {
    fn from(import: TradePetImport) -> Self {
        Self {
            pet: PetProfileData::from(import.pet),
            event: PetEventData::from(import.event),
        }
    }
}

/// PetTimelineData 宠物时间线响应数据
/// 核心职责：
/// - 返回单只宠物最近事件列表
/// - 支持首页最近时间线和宠物详情页共用
#[derive(Debug, Serialize)]
pub(crate) struct PetTimelineData {
    #[serde(flatten)]
    timeline: PetTimeline,
}

impl From<PetTimeline> for PetTimelineData {
    fn from(timeline: PetTimeline) -> Self {
        Self { timeline }
    }
}

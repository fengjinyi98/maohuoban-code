use maohuoban_pet_application::pet::BindUploadedPetMediaInput;
use serde::Deserialize;
use uuid::Uuid;

/// BindUploadedPetMediaRequest 绑定已上传宠物媒体请求
/// 核心职责：
/// - 接收 pending 媒体资产 ID
/// - 转换为宠物媒体绑定命令
#[derive(Debug, Deserialize)]
pub(crate) struct BindUploadedPetMediaRequest {
    asset_id: Uuid,
}

impl BindUploadedPetMediaRequest {
    pub(crate) fn into_input(self, pet_id: Uuid, owner_user_id: Uuid) -> BindUploadedPetMediaInput {
        BindUploadedPetMediaInput {
            pet_id,
            owner_user_id,
            asset_id: self.asset_id,
        }
    }
}

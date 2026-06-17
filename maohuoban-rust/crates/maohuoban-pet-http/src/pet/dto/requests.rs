use axum::extract::Multipart;
use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_application::pet::{
    DeletePetProfile, NewMerchantPetProfile, NewPetEvent, NewPetProfile, PetMediaUploadInput,
    PublishAvailableStatusInput, TradePetImportInput, UpdatePetProfile,
};
use maohuoban_pet_domain::pet::{
    EventKind, EventVisibility, ManagedPetStatus, MediaUsageKind, PetError, PetNeuterStatus,
    PetResult, PetSex, PetSourceKind, PetSpecies,
};
use serde::Deserialize;
use serde_json::Value;
use uuid::Uuid;

/// CreatePetProfileRequest 创建宠物档案请求
/// 核心职责：
/// - 接收普通用户创建宠物所需字段
/// - 将 HTTP 输入转换为应用层命令
#[derive(Debug, Deserialize)]
pub(crate) struct CreatePetProfileRequest {
    name: String,
    species: PetSpecies,
    breed: Option<String>,
    sex: Option<PetSex>,
    birthday: Option<NaiveDate>,
    microchip_number: Option<String>,
    arrival_date: Option<NaiveDate>,
    weight_grams: Option<i32>,
    neuter_status: Option<PetNeuterStatus>,
    personality_tags: Option<Vec<String>>,
    note: Option<String>,
}

impl CreatePetProfileRequest {
    pub(crate) fn into_new_pet_profile(self, owner_user_id: Uuid) -> NewPetProfile {
        NewPetProfile {
            owner_user_id,
            name: self.name,
            species: self.species,
            breed: self.breed,
            sex: self.sex.unwrap_or(PetSex::Unknown),
            birthday: self.birthday,
            microchip_number: self.microchip_number,
            arrival_date: self.arrival_date,
            weight_grams: self.weight_grams,
            neuter_status: self.neuter_status.unwrap_or(PetNeuterStatus::Unknown),
            personality_tags: self.personality_tags.unwrap_or_default(),
            note: self.note,
            source_kind: PetSourceKind::UserCreated,
        }
    }
}

/// UpdatePetProfileRequest 更新宠物档案请求
/// 核心职责：
/// - 接收用户可编辑字段
/// - 转换为应用层部分更新命令
#[derive(Debug, Deserialize)]
pub(crate) struct UpdatePetProfileRequest {
    name: Option<String>,
    species: Option<PetSpecies>,
    breed: Option<String>,
    sex: Option<PetSex>,
    birthday: Option<NaiveDate>,
    microchip_number: Option<String>,
    arrival_date: Option<NaiveDate>,
    weight_grams: Option<i32>,
    neuter_status: Option<PetNeuterStatus>,
    personality_tags: Option<Vec<String>>,
    note: Option<String>,
}

impl UpdatePetProfileRequest {
    pub(crate) fn into_input(self, pet_id: Uuid, owner_user_id: Uuid) -> UpdatePetProfile {
        UpdatePetProfile {
            pet_id,
            owner_user_id,
            name: self.name,
            species: self.species,
            breed: self.breed,
            sex: self.sex,
            birthday: self.birthday,
            microchip_number: self.microchip_number,
            arrival_date: self.arrival_date,
            weight_grams: self.weight_grams,
            neuter_status: self.neuter_status,
            personality_tags: self.personality_tags,
            note: self.note,
        }
    }
}

/// DeletePetProfileRequest 删除宠物档案请求
/// 核心职责：
/// - 接收用户删除原因
/// - 转换为软删除命令
#[derive(Debug, Deserialize)]
pub(crate) struct DeletePetProfileRequest {
    reason: Option<String>,
}

impl DeletePetProfileRequest {
    pub(crate) fn into_input(self, pet_id: Uuid, owner_user_id: Uuid) -> DeletePetProfile {
        DeletePetProfile {
            pet_id,
            owner_user_id,
            reason: self.reason,
        }
    }
}

/// UploadPetMediaRequest 上传宠物媒体请求
/// 核心职责：
/// - 承接 multipart 解包后的媒体内容
/// - 转换为媒体资产和业务绑定命令
#[derive(Debug)]
pub(crate) struct UploadPetMediaRequest {
    file_name: String,
    mime_type: String,
    content: Vec<u8>,
    source_client: Option<String>,
}

impl UploadPetMediaRequest {
    pub(crate) async fn from_multipart(mut multipart: Multipart) -> PetResult<Self> {
        let mut file_name = None;
        let mut mime_type = None;
        let mut content = None;
        let mut source_client = None;

        while let Some(field) = multipart
            .next_field()
            .await
            .map_err(|_| PetError::InvalidInput("媒体上传表单无法解析".to_owned()))?
        {
            match field.name() {
                Some("file") => {
                    file_name = Some(
                        field
                            .file_name()
                            .filter(|value| !value.trim().is_empty())
                            .unwrap_or("upload.bin")
                            .to_owned(),
                    );
                    mime_type = Some(
                        field
                            .content_type()
                            .filter(|value| !value.trim().is_empty())
                            .unwrap_or("application/octet-stream")
                            .to_owned(),
                    );
                    let bytes = field
                        .bytes()
                        .await
                        .map_err(|_| PetError::InvalidInput("媒体文件读取失败".to_owned()))?;
                    content = Some(bytes.to_vec());
                }
                Some("source_client") => {
                    let value = field
                        .text()
                        .await
                        .map_err(|_| PetError::InvalidInput("媒体来源客户端读取失败".to_owned()))?;
                    let trimmed = value.trim();
                    if !trimmed.is_empty() {
                        source_client = Some(trimmed.to_owned());
                    }
                }
                _ => {}
            }
        }

        let content = content.ok_or_else(|| PetError::InvalidInput("请上传媒体文件".to_owned()))?;
        if content.is_empty() {
            return Err(PetError::InvalidInput("媒体文件不能为空".to_owned()));
        }

        Ok(Self {
            file_name: file_name.unwrap_or_else(|| "upload.bin".to_owned()),
            mime_type: mime_type.unwrap_or_else(|| "application/octet-stream".to_owned()),
            content,
            source_client,
        })
    }

    pub(crate) fn into_avatar_input(
        self,
        pet_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetMediaUploadInput {
        self.into_input(pet_id, owner_user_id, MediaUsageKind::PetAvatar)
    }

    pub(crate) fn into_background_image_input(
        self,
        pet_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetMediaUploadInput {
        self.into_input(pet_id, owner_user_id, MediaUsageKind::PetBackgroundImage)
    }

    pub(crate) fn into_background_video_input(
        self,
        pet_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetMediaUploadInput {
        self.into_input(pet_id, owner_user_id, MediaUsageKind::PetBackgroundVideo)
    }

    fn into_input(
        self,
        pet_id: Uuid,
        owner_user_id: Uuid,
        usage_kind: MediaUsageKind,
    ) -> PetMediaUploadInput {
        PetMediaUploadInput {
            pet_id,
            owner_user_id,
            usage_kind,
            file_name: self.file_name,
            mime_type: self.mime_type,
            content: self.content,
            source_client: self.source_client,
        }
    }
}

/// TradePetImportRequest 交易宠物导入请求
/// 核心职责：
/// - 接收交易完成后的宠物建档字段
/// - 将来源证据转换为应用层导入命令
#[derive(Debug, Deserialize)]
pub(crate) struct TradePetImportRequest {
    name: String,
    species: PetSpecies,
    breed: Option<String>,
    sex: Option<PetSex>,
    birthday: Option<NaiveDate>,
    seller_name: String,
    trade_reference: Option<String>,
    summary: Option<String>,
    occurred_at: DateTime<Utc>,
}

impl TradePetImportRequest {
    pub(crate) fn into_input(self, owner_user_id: Uuid) -> TradePetImportInput {
        TradePetImportInput {
            owner_user_id,
            name: self.name,
            species: self.species,
            breed: self.breed,
            sex: self.sex.unwrap_or(PetSex::Unknown),
            birthday: self.birthday,
            seller_name: self.seller_name,
            trade_reference: self.trade_reference,
            summary: self.summary,
            occurred_at: self.occurred_at,
        }
    }
}

/// CreateMerchantPetRequest 新增商家在管宠物请求
/// 核心职责：
/// - 接收商家新增宠物所需字段
/// - 固定商家手动新增宠物的来源类型
#[derive(Debug, Deserialize)]
pub(crate) struct CreateMerchantPetRequest {
    name: String,
    species: PetSpecies,
    breed: Option<String>,
    sex: Option<PetSex>,
    birthday: Option<NaiveDate>,
    managed_status: Option<ManagedPetStatus>,
}

impl CreateMerchantPetRequest {
    pub(crate) fn into_new_merchant_pet(self, merchant_id: Uuid) -> NewMerchantPetProfile {
        NewMerchantPetProfile {
            merchant_id,
            name: self.name,
            species: self.species,
            breed: self.breed,
            sex: self.sex.unwrap_or(PetSex::Unknown),
            birthday: self.birthday,
            managed_status: self.managed_status.unwrap_or(ManagedPetStatus::NeedsRecord),
            source_kind: PetSourceKind::MerchantManaged,
        }
    }
}

/// PublishAvailableStatusRequest 发布可售状态请求
/// 核心职责：
/// - 接收商家发布买家可见可售状态所需字段
/// - 将 HTTP 输入转换为应用层命令
#[derive(Debug, Deserialize)]
pub(crate) struct PublishAvailableStatusRequest {
    summary: Option<String>,
    occurred_at: DateTime<Utc>,
}

impl PublishAvailableStatusRequest {
    pub(crate) fn into_input(
        self,
        merchant_id: Uuid,
        pet_id: Uuid,
        actor_user_id: Uuid,
    ) -> PublishAvailableStatusInput {
        PublishAvailableStatusInput {
            merchant_id,
            pet_id,
            actor_user_id,
            summary: self.summary,
            occurred_at: self.occurred_at,
        }
    }
}

/// CreatePetEventRequest 创建宠物事件请求
/// 核心职责：
/// - 接收时间线事件基础字段
/// - 支持健康、日常、交易和商家事件共用结构
#[derive(Debug, Deserialize)]
pub(crate) struct CreatePetEventRequest {
    event_kind: EventKind,
    event_subkind: Option<String>,
    title: String,
    summary: Option<String>,
    visibility: Option<EventVisibility>,
    event_payload: Option<Value>,
    occurred_at: DateTime<Utc>,
}

impl CreatePetEventRequest {
    pub(crate) fn into_new_pet_event(self, pet_id: Uuid, actor_user_id: Uuid) -> NewPetEvent {
        NewPetEvent {
            pet_id,
            actor_user_id,
            event_kind: self.event_kind,
            event_subkind: self.event_subkind,
            title: self.title,
            summary: self.summary,
            visibility: self.visibility.unwrap_or(EventVisibility::Private),
            event_payload: self.event_payload.unwrap_or_else(|| serde_json::json!({})),
            occurred_at: self.occurred_at,
        }
    }
}

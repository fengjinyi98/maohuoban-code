use std::sync::Arc;

use maohuoban_pet_domain::pet::{
    ManagedPetStatus, MediaUsageKind, PetError, PetEvent, PetProfile, PetResult, PetTimeline,
};
use uuid::Uuid;

use super::{
    BindUploadedPetMediaInput, DeletePetProfile, MediaAssetDisplayMetadata,
    MediaBindingDiagnostics, MediaUploadDiagnostics, MerchantAvailableStatusPublication,
    MerchantDashboardSummary, MerchantLitterDetail, MerchantRepository, NewMerchantPetProfile,
    NewPetEvent, NewPetProfile, PendingPetLivePhotoUploadInput, PendingPetMediaUploadInput,
    PetProfileDiagnostics, PetRepository, PublishAvailableStatusInput, RestorePetProfile,
    TradePetImport, TradePetImportInput, UpdatePetProfile, record_media_binding,
    record_media_upload, record_pet_profile,
};

/// PetService 宠物应用服务
/// 核心职责：
/// - 编排宠物档案创建、事件追加和时间线读取
/// - 编排商家多宠工作台、窝次和关系追溯读取
pub struct PetService {
    repository: Arc<dyn PetRepository>,
    merchant_repository: Arc<dyn MerchantRepository>,
}

impl PetService {
    #[must_use]
    pub fn new(
        repository: Arc<dyn PetRepository>,
        merchant_repository: Arc<dyn MerchantRepository>,
    ) -> Self {
        Self {
            repository,
            merchant_repository,
        }
    }

    pub async fn create_pet_profile(&self, mut input: NewPetProfile) -> PetResult<PetProfile> {
        input.name = normalize_compact_text(&input.name);
        input.breed = normalize_optional_compact_text(input.breed);
        validate_pet_name(&input.name)?;
        validate_optional_microchip(input.microchip_number.as_deref())?;
        validate_optional_weight(input.weight_grams)?;
        let owner_user_id = input.owner_user_id;
        let breed = input.breed.clone();
        record_pet_profile(PetProfileDiagnostics {
            stage: "service.normalized",
            action: "create",
            user_id: owner_user_id,
            pet_id: None,
            breed: breed.as_deref(),
            success: true,
        });
        let result = self.repository.create_pet_profile(input).await;
        match &result {
            Ok(profile) => record_pet_profile(PetProfileDiagnostics {
                stage: "service.result",
                action: "create",
                user_id: owner_user_id,
                pet_id: Some(profile.id),
                breed: profile.breed.as_deref(),
                success: true,
            }),
            Err(_error) => record_pet_profile(PetProfileDiagnostics {
                stage: "service.result",
                action: "create",
                user_id: owner_user_id,
                pet_id: None,
                breed: breed.as_deref(),
                success: false,
            }),
        }
        result
    }

    pub async fn update_pet_profile(&self, mut input: UpdatePetProfile) -> PetResult<PetProfile> {
        input.name = input.name.map(|name| normalize_compact_text(&name));
        input.breed = normalize_optional_compact_text(input.breed);
        if let Some(name) = input.name.as_deref() {
            validate_pet_name(name)?;
        }
        validate_optional_microchip(input.microchip_number.as_deref())?;
        validate_optional_weight(input.weight_grams)?;
        if self
            .repository
            .find_pet_for_owner(input.pet_id, input.owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        let owner_user_id = input.owner_user_id;
        let pet_id = input.pet_id;
        let breed = input.breed.clone();
        record_pet_profile(PetProfileDiagnostics {
            stage: "service.normalized",
            action: "update",
            user_id: owner_user_id,
            pet_id: Some(pet_id),
            breed: breed.as_deref(),
            success: true,
        });
        let result = self.repository.update_pet_profile(input).await;
        match &result {
            Ok(profile) => record_pet_profile(PetProfileDiagnostics {
                stage: "service.result",
                action: "update",
                user_id: owner_user_id,
                pet_id: Some(profile.id),
                breed: profile.breed.as_deref(),
                success: true,
            }),
            Err(_error) => record_pet_profile(PetProfileDiagnostics {
                stage: "service.result",
                action: "update",
                user_id: owner_user_id,
                pet_id: Some(pet_id),
                breed: breed.as_deref(),
                success: false,
            }),
        }
        result
    }

    pub async fn delete_pet_profile(&self, input: DeletePetProfile) -> PetResult<PetProfile> {
        if self
            .repository
            .find_pet_for_owner(input.pet_id, input.owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository.soft_delete_pet_profile(input).await
    }

    pub async fn restore_pet_profile(&self, input: RestorePetProfile) -> PetResult<PetProfile> {
        self.repository.restore_pet_profile(input).await
    }

    pub async fn upload_pending_pet_media(
        &self,
        input: PendingPetMediaUploadInput,
    ) -> PetResult<maohuoban_pet_domain::pet::PetMediaUploadResult> {
        validate_text("文件名", &input.file_name)?;
        validate_text("媒体类型", &input.mime_type)?;
        if input.content.is_empty() {
            return Err(PetError::InvalidInput("媒体内容不能为空".to_owned()));
        }
        let owner_user_id = input.owner_user_id;
        let usage_kind = input.usage_kind;
        let mime_type = input.mime_type.clone();
        let byte_size = i64::try_from(input.content.len()).unwrap_or(i64::MAX);
        record_media_upload(MediaUploadDiagnostics {
            stage: "service.request",
            user_id: owner_user_id,
            asset_id: None,
            usage_kind,
            mime_type: &mime_type,
            byte_size,
            width: None,
            height: None,
            derivative_count: 0,
            success: true,
            error_kind: None,
        });
        let result = self.repository.upload_pending_pet_media(input).await;
        match &result {
            Ok(upload) => record_media_upload(MediaUploadDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                asset_id: Some(upload.asset.id),
                usage_kind,
                mime_type: &upload.asset.mime_type,
                byte_size: upload.asset.byte_size,
                width: upload.asset.width,
                height: upload.asset.height,
                derivative_count: upload.derivatives.len(),
                success: true,
                error_kind: None,
            }),
            Err(error) => record_media_upload(MediaUploadDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                asset_id: None,
                usage_kind,
                mime_type: &mime_type,
                byte_size,
                width: None,
                height: None,
                derivative_count: 0,
                success: false,
                error_kind: Some(pet_error_kind(error)),
            }),
        }
        result
    }

    pub async fn upload_pending_pet_live_photo(
        &self,
        input: PendingPetLivePhotoUploadInput,
    ) -> PetResult<maohuoban_pet_domain::pet::PetMediaUploadResult> {
        validate_text("静态图文件名", &input.still_file_name)?;
        validate_text("静态图媒体类型", &input.still_mime_type)?;
        validate_text("配对视频文件名", &input.paired_video_file_name)?;
        validate_text("配对视频媒体类型", &input.paired_video_mime_type)?;
        if input.still_content.is_empty() || input.paired_video_content.is_empty() {
            return Err(PetError::InvalidInput("Live Photo 资源不能为空".to_owned()));
        }

        let owner_user_id = input.owner_user_id;
        let mime_type = input.still_mime_type.clone();
        let byte_size = i64::try_from(input.still_content.len() + input.paired_video_content.len())
            .unwrap_or(i64::MAX);
        record_media_upload(MediaUploadDiagnostics {
            stage: "service.request",
            user_id: owner_user_id,
            asset_id: None,
            usage_kind: MediaUsageKind::PetBackgroundLivePhoto,
            mime_type: &mime_type,
            byte_size,
            width: None,
            height: None,
            derivative_count: 0,
            success: true,
            error_kind: None,
        });
        let result = self.repository.upload_pending_pet_live_photo(input).await;
        match &result {
            Ok(upload) => record_media_upload(MediaUploadDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                asset_id: Some(upload.asset.id),
                usage_kind: upload.asset.usage_kind,
                mime_type: &upload.asset.mime_type,
                byte_size: upload.asset.byte_size,
                width: upload.asset.width,
                height: upload.asset.height,
                derivative_count: upload.derivatives.len(),
                success: true,
                error_kind: None,
            }),
            Err(error) => record_media_upload(MediaUploadDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                asset_id: None,
                usage_kind: MediaUsageKind::PetBackgroundLivePhoto,
                mime_type: &mime_type,
                byte_size,
                width: None,
                height: None,
                derivative_count: 0,
                success: false,
                error_kind: Some(pet_error_kind(error)),
            }),
        }
        result
    }

    pub async fn bind_uploaded_pet_media(
        &self,
        input: BindUploadedPetMediaInput,
    ) -> PetResult<maohuoban_pet_domain::pet::PetMediaUploadResult> {
        if self
            .repository
            .find_pet_for_owner(input.pet_id, input.owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        let owner_user_id = input.owner_user_id;
        let pet_id = input.pet_id;
        let asset_id = input.asset_id;
        let result = self.repository.bind_uploaded_pet_media(input).await;
        match &result {
            Ok(upload) => record_media_binding(MediaBindingDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                pet_id,
                asset_id,
                usage_kind: Some(upload.asset.usage_kind),
                width: upload.asset.width,
                height: upload.asset.height,
                derivative_count: upload.derivatives.len(),
                success: true,
                error_kind: None,
            }),
            Err(error) => record_media_binding(MediaBindingDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                pet_id,
                asset_id,
                usage_kind: None,
                width: None,
                height: None,
                derivative_count: 0,
                success: false,
                error_kind: Some(pet_error_kind(error)),
            }),
        }
        result
    }

    pub async fn list_media_display_metadata(
        &self,
        asset_ids: &[Uuid],
    ) -> PetResult<Vec<MediaAssetDisplayMetadata>> {
        self.repository.list_media_display_metadata(asset_ids).await
    }

    pub async fn create_pet_event(&self, input: NewPetEvent) -> PetResult<PetEvent> {
        validate_text("事件标题", &input.title)?;
        if self
            .repository
            .find_pet_for_owner(input.pet_id, input.actor_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository.create_pet_event(input).await
    }

    pub async fn import_trade_pet(
        &self,
        mut input: TradePetImportInput,
    ) -> PetResult<TradePetImport> {
        input.name = normalize_compact_text(&input.name);
        input.breed = normalize_optional_compact_text(input.breed);
        validate_pet_name(&input.name)?;
        validate_text("来源方", &input.seller_name)?;
        self.repository.import_trade_pet(input).await
    }

    pub async fn list_pet_profiles(&self, owner_user_id: Uuid) -> PetResult<Vec<PetProfile>> {
        self.repository
            .list_pet_profiles_for_owner(owner_user_id)
            .await
    }

    pub async fn load_pet_profile(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetProfile> {
        self.repository
            .find_pet_for_owner(pet_id, owner_user_id)
            .await?
            .ok_or(PetError::PetNotFound)
    }

    pub async fn load_pet_timeline(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetTimeline> {
        if self
            .repository
            .find_pet_for_owner(pet_id, owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository
            .load_pet_timeline(owner_user_id, pet_id, 50)
            .await
    }

    pub async fn load_pet_event_detail(
        &self,
        owner_user_id: Uuid,
        event_id: Uuid,
    ) -> PetResult<PetEvent> {
        self.repository
            .load_pet_event_detail(owner_user_id, event_id)
            .await?
            .ok_or(PetError::PetNotFound)
    }

    pub async fn load_merchant_dashboard(
        &self,
        owner_user_id: Uuid,
    ) -> PetResult<Option<MerchantDashboardSummary>> {
        let Some(merchant) = self
            .merchant_repository
            .find_verified_merchant_for_owner(owner_user_id)
            .await?
        else {
            return Ok(None);
        };

        let status_counts = self
            .merchant_repository
            .load_merchant_status_counts(merchant.id)
            .await?;
        let litters = self
            .merchant_repository
            .list_merchant_litter_summaries(merchant.id, 5)
            .await?;
        let relationships = self
            .merchant_repository
            .list_merchant_relationships(merchant.id, 20)
            .await?;
        let recent_events = self
            .merchant_repository
            .load_merchant_recent_events(merchant.id, 5)
            .await?;

        Ok(Some(MerchantDashboardSummary {
            merchant,
            status_counts,
            litters,
            relationships,
            recent_events,
        }))
    }

    pub async fn list_merchant_pets(
        &self,
        owner_user_id: Uuid,
        merchant_id: Uuid,
        status: ManagedPetStatus,
    ) -> PetResult<Vec<PetProfile>> {
        let Some(merchant) = self
            .merchant_repository
            .find_verified_merchant_for_owner(owner_user_id)
            .await?
        else {
            return Err(PetError::Forbidden);
        };
        if merchant.id != merchant_id {
            return Err(PetError::Forbidden);
        }

        self.merchant_repository
            .list_merchant_pets(merchant_id, status, 100)
            .await
    }

    pub async fn create_merchant_pet(
        &self,
        owner_user_id: Uuid,
        mut input: NewMerchantPetProfile,
    ) -> PetResult<PetProfile> {
        input.name = normalize_compact_text(&input.name);
        input.breed = normalize_optional_compact_text(input.breed);
        validate_pet_name(&input.name)?;
        if input.managed_status == ManagedPetStatus::Family {
            return Err(PetError::InvalidInput("商家宠物状态无效".to_owned()));
        }

        let Some(merchant) = self
            .merchant_repository
            .find_verified_merchant_for_owner(owner_user_id)
            .await?
        else {
            return Err(PetError::Forbidden);
        };
        if merchant.id != input.merchant_id {
            return Err(PetError::Forbidden);
        }

        self.merchant_repository.create_merchant_pet(input).await
    }

    pub async fn publish_available_status(
        &self,
        owner_user_id: Uuid,
        input: PublishAvailableStatusInput,
    ) -> PetResult<MerchantAvailableStatusPublication> {
        let Some(merchant) = self
            .merchant_repository
            .find_verified_merchant_for_owner(owner_user_id)
            .await?
        else {
            return Err(PetError::Forbidden);
        };
        if merchant.id != input.merchant_id || input.actor_user_id != owner_user_id {
            return Err(PetError::Forbidden);
        }

        self.merchant_repository
            .publish_available_status(input)
            .await
    }

    pub async fn load_merchant_litter_detail(
        &self,
        owner_user_id: Uuid,
        merchant_id: Uuid,
        litter_id: Uuid,
    ) -> PetResult<MerchantLitterDetail> {
        let Some(merchant) = self
            .merchant_repository
            .find_verified_merchant_for_owner(owner_user_id)
            .await?
        else {
            return Err(PetError::Forbidden);
        };
        if merchant.id != merchant_id {
            return Err(PetError::Forbidden);
        }

        self.merchant_repository
            .load_merchant_litter_detail(merchant_id, litter_id)
            .await?
            .ok_or(PetError::PetNotFound)
    }
}

/// validate_text 校验用户输入文案
/// 核心职责：
/// - 拒绝空白关键字段
/// - 输出可映射的领域错误
fn validate_text(label: &str, value: &str) -> PetResult<()> {
    if value.trim().is_empty() {
        return Err(PetError::InvalidInput(format!("{label}不能为空")));
    }
    Ok(())
}

/// validate_pet_name 校验宠物名称
/// 核心职责：
/// - 按去除空白后的文字数限制名称长度
/// - 输出稳定的领域错误文案
fn validate_pet_name(value: &str) -> PetResult<()> {
    let normalized = normalize_compact_text(value);
    validate_text("宠物名称", &normalized)?;
    if normalized.chars().count() > 6 {
        return Err(PetError::InvalidInput("宠物名称最多 6 个字".to_owned()));
    }
    Ok(())
}

/// normalize_compact_text 去除文本内全部空白字符
/// 核心职责：
/// - 统一宠物名称和品种的写入规范
/// - 让长度校验与最终持久化值保持一致
fn normalize_compact_text(value: &str) -> String {
    value
        .chars()
        .filter(|character| !character.is_whitespace())
        .collect()
}

/// normalize_optional_compact_text 规范化可选紧凑文本
/// 核心职责：
/// - 去除文本内全部空白字符
/// - 将空白结果映射为空值，避免持久化无意义文本
fn normalize_optional_compact_text(value: Option<String>) -> Option<String> {
    value
        .map(|text| normalize_compact_text(&text))
        .filter(|text| !text.is_empty())
}

fn pet_error_kind(error: &PetError) -> &'static str {
    match error {
        PetError::InvalidInput(_) => "invalid_input",
        PetError::NameEditLimitExceeded => "name_edit_limit_exceeded",
        PetError::PetNotFound => "pet_not_found",
        PetError::Forbidden => "forbidden",
        PetError::Infrastructure(_) => "infrastructure",
    }
}

fn validate_optional_microchip(value: Option<&str>) -> PetResult<()> {
    let Some(value) = value else {
        return Ok(());
    };
    let trimmed = value.trim();
    if trimmed.len() != 15 || !trimmed.chars().all(|character| character.is_ascii_digit()) {
        return Err(PetError::InvalidInput(
            "芯片号必须是 15 位纯数字".to_owned(),
        ));
    }
    Ok(())
}

fn validate_optional_weight(value: Option<i32>) -> PetResult<()> {
    if value.is_some_and(|weight| weight <= 0) {
        return Err(PetError::InvalidInput("体重必须大于 0".to_owned()));
    }
    Ok(())
}

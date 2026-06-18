use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_application::pet::TradePetImportInput;
use maohuoban_pet_domain::pet::{PetSex, PetSpecies};
use serde::Deserialize;
use uuid::Uuid;

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

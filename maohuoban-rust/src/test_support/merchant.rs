use chrono::NaiveDate;
use uuid::Uuid;

use super::AuthTestApp;

impl AuthTestApp {
    /// `seed_merchant_tracking_workspace` 写入商家追溯工作台数据
    /// 核心职责：
    /// - 为首页契约测试准备认证商家和窝次关系数据
    /// - 覆盖多宠状态、父母关系、同窝关系和商家事件
    ///
    /// # Panics
    ///
    /// 当 `owner_user_id` 不是合法 UUID，或任一测试数据写入失败时触发。
    pub async fn seed_merchant_tracking_workspace(&self, owner_user_id: &str) -> String {
        let owner_user_id = Uuid::parse_str(owner_user_id).expect("owner user id");
        let ids = MerchantWorkspaceSeedIds::new();
        seed_merchant_profile(&self.app.pool, ids.merchant, owner_user_id).await;
        seed_merchant_pets(&self.app.pool, &ids).await;
        seed_litter(&self.app.pool, &ids).await;
        seed_pet_relationships(&self.app.pool, &ids).await;
        seed_litter_event(&self.app.pool, &ids, owner_user_id).await;

        ids.merchant.to_string()
    }
}

/// `MerchantWorkspaceSeedIds` 商家追溯测试 ID 集
/// 核心职责：
/// - 固定契约测试中的 UUID
/// - 让测试断言和数据库关系稳定可重复
struct MerchantWorkspaceSeedIds {
    merchant: Uuid,
    sire_pet: Uuid,
    dam_pet: Uuid,
    kitten_one: Uuid,
    kitten_two: Uuid,
    needs_record_pet: Uuid,
    litter: Uuid,
}

impl MerchantWorkspaceSeedIds {
    fn new() -> Self {
        Self {
            merchant: parse_seed_uuid("3a85d5e7-1d03-41a1-9f8f-7c34a1e5a71f"),
            sire_pet: parse_seed_uuid("85d24083-8912-4793-8942-2d8470f366e1"),
            dam_pet: parse_seed_uuid("0537725e-0e21-4040-a144-a5ad430c188d"),
            kitten_one: parse_seed_uuid("9c7c59f6-ac8e-41d3-986d-93ce6fcd53e0"),
            kitten_two: parse_seed_uuid("3616e79c-9dbe-4e7a-a585-86cd7d89cfb2"),
            needs_record_pet: parse_seed_uuid("69f4570a-aea8-4197-a98c-33ed56c6ff78"),
            litter: parse_seed_uuid("cd324de4-9a24-45a4-adf8-679eb40b3db5"),
        }
    }
}

async fn seed_merchant_profile(pool: &sqlx::PgPool, merchant_id: Uuid, owner_user_id: Uuid) {
    sqlx::query(
        r"
        INSERT INTO merchant_profiles (
            id,
            owner_user_id,
            merchant_type,
            name,
            city,
            verification_status,
            verified_at
        )
        VALUES ($1, $2, 'cat_breeder', '梧桐猫舍', '成都', 'verified', now())
        ",
    )
    .bind(merchant_id)
    .bind(owner_user_id)
    .execute(pool)
    .await
    .expect("seed merchant profile");
}

async fn seed_merchant_pets(pool: &sqlx::PgPool, ids: &MerchantWorkspaceSeedIds) {
    for (pet_id, name, sex, managed_status, source_kind) in [
        (ids.sire_pet, "Leo", "male", "retained", "merchant_managed"),
        (
            ids.dam_pet,
            "Luna",
            "female",
            "retained",
            "merchant_managed",
        ),
        (
            ids.kitten_one,
            "小橘",
            "female",
            "available",
            "litter_birth",
        ),
        (ids.kitten_two, "小灰", "male", "available", "litter_birth"),
        (
            ids.needs_record_pet,
            "小白",
            "unknown",
            "needs_record",
            "litter_birth",
        ),
    ] {
        sqlx::query(
            r"
            INSERT INTO pet_profiles (
                id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                profile_number,
                managed_status,
                source_kind
            )
            VALUES ($1, $2, $3, 'cat', '布偶猫', $4, $5, $6, $7, $8)
            ",
        )
        .bind(pet_id)
        .bind(ids.merchant)
        .bind(name)
        .bind(sex)
        .bind(NaiveDate::from_ymd_opt(2026, 3, 18).expect("birthday"))
        .bind(profile_number_from_uuid(pet_id))
        .bind(managed_status)
        .bind(source_kind)
        .execute(pool)
        .await
        .expect("seed merchant pet");
    }
}

fn profile_number_from_uuid(id: Uuid) -> String {
    let raw = id.as_u128() % 10_000_000_000_000_000;
    format!("{raw:016}")
}

async fn seed_litter(pool: &sqlx::PgPool, ids: &MerchantWorkspaceSeedIds) {
    sqlx::query(
        r"
        INSERT INTO litters (
            id,
            merchant_id,
            name,
            species,
            sire_pet_id,
            dam_pet_id,
            born_at,
            born_count,
            alive_count,
            status
        )
        VALUES ($1, $2, '2026 春季 A 窝', 'cat', $3, $4, $5, 3, 3, 'active')
        ",
    )
    .bind(ids.litter)
    .bind(ids.merchant)
    .bind(ids.sire_pet)
    .bind(ids.dam_pet)
    .bind(NaiveDate::from_ymd_opt(2026, 3, 18).expect("born at"))
    .execute(pool)
    .await
    .expect("seed litter");
}

async fn seed_pet_relationships(pool: &sqlx::PgPool, ids: &MerchantWorkspaceSeedIds) {
    for (subject_pet_id, related_pet_id, relationship_kind, litter_ref) in [
        (ids.kitten_one, ids.sire_pet, "sire", None),
        (ids.kitten_one, ids.dam_pet, "dam", None),
        (
            ids.kitten_one,
            ids.kitten_two,
            "same_litter",
            Some(ids.litter),
        ),
        (
            ids.kitten_two,
            ids.kitten_one,
            "same_litter",
            Some(ids.litter),
        ),
        (
            ids.needs_record_pet,
            ids.kitten_one,
            "same_litter",
            Some(ids.litter),
        ),
    ] {
        sqlx::query(
            r"
            INSERT INTO pet_relationships (
                id,
                subject_pet_id,
                related_pet_id,
                litter_id,
                relationship_kind,
                source_kind
            )
            VALUES ($1, $2, $3, $4, $5, 'merchant_recorded')
            ",
        )
        .bind(Uuid::new_v4())
        .bind(subject_pet_id)
        .bind(related_pet_id)
        .bind(litter_ref)
        .bind(relationship_kind)
        .execute(pool)
        .await
        .expect("seed pet relationship");
    }
}

async fn seed_litter_event(
    pool: &sqlx::PgPool,
    ids: &MerchantWorkspaceSeedIds,
    owner_user_id: Uuid,
) {
    sqlx::query(
        r"
        INSERT INTO pet_events (
            id,
            litter_id,
            event_kind,
            event_subkind,
            title,
            summary,
            visibility,
            event_payload,
            occurred_at,
            actor_user_id,
            record_revision
        )
        VALUES (
            $1,
            $2,
            'merchant',
            'litter_birth',
            'A 窝出生记录',
            '3 只幼猫出生，父母关系已记录',
            'buyer_visible',
            $3,
            '2026-03-18T08:30:00Z',
            $4,
            1
        )
        ",
    )
    .bind(parse_seed_uuid("0d2972a6-37a9-4681-8220-2a6de291e3ee"))
    .bind(ids.litter)
    .bind(serde_json::json!({
        "born_count": 3,
        "alive_count": 3
    }))
    .bind(owner_user_id)
    .execute(pool)
    .await
    .expect("seed litter event");
}

fn parse_seed_uuid(raw: &str) -> Uuid {
    Uuid::parse_str(raw).expect("valid seed uuid")
}

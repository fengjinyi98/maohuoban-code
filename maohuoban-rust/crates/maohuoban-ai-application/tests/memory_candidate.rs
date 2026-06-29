// memory_candidate 记忆候选写入流程测试
// 核心职责：
// - 验证候选创建流程（先写 Pending 候选）
// - 验证宠物强事实必须经过用户确认才能升级
// - 验证偏好类候选可直接创建
// - 验证候选状态流转（Pending -> Confirmed / Rejected）

use maohuoban_ai_application::ai::memory::MemoryCandidateService;
use maohuoban_ai_application::ai::ports::MemoryCandidateRepository;
use maohuoban_ai_domain::ai::{
    AiError, AiResult, MemoryCandidate, MemoryCandidateKind, MemoryCandidateStatus, MemoryScope,
};
use std::sync::{Arc, Mutex};
use uuid::Uuid;

fn actor_user_id() -> Uuid {
    Uuid::parse_str("22222222-2222-2222-2222-222222222222").expect("actor user id")
}

fn pet_id() -> Uuid {
    Uuid::parse_str("33333333-3333-3333-3333-333333333333").expect("pet id")
}

// === Domain 层测试 ===

#[test]
fn pet_fact_candidate_requires_user_confirmation() {
    let candidate = MemoryCandidate {
        id: Uuid::new_v4(),
        scope_type: MemoryScope::Pet,
        scope_id: pet_id(),
        actor_user_id: actor_user_id(),
        candidate_kind: MemoryCandidateKind::PetFactCandidate,
        summary: "豆包最近换了主粮".to_owned(),
        source_message_id: None,
        confidence: 0.8,
        status: MemoryCandidateStatus::Pending,
        created_at: chrono::Utc::now(),
        confirmed_at: None,
    };

    assert!(candidate.requires_user_confirmation());
    assert!(candidate.is_pending());
}

#[test]
fn risk_signal_candidate_requires_user_confirmation() {
    let candidate = MemoryCandidate {
        id: Uuid::new_v4(),
        scope_type: MemoryScope::Pet,
        scope_id: pet_id(),
        actor_user_id: actor_user_id(),
        candidate_kind: MemoryCandidateKind::RiskSignal,
        summary: "豆包出现持续呕吐风险信号".to_owned(),
        source_message_id: None,
        confidence: 0.7,
        status: MemoryCandidateStatus::Pending,
        created_at: chrono::Utc::now(),
        confirmed_at: None,
    };

    assert!(candidate.requires_user_confirmation());
}

#[test]
fn preference_candidate_does_not_require_user_confirmation() {
    let candidate = MemoryCandidate {
        id: Uuid::new_v4(),
        scope_type: MemoryScope::User,
        scope_id: actor_user_id(),
        actor_user_id: actor_user_id(),
        candidate_kind: MemoryCandidateKind::PreferenceCandidate,
        summary: "用户希望回答简短".to_owned(),
        source_message_id: None,
        confidence: 0.9,
        status: MemoryCandidateStatus::Pending,
        created_at: chrono::Utc::now(),
        confirmed_at: None,
    };

    assert!(!candidate.requires_user_confirmation());
}

#[test]
fn candidate_confirm_transitions_to_confirmed() {
    let candidate = MemoryCandidate {
        id: Uuid::new_v4(),
        scope_type: MemoryScope::Pet,
        scope_id: pet_id(),
        actor_user_id: actor_user_id(),
        candidate_kind: MemoryCandidateKind::PetFactCandidate,
        summary: "test".to_owned(),
        source_message_id: None,
        confidence: 0.8,
        status: MemoryCandidateStatus::Pending,
        created_at: chrono::Utc::now(),
        confirmed_at: None,
    };

    let now = chrono::Utc::now();
    let confirmed = candidate.confirm(now);
    assert_eq!(confirmed.status, MemoryCandidateStatus::Confirmed);
    assert!(confirmed.confirmed_at.is_some());
    assert!(!confirmed.is_pending());
}

#[test]
fn candidate_reject_transitions_to_rejected() {
    let candidate = MemoryCandidate {
        id: Uuid::new_v4(),
        scope_type: MemoryScope::Pet,
        scope_id: pet_id(),
        actor_user_id: actor_user_id(),
        candidate_kind: MemoryCandidateKind::PetFactCandidate,
        summary: "test".to_owned(),
        source_message_id: None,
        confidence: 0.3,
        status: MemoryCandidateStatus::Pending,
        created_at: chrono::Utc::now(),
        confirmed_at: None,
    };

    let rejected = candidate.reject();
    assert_eq!(rejected.status, MemoryCandidateStatus::Rejected);
    assert!(!rejected.is_pending());
}

// === Application 层测试 ===

#[tokio::test]
async fn service_creates_pending_candidate_for_pet_fact() {
    let repo = Arc::new(InMemoryCandidateRepo::new());
    let service = MemoryCandidateService::new(repo.clone());

    let candidate_id = service
        .create_candidate(
            MemoryScope::Pet,
            pet_id(),
            actor_user_id(),
            MemoryCandidateKind::PetFactCandidate,
            "豆包最近换了主粮".to_owned(),
            None,
            0.8,
        )
        .await
        .expect("create candidate");

    // 验证候选已写入且为 Pending 状态
    let candidates = repo
        .get_pending_candidates(MemoryScope::Pet, pet_id(), actor_user_id())
        .await
        .expect("get pending");

    assert_eq!(candidates.len(), 1);
    assert_eq!(candidates[0].id, candidate_id);
    assert_eq!(candidates[0].status, MemoryCandidateStatus::Pending);
    assert_eq!(candidates[0].summary, "豆包最近换了主粮");
}

#[tokio::test]
async fn service_confirm_candidate_promotes_to_confirmed() {
    let repo = Arc::new(InMemoryCandidateRepo::new());
    let service = MemoryCandidateService::new(repo.clone());

    let candidate_id = service
        .create_candidate(
            MemoryScope::Pet,
            pet_id(),
            actor_user_id(),
            MemoryCandidateKind::PetFactCandidate,
            "豆包体重 5kg".to_owned(),
            None,
            0.9,
        )
        .await
        .expect("create candidate");

    // 确认候选
    service
        .confirm_candidate(candidate_id, actor_user_id())
        .await
        .expect("confirm");

    // 验证不再出现在 pending 列表中
    let pending = repo
        .get_pending_candidates(MemoryScope::Pet, pet_id(), actor_user_id())
        .await
        .expect("get pending");

    assert!(
        pending.is_empty(),
        "confirmed candidate should not be pending"
    );

    // 验证状态已变更
    let candidate = repo
        .get_by_id(candidate_id)
        .await
        .expect("get by id")
        .expect("candidate exists");

    assert_eq!(candidate.status, MemoryCandidateStatus::Confirmed);
    assert!(candidate.confirmed_at.is_some());
}

#[tokio::test]
async fn service_reject_candidate_marks_rejected() {
    let repo = Arc::new(InMemoryCandidateRepo::new());
    let service = MemoryCandidateService::new(repo.clone());

    let candidate_id = service
        .create_candidate(
            MemoryScope::Pet,
            pet_id(),
            actor_user_id(),
            MemoryCandidateKind::PetFactCandidate,
            "豆包可能生病了".to_owned(),
            None,
            0.4,
        )
        .await
        .expect("create candidate");

    service
        .reject_candidate(candidate_id, actor_user_id())
        .await
        .expect("reject");

    let pending = repo
        .get_pending_candidates(MemoryScope::Pet, pet_id(), actor_user_id())
        .await
        .expect("get pending");

    assert!(
        pending.is_empty(),
        "rejected candidate should not be pending"
    );
}

#[tokio::test]
async fn service_creates_preference_candidate_without_confirmation() {
    let repo = Arc::new(InMemoryCandidateRepo::new());
    let service = MemoryCandidateService::new(repo.clone());

    let candidate_id = service
        .create_candidate(
            MemoryScope::User,
            actor_user_id(),
            actor_user_id(),
            MemoryCandidateKind::PreferenceCandidate,
            "用户希望回答简短".to_owned(),
            None,
            0.9,
        )
        .await
        .expect("create candidate");

    let candidate = repo
        .get_by_id(candidate_id)
        .await
        .expect("get by id")
        .expect("candidate exists");

    // 偏好类候选不需要用户确认
    assert!(!candidate.requires_user_confirmation());
    assert_eq!(candidate.status, MemoryCandidateStatus::Pending);
}

#[tokio::test]
async fn service_confirm_rejects_unauthorized_actor() {
    let repo = Arc::new(InMemoryCandidateRepo::new());
    let service = MemoryCandidateService::new(repo.clone());

    let candidate_id = service
        .create_candidate(
            MemoryScope::Pet,
            pet_id(),
            actor_user_id(),
            MemoryCandidateKind::PetFactCandidate,
            "豆包体重 5kg".to_owned(),
            None,
            0.9,
        )
        .await
        .expect("create candidate");

    // 其他用户尝试确认，应被拒绝
    let result = service
        .confirm_candidate(candidate_id, other_user_id())
        .await;
    assert!(
        matches!(result, Err(AiError::Unauthorized)),
        "confirming another user's candidate must return Unauthorized"
    );

    // 验证候选仍为 Pending
    let candidate = repo
        .get_by_id(candidate_id)
        .await
        .expect("get by id")
        .expect("candidate exists");
    assert_eq!(candidate.status, MemoryCandidateStatus::Pending);
}

#[tokio::test]
async fn service_reject_rejects_unauthorized_actor() {
    let repo = Arc::new(InMemoryCandidateRepo::new());
    let service = MemoryCandidateService::new(repo.clone());

    let candidate_id = service
        .create_candidate(
            MemoryScope::Pet,
            pet_id(),
            actor_user_id(),
            MemoryCandidateKind::PetFactCandidate,
            "豆包可能生病了".to_owned(),
            None,
            0.4,
        )
        .await
        .expect("create candidate");

    // 其他用户尝试拒绝，应被拒绝
    let result = service
        .reject_candidate(candidate_id, other_user_id())
        .await;
    assert!(
        matches!(result, Err(AiError::Unauthorized)),
        "rejecting another user's candidate must return Unauthorized"
    );

    // 验证候选仍为 Pending
    let candidate = repo
        .get_by_id(candidate_id)
        .await
        .expect("get by id")
        .expect("candidate exists");
    assert_eq!(candidate.status, MemoryCandidateStatus::Pending);
}

fn other_user_id() -> Uuid {
    Uuid::parse_str("66666666-6666-6666-6666-666666666666").expect("other user id")
}

// === Fake 实现 ===

struct InMemoryCandidateRepo {
    candidates: Mutex<Vec<MemoryCandidate>>,
}

impl InMemoryCandidateRepo {
    fn new() -> Self {
        Self {
            candidates: Mutex::new(Vec::new()),
        }
    }
}

#[async_trait::async_trait]
impl MemoryCandidateRepository for InMemoryCandidateRepo {
    async fn insert_candidate(&self, candidate: &MemoryCandidate) -> AiResult<()> {
        self.candidates
            .lock()
            .expect("lock")
            .push(candidate.clone());
        Ok(())
    }

    async fn get_pending_candidates(
        &self,
        scope_type: MemoryScope,
        scope_id: Uuid,
        actor_user_id: Uuid,
    ) -> AiResult<Vec<MemoryCandidate>> {
        let candidates = self.candidates.lock().expect("lock");
        Ok(candidates
            .iter()
            .filter(|c| {
                c.scope_type == scope_type
                    && c.scope_id == scope_id
                    && c.actor_user_id == actor_user_id
                    && c.is_pending()
            })
            .cloned()
            .collect())
    }

    async fn update_status(
        &self,
        id: Uuid,
        _actor_user_id: Uuid,
        status: MemoryCandidateStatus,
        confirmed_at: Option<chrono::DateTime<chrono::Utc>>,
    ) -> AiResult<()> {
        let mut candidates = self.candidates.lock().expect("lock");
        for c in candidates.iter_mut() {
            if c.id == id {
                c.status = status;
                c.confirmed_at = confirmed_at;
            }
        }
        Ok(())
    }

    async fn get_by_id(&self, id: Uuid) -> AiResult<Option<MemoryCandidate>> {
        let candidates = self.candidates.lock().expect("lock");
        Ok(candidates.iter().find(|c| c.id == id).cloned())
    }
}

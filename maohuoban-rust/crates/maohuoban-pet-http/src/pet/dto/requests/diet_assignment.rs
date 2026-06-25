use maohuoban_pet_application::pet::{SetPetCurrentStapleInput, SetPetDietAssignmentInput};
use maohuoban_pet_domain::pet::DietAssignmentRole;
use serde::Deserialize;
use uuid::Uuid;

/// SetPetCurrentStapleRequest 设为当前主粮请求
#[derive(Debug, Deserialize)]
pub(crate) struct SetPetCurrentStapleRequest {
    food_item_id: Uuid,
    reason: Option<String>,
}

impl SetPetCurrentStapleRequest {
    pub(crate) fn into_input(
        self,
        pet_id: Uuid,
        created_by_user_id: Uuid,
    ) -> SetPetCurrentStapleInput {
        SetPetCurrentStapleInput {
            pet_id,
            food_item_id: self.food_item_id,
            created_by_user_id,
            reason: self.reason,
        }
    }
}

/// SetPetDietAssignmentRequest 饮食配置请求
#[derive(Debug, Deserialize)]
pub(crate) struct SetPetDietAssignmentRequest {
    food_item_id: Uuid,
    role: DietAssignmentRole,
    reason: Option<String>,
}

impl SetPetDietAssignmentRequest {
    pub(crate) fn into_input(
        self,
        pet_id: Uuid,
        created_by_user_id: Uuid,
    ) -> SetPetDietAssignmentInput {
        SetPetDietAssignmentInput {
            pet_id,
            food_item_id: self.food_item_id,
            role: self.role,
            created_by_user_id,
            reason: self.reason,
        }
    }
}

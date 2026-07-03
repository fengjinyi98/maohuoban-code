use maohuoban_ai_domain::ai::AiPetDisplaySnapshot;
use uuid::Uuid;

pub fn pet_display_snapshot(name: &str) -> AiPetDisplaySnapshot {
    AiPetDisplaySnapshot {
        pet_id: Uuid::new_v4(),
        pet_name: name.to_owned(),
        pet_avatar_url: None,
        pet_species: "cat".to_owned(),
        profile_number: "P001".to_owned(),
    }
}

use maohuoban_pet_domain::pet::PetError;

pub(super) fn to_infrastructure_error(error: sqlx::Error) -> PetError {
    PetError::Infrastructure(error.to_string())
}

use std::fmt::Write as _;

use maohuoban_pet_domain::pet::PetError;
use sha2::{Digest, Sha256};
use uuid::Uuid;

pub(super) fn profile_number_from_uuid(id: Uuid) -> String {
    let raw = id.as_u128() % 10_000_000_000_000_000;
    format!("{raw:016}")
}

pub(super) fn sha256_hex(content: &[u8]) -> String {
    let digest = Sha256::digest(content);
    digest.iter().fold(String::new(), |mut output, byte| {
        write!(&mut output, "{byte:02x}").expect("write sha256 hex");
        output
    })
}

pub(super) fn sanitized_file_name(file_name: &str) -> String {
    let sanitized = file_name
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() || matches!(character, '.' | '-' | '_') {
                character
            } else {
                '_'
            }
        })
        .collect::<String>();
    if sanitized.is_empty() {
        Uuid::new_v4().to_string()
    } else {
        sanitized
    }
}

pub(super) fn to_infrastructure_error(error: sqlx::Error) -> PetError {
    PetError::Infrastructure(error.to_string())
}

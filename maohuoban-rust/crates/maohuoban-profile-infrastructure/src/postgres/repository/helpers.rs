use std::fmt::Write as _;

use chrono::{DateTime, Datelike, Duration, Utc};
use maohuoban_profile_domain::profile::{ProfileError, ProfileFieldEditPolicy, ProfileResult};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use super::PROFILE_FIELD_EDIT_WINDOW_DAYS;

pub(super) fn generate_maohuoban_id() -> String {
    Uuid::new_v4()
        .simple()
        .to_string()
        .chars()
        .take(12)
        .map(|c| c.to_ascii_uppercase())
        .collect()
}

pub(super) fn to_profile_error(error: &sqlx::Error) -> ProfileError {
    ProfileError::Infrastructure(error.to_string())
}

pub(super) fn sha256_hex(content: &[u8]) -> String {
    let digest = Sha256::digest(content);
    digest.iter().fold(String::new(), |mut output, byte| {
        write!(&mut output, "{byte:02x}").expect("write sha256 hex");
        output
    })
}

pub(super) fn to_i32_dimension(value: u32) -> ProfileResult<i32> {
    i32::try_from(value)
        .ok()
        .filter(|v| *v > 0)
        .ok_or(ProfileError::MediaDecodeFailed)
}

pub(super) fn image_error_kind(error: &image::ImageError) -> &'static str {
    match error {
        image::ImageError::Decoding(_) => "decoding",
        image::ImageError::Encoding(_) => "encoding",
        image::ImageError::Parameter(_) => "parameter",
        image::ImageError::Limits(_) => "limits",
        image::ImageError::Unsupported(_) => "unsupported",
        image::ImageError::IoError(_) => "io",
    }
}

pub(super) fn profile_field_edit_policy(
    used_count: i64,
    first_changed_at: Option<DateTime<Utc>>,
    max_count: i32,
    display_name: &str,
) -> ProfileFieldEditPolicy {
    let used_count = i32::try_from(used_count).unwrap_or(i32::MAX);
    let remaining_count = max_count.saturating_sub(used_count).max(0);
    let window_ends_at = first_changed_at
        .map(|changed_at| changed_at + Duration::days(i64::from(PROFILE_FIELD_EDIT_WINDOW_DAYS)));
    let display_text = window_ends_at.map_or_else(
        || format!("{PROFILE_FIELD_EDIT_WINDOW_DAYS} 天内最多修改 {max_count} 次{display_name}。"),
        |ends_at| {
            format!(
                "{}月{}日前还可以修改 {remaining_count} 次{display_name}。",
                ends_at.month(),
                ends_at.day()
            )
        },
    );

    ProfileFieldEditPolicy {
        max_count,
        used_count,
        remaining_count,
        window_days: PROFILE_FIELD_EDIT_WINDOW_DAYS,
        window_ends_at,
        display_text,
    }
}

use std::collections::HashMap;

use chrono::{Datelike, NaiveDate, Utc};
use maohuoban_home_domain::home::{
    HeroLivePhotoCrop, HeroLivePhotoSummary, HomeStorylineKind, HomeStorylineSummary,
    PetHeroSummary, PetNameEditPolicy as HomePetNameEditPolicy,
    PetNeuterStatus as HomePetNeuterStatus, PetSex as HomePetSex, PetSpecies as HomePetSpecies,
    PetSwitchItem,
};
use maohuoban_pet_application::pet::MediaAssetDisplayMetadata;
use maohuoban_pet_domain::pet::{
    PetBackgroundMediaKind, PetNameEditPolicy as DomainPetNameEditPolicy,
    PetNeuterStatus as DomainPetNeuterStatus, PetProfile, PetSex as DomainPetSex,
    PetSpecies as DomainPetSpecies, days_since_date,
};
use uuid::Uuid;

pub(super) fn selected_pet(
    pets: &[PetProfile],
    selected_pet_id: Option<Uuid>,
) -> Option<&PetProfile> {
    selected_pet_id
        .and_then(|pet_id| pets.iter().find(|pet| pet.id == pet_id))
        .or_else(|| pets.first())
}

pub(super) fn media_asset_ids(pets: &[PetProfile]) -> Vec<Uuid> {
    pets.iter()
        .flat_map(|pet| [pet.avatar_asset_id, pet.background_asset_id])
        .flatten()
        .collect()
}

pub(super) fn pet_hero_summary(
    pet: &PetProfile,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
) -> PetHeroSummary {
    let companionship_start_date = pet
        .arrival_date
        .unwrap_or_else(|| pet.created_at.date_naive());
    let today = Utc::now().date_naive();
    let companionship_days = Some(days_since_for_home(companionship_start_date, today));
    let world_days = pet
        .birthday
        .map(|birthday| days_since_for_home(birthday, today));
    let avatar_metadata = pet
        .avatar_asset_id
        .and_then(|asset_id| media_metadata.get(&asset_id));
    let background_metadata = pet
        .background_asset_id
        .and_then(|asset_id| media_metadata.get(&asset_id));
    let hero_theme_color_hex = background_metadata.and_then(|metadata| {
        metadata
            .theme_color_hex
            .as_deref()
            .filter(|value| !value.is_empty())
            .map(ToOwned::to_owned)
    });
    let hero_content_color_scheme = hero_theme_color_hex
        .as_deref()
        .and_then(hero_content_color_scheme);

    PetHeroSummary {
        id: pet.id,
        name: pet.name.clone(),
        species: home_pet_species(pet.species),
        breed: pet.breed.clone().unwrap_or_else(|| "未填写品种".to_owned()),
        sex: home_pet_sex(pet.sex),
        age_text: pet_age_text(pet.birthday),
        status_text: "记录正在形成可信档案".to_owned(),
        updated_text: "档案已同步".to_owned(),
        avatar_url: pet.avatar_asset_id.map(media_asset_url),
        avatar_width: avatar_metadata.and_then(|metadata| metadata.width),
        avatar_height: avatar_metadata.and_then(|metadata| metadata.height),
        hero_image_url: hero_image_url(pet),
        hero_image_width: hero_image_dimensions(pet, background_metadata).0,
        hero_image_height: hero_image_dimensions(pet, background_metadata).1,
        hero_video_url: hero_video_url(pet),
        hero_video_width: hero_video_dimensions(pet, background_metadata).0,
        hero_video_height: hero_video_dimensions(pet, background_metadata).1,
        hero_live_photo: hero_live_photo(pet, background_metadata),
        hero_theme_color_hex,
        hero_content_color_scheme,
        profile_number: Some(pet.profile_number.clone()),
        microchip_number: pet.microchip_number.clone(),
        birthday: pet.birthday,
        arrival_date: pet.arrival_date,
        world_days,
        weight_grams: pet.weight_grams,
        neuter_status: Some(home_pet_neuter_status(pet.neuter_status)),
        personality_tags: pet.personality_tags.clone(),
        note: pet.note.clone(),
        name_edit_policy: pet.name_edit_policy.as_ref().map(home_name_edit_policy),
        companionship_days,
    }
}

/// `days_since_for_home` 转换宠物领域天数为首页 DTO 数值
/// 核心职责：
/// - 复用宠物领域统一天数口径
/// - 保证首页 DTO 的 i32 边界稳定
fn days_since_for_home(start_date: chrono::NaiveDate, today: chrono::NaiveDate) -> i32 {
    let days = days_since_date(start_date, today);
    i32::try_from(days).unwrap_or(i32::MAX)
}

pub(super) fn pet_switch_item(
    pet: &PetProfile,
    is_selected: bool,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
) -> PetSwitchItem {
    let avatar_metadata = pet
        .avatar_asset_id
        .and_then(|asset_id| media_metadata.get(&asset_id));

    PetSwitchItem {
        id: pet.id,
        name: pet.name.clone(),
        species: home_pet_species(pet.species),
        breed: pet.breed.clone().unwrap_or_default(),
        avatar_url: pet.avatar_asset_id.map(media_asset_url),
        avatar_width: avatar_metadata.and_then(|metadata| metadata.width),
        avatar_height: avatar_metadata.and_then(|metadata| metadata.height),
        profile_number: Some(pet.profile_number.clone()),
        microchip_number: pet.microchip_number.clone(),
        birthday: pet.birthday,
        arrival_date: pet.arrival_date,
        weight_grams: pet.weight_grams,
        neuter_status: Some(home_pet_neuter_status(pet.neuter_status)),
        personality_tags: pet.personality_tags.clone(),
        note: pet.note.clone(),
        name_edit_policy: pet.name_edit_policy.as_ref().map(home_name_edit_policy),
        is_selected,
    }
}

pub(super) fn pet_storylines(pet: &PetProfile) -> Vec<HomeStorylineSummary> {
    let cover_url = pet.avatar_asset_id.map(media_asset_url);
    [
        pet.birthday.map(|anchor_date| HomeStorylineSummary {
            id: format!("{}-birth", pet.id),
            kind: HomeStorylineKind::Birth,
            title: "第一次来到这个世界".to_owned(),
            anchor_date,
            cover_url: cover_url.clone(),
            entry_count: 0,
        }),
        pet.arrival_date.map(|anchor_date| HomeStorylineSummary {
            id: format!("{}-homecoming", pet.id),
            kind: HomeStorylineKind::Homecoming,
            title: "到家的第一天".to_owned(),
            anchor_date,
            cover_url,
            entry_count: 0,
        }),
    ]
    .into_iter()
    .flatten()
    .collect()
}

fn home_name_edit_policy(policy: &DomainPetNameEditPolicy) -> HomePetNameEditPolicy {
    HomePetNameEditPolicy {
        max_count: policy.max_count,
        used_count: policy.used_count,
        remaining_count: policy.remaining_count,
        window_days: policy.window_days,
        window_ends_at: policy.window_ends_at,
        display_text: policy.display_text.clone(),
    }
}

fn hero_image_url(pet: &PetProfile) -> Option<String> {
    match pet.background_media_kind {
        Some(PetBackgroundMediaKind::Image) => pet.background_asset_id.map(media_asset_url),
        _ => None,
    }
}

fn hero_video_url(pet: &PetProfile) -> Option<String> {
    match pet.background_media_kind {
        Some(PetBackgroundMediaKind::Video) => pet.background_asset_id.map(media_asset_url),
        _ => None,
    }
}

fn hero_image_dimensions(
    pet: &PetProfile,
    metadata: Option<&MediaAssetDisplayMetadata>,
) -> (Option<i32>, Option<i32>) {
    match pet.background_media_kind {
        Some(PetBackgroundMediaKind::Image) => media_dimensions(metadata),
        _ => (None, None),
    }
}

fn hero_video_dimensions(
    pet: &PetProfile,
    metadata: Option<&MediaAssetDisplayMetadata>,
) -> (Option<i32>, Option<i32>) {
    match pet.background_media_kind {
        Some(PetBackgroundMediaKind::Video) => media_dimensions(metadata),
        _ => (None, None),
    }
}

fn hero_live_photo(
    pet: &PetProfile,
    metadata: Option<&MediaAssetDisplayMetadata>,
) -> Option<HeroLivePhotoSummary> {
    if pet.background_media_kind != Some(PetBackgroundMediaKind::LivePhoto) {
        return None;
    }
    let metadata = metadata?;
    Some(HeroLivePhotoSummary {
        still_url: metadata.live_photo_still_url.clone()?,
        still_width: metadata.live_photo_still_width,
        still_height: metadata.live_photo_still_height,
        paired_video_url: metadata.live_photo_paired_video_url.clone()?,
        paired_video_width: metadata.live_photo_paired_video_width,
        paired_video_height: metadata.live_photo_paired_video_height,
        paired_video_duration_ms: metadata.live_photo_paired_video_duration_ms,
        crop: metadata.crop_metadata.map(|crop| HeroLivePhotoCrop {
            x: crop.x,
            y: crop.y,
            width: crop.width,
            height: crop.height,
        }),
    })
}

fn media_dimensions(metadata: Option<&MediaAssetDisplayMetadata>) -> (Option<i32>, Option<i32>) {
    metadata.map_or((None, None), |metadata| (metadata.width, metadata.height))
}

fn hero_content_color_scheme(hex: &str) -> Option<String> {
    let (red, green, blue) = parse_hex_rgb(hex)?;
    let luminance = relative_luminance(red, green, blue);
    Some(if luminance > 0.46 { "light" } else { "dark" }.to_owned())
}

fn parse_hex_rgb(hex: &str) -> Option<(u8, u8, u8)> {
    let value = hex.strip_prefix('#').unwrap_or(hex);
    if value.len() != 6 {
        return None;
    }
    let red = u8::from_str_radix(&value[0..2], 16).ok()?;
    let green = u8::from_str_radix(&value[2..4], 16).ok()?;
    let blue = u8::from_str_radix(&value[4..6], 16).ok()?;
    Some((red, green, blue))
}

fn relative_luminance(red: u8, green: u8, blue: u8) -> f64 {
    fn linear_channel(value: u8) -> f64 {
        let normalized = f64::from(value) / 255.0;
        if normalized <= 0.03928 {
            normalized / 12.92
        } else {
            ((normalized + 0.055) / 1.055).powf(2.4)
        }
    }

    0.2126 * linear_channel(red) + 0.7152 * linear_channel(green) + 0.0722 * linear_channel(blue)
}

fn media_asset_url(asset_id: Uuid) -> String {
    format!("/api/v1/media/assets/{asset_id}/content")
}

fn home_pet_species(species: DomainPetSpecies) -> HomePetSpecies {
    match species {
        DomainPetSpecies::Dog => HomePetSpecies::Dog,
        DomainPetSpecies::Cat => HomePetSpecies::Cat,
        DomainPetSpecies::Other => HomePetSpecies::Other,
    }
}

fn home_pet_sex(sex: DomainPetSex) -> HomePetSex {
    match sex {
        DomainPetSex::Female => HomePetSex::Female,
        DomainPetSex::Male => HomePetSex::Male,
        DomainPetSex::Unknown => HomePetSex::Unknown,
    }
}

fn home_pet_neuter_status(status: DomainPetNeuterStatus) -> HomePetNeuterStatus {
    match status {
        DomainPetNeuterStatus::Unknown => HomePetNeuterStatus::Unknown,
        DomainPetNeuterStatus::Intact => HomePetNeuterStatus::Intact,
        DomainPetNeuterStatus::Neutered => HomePetNeuterStatus::Neutered,
    }
}

fn pet_age_text(birthday: Option<NaiveDate>) -> String {
    let Some(birthday) = birthday else {
        return "未填写年龄".to_owned();
    };
    let today = Utc::now().date_naive();
    if birthday > today {
        return "未填写年龄".to_owned();
    }
    let mut years = today.year() - birthday.year();
    if (today.month(), today.day()) < (birthday.month(), birthday.day()) {
        years -= 1;
    }
    if years > 0 {
        format!("{years}岁")
    } else {
        "未满1岁".to_owned()
    }
}

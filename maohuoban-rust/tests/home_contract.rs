#![allow(clippy::needless_pass_by_value)]

#[path = "home_contract/support.rs"]
mod support;

use support::*;

#[path = "home_contract/empty_merchant.rs"]
mod empty_merchant;
#[path = "home_contract/fallback_care.rs"]
mod fallback_care;
#[path = "home_contract/media.rs"]
mod media;
#[path = "home_contract/merchant_recommendation.rs"]
mod merchant_recommendation;
#[path = "home_contract/pet_dashboard.rs"]
mod pet_dashboard;
#[path = "home_contract/public_events.rs"]
mod public_events;

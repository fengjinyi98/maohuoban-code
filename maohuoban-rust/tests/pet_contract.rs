#![allow(clippy::needless_pass_by_value)]

#[path = "pet_contract/support.rs"]
mod support;

use support::*;

#[path = "pet_contract/auth_trade.rs"]
mod auth_trade;
#[path = "pet_contract/identity_context.rs"]
mod identity_context;
#[path = "pet_contract/media_background.rs"]
mod media_background;
#[path = "pet_contract/media_basic.rs"]
mod media_basic;
#[path = "pet_contract/media_derivatives_cleanup.rs"]
mod media_derivatives_cleanup;
#[path = "pet_contract/merchant.rs"]
mod merchant;
#[path = "pet_contract/profile_crud.rs"]
mod profile_crud;
#[path = "pet_contract/profile_delete.rs"]
mod profile_delete;
#[path = "pet_contract/profile_events.rs"]
mod profile_events;

#![allow(clippy::needless_pass_by_value)]

#[path = "pet_contract/support.rs"]
mod support;

use support::*;

#[path = "pet_contract/abnormal_episode.rs"]
mod abnormal_episode;
#[path = "pet_contract/abnormal_episode_table_test.rs"]
mod abnormal_episode_table_test;
#[path = "pet_contract/agent_confirmation_task_test.rs"]
mod agent_confirmation_task_test;
#[path = "pet_contract/auth_trade.rs"]
mod auth_trade;
#[path = "pet_contract/diet_assignment.rs"]
mod diet_assignment;
#[path = "pet_contract/feeding_event.rs"]
mod feeding_event;
#[path = "pet_contract/feeding_event_archived.rs"]
mod feeding_event_archived;
#[path = "pet_contract/food_inventory_crud.rs"]
mod food_inventory_crud;
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
#[path = "pet_contract/pet_album.rs"]
mod pet_album;
#[path = "pet_contract/pet_event_attachments.rs"]
mod pet_event_attachments;
#[path = "pet_contract/profile_crud.rs"]
mod profile_crud;
#[path = "pet_contract/profile_delete.rs"]
mod profile_delete;
#[path = "pet_contract/profile_events.rs"]
mod profile_events;
#[path = "pet_contract/weight_record.rs"]
mod weight_record;

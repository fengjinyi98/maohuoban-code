mod error;
mod model;

pub use error::{ProfileError, ProfileResult};
pub use model::{
    AvatarPresentation, AvatarSex, AvatarSexVisibility, ProfileFieldEditPolicy, UserGender,
    UserProfile,
};

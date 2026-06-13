mod error;
mod model;

pub use error::{PetError, PetResult};
pub use model::{
    EventKind, EventVisibility, ManagedPetStatus, PetEvent, PetProfile, PetSex, PetSourceKind,
    PetSpecies, PetTimeline,
};

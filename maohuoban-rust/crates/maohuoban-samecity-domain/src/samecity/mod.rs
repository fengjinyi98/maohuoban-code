mod error;
mod model;

pub use error::{SameCityError, SameCityResult};
pub use model::{
    Hospital, HospitalAppointment, HospitalAppointmentStatus, HospitalPartnershipStatus,
    VerificationStatus,
};

mod error;
mod model;

pub use error::{RecommendationError, RecommendationResult};
pub use model::{
    HomePartnerRecommendation, HomeRecommendedContent, HomeRecommendedContentKind,
    HomeRelationshipKind,
};

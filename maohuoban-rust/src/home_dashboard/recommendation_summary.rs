use maohuoban_home_domain::home::{
    PartnerRecommendation, PartnerRelationshipKind, RecommendedContent, RecommendedContentKind,
};
use maohuoban_recommendation_domain::recommendation::{
    HomePartnerRecommendation, HomeRecommendedContent,
    HomeRecommendedContentKind as RecommendationContentKind,
    HomeRelationshipKind as RecommendationRelationshipKind,
};

pub(super) fn partner_recommendation_summary(
    recommendation: HomePartnerRecommendation,
) -> PartnerRecommendation {
    PartnerRecommendation {
        pet_id: recommendation.pet_id,
        pet_name: recommendation.pet_name,
        relationship_kind: home_relationship_kind(recommendation.relationship_kind),
        title: recommendation.title,
        subtitle: recommendation.subtitle,
        distance_text: recommendation.distance_text,
    }
}

fn home_relationship_kind(kind: RecommendationRelationshipKind) -> PartnerRelationshipKind {
    match kind {
        RecommendationRelationshipKind::SameLitter => PartnerRelationshipKind::SameLitter,
        RecommendationRelationshipKind::SameCity => PartnerRelationshipKind::SameCity,
        RecommendationRelationshipKind::SameCondition => PartnerRelationshipKind::SameCondition,
        RecommendationRelationshipKind::SameHospital => PartnerRelationshipKind::SameHospital,
        RecommendationRelationshipKind::SameSource => PartnerRelationshipKind::SameSource,
    }
}

pub(super) fn recommended_content_summary(content: HomeRecommendedContent) -> RecommendedContent {
    RecommendedContent {
        id: content.id,
        kind: home_recommended_content_kind(content.kind),
        title: content.title,
        source_text: content.source_text,
    }
}

fn home_recommended_content_kind(kind: RecommendationContentKind) -> RecommendedContentKind {
    match kind {
        RecommendationContentKind::Ugc => RecommendedContentKind::Ugc,
        RecommendationContentKind::Guide => RecommendedContentKind::Guide,
        RecommendationContentKind::LocalService => RecommendedContentKind::LocalService,
    }
}

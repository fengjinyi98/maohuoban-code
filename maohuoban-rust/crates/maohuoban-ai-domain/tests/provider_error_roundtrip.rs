use maohuoban_ai_domain::ai::{
    PROVIDER_USER_VISIBLE_FAILURE_MESSAGE, ProviderError, ProviderErrorCategory,
};

#[test]
fn provider_error_category_roundtrips_as_frozen_snake_case_strings() {
    let cases = [
        (ProviderErrorCategory::NotConfigured, "not_configured"),
        (ProviderErrorCategory::Timeout, "timeout"),
        (ProviderErrorCategory::RateLimited, "rate_limited"),
        (ProviderErrorCategory::Upstream, "upstream"),
        (
            ProviderErrorCategory::StreamInterrupted,
            "stream_interrupted",
        ),
        (ProviderErrorCategory::InvalidResponse, "invalid_response"),
    ];

    for (category, expected) in cases {
        let serialized = serde_json::to_string(&category).expect("category should serialize");
        assert_eq!(serialized, format!("\"{expected}\""));

        let decoded: ProviderErrorCategory =
            serde_json::from_str(&serialized).expect("category should deserialize");
        assert_eq!(decoded, category);
        assert_eq!(category.as_str(), expected);
    }
}

#[test]
fn provider_error_category_declares_retryability() {
    assert!(!ProviderErrorCategory::NotConfigured.is_retryable());
    assert!(ProviderErrorCategory::Timeout.is_retryable());
    assert!(ProviderErrorCategory::RateLimited.is_retryable());
    assert!(ProviderErrorCategory::Upstream.is_retryable());
    assert!(ProviderErrorCategory::StreamInterrupted.is_retryable());
    assert!(!ProviderErrorCategory::InvalidResponse.is_retryable());
}

#[test]
fn provider_error_keeps_internal_category_and_stable_user_message() {
    let error = ProviderError::new(ProviderErrorCategory::RateLimited, "quota exhausted");

    assert_eq!(error.category(), ProviderErrorCategory::RateLimited);
    assert!(error.is_retryable());
    assert_eq!(
        error.user_visible_message(),
        PROVIDER_USER_VISIBLE_FAILURE_MESSAGE
    );
    assert!(
        !error
            .to_string()
            .contains(PROVIDER_USER_VISIBLE_FAILURE_MESSAGE)
    );
}

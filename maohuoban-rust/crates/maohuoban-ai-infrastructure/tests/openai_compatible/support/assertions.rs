use maohuoban_ai_domain::ai::{AiError, ProviderErrorCategory};

pub fn assert_provider_category(error: AiError, expected: ProviderErrorCategory) {
    match error {
        AiError::Provider(provider_error) => {
            assert_eq!(provider_error.category(), expected);
            assert_eq!(provider_error.is_retryable(), expected.is_retryable());
        }
        other => panic!("expected provider error category {expected:?}, got {other:?}"),
    }
}

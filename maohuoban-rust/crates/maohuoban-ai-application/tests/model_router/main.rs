use maohuoban_ai_application::ai::model_router::{ModelRouteConfig, ModelRouter, ModelRouterError};

#[test]
fn model_router_resolves_labels_to_configured_models() {
    let router = ModelRouter::new([
        ModelRouteConfig::new("lite", "gpt-4.1-mini"),
        ModelRouteConfig::new("primary", "gpt-4.1"),
        ModelRouteConfig::new("pro", "gpt-4.1-pro"),
        ModelRouteConfig::new("memory", "gpt-4.1-mini-memory"),
    ]);

    assert_eq!(
        router.resolve("lite").expect("lite should resolve").model(),
        "gpt-4.1-mini"
    );
    assert_eq!(
        router
            .resolve("primary")
            .expect("primary should resolve")
            .model(),
        "gpt-4.1"
    );
    assert_eq!(
        router
            .resolve("memory")
            .expect("memory should resolve")
            .model(),
        "gpt-4.1-mini-memory"
    );
}

#[test]
fn model_router_rejects_unknown_or_unconfigured_labels_with_stable_error() {
    let router = ModelRouter::new([ModelRouteConfig::new("primary", "gpt-4.1")]);

    assert!(matches!(
        router.resolve("experimental"),
        Err(ModelRouterError::UnknownLabel { label }) if label == "experimental"
    ));
    assert_eq!(
        router.resolve("experimental").unwrap_err().stable_code(),
        "ai.model_router.unknown_label"
    );

    let partially_configured = ModelRouter::new([ModelRouteConfig::new("lite", "")]);
    assert!(matches!(
        partially_configured.resolve("lite"),
        Err(ModelRouterError::ModelNotConfigured { label }) if label == "lite"
    ));
    assert_eq!(
        partially_configured
            .resolve("lite")
            .unwrap_err()
            .stable_code(),
        "ai.model_router.model_not_configured"
    );
}

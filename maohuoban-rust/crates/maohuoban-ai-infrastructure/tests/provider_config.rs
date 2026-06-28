use maohuoban_ai_infrastructure::provider::{
    LlmProviderEnvValues, LlmProviderKind, LlmProviderOperationalConfig, LlmProviderRegistryConfig,
    LlmProviderRuntimeConfig, OpenAiCompatibleConfig,
};

fn commandcode_runtime_config(model: &str) -> OpenAiCompatibleConfig {
    OpenAiCompatibleConfig {
        base_url: "http://127.0.0.1:3050".to_owned(),
        api_key: "user_secret_key".to_owned(),
        model: model.to_owned(),
        timeout_secs: 90,
        temperature: 0.2,
        max_output_tokens: Some(64_000),
        response_format: None,
    }
}

#[test]
fn operational_provider_config_builds_commandcode_proxy_runtime_config() {
    let registry = LlmProviderRegistryConfig::new(vec![
        LlmProviderOperationalConfig::from_openai_compatible_config(
            "commandcode-local",
            "Command Code Local",
            true,
            true,
            commandcode_runtime_config("deepseek/deepseek-v4-flash"),
        ),
    ]);

    let active = registry
        .active_openai_compatible_config()
        .expect("active provider config");

    assert_eq!(active.base_url, "http://127.0.0.1:3050");
    assert_eq!(active.api_key, "user_secret_key");
    assert_eq!(active.model, "deepseek/deepseek-v4-flash");
    assert_eq!(active.timeout_secs, 90);
    assert_eq!(active.max_output_tokens, Some(64_000));
}

#[test]
fn operational_provider_config_selects_enabled_default_provider() {
    let registry = LlmProviderRegistryConfig::new(vec![
        LlmProviderOperationalConfig::from_openai_compatible_config(
            "disabled-default",
            "Disabled Default",
            false,
            true,
            commandcode_runtime_config("disabled-model"),
        ),
        LlmProviderOperationalConfig::from_openai_compatible_config(
            "enabled-default",
            "Enabled Default",
            true,
            true,
            commandcode_runtime_config("enabled-model"),
        ),
    ]);

    let active = registry
        .active_openai_compatible_config()
        .expect("enabled default provider");

    assert_eq!(active.model, "enabled-model");
}

#[test]
fn operational_provider_config_returns_none_without_enabled_default_provider() {
    let registry = LlmProviderRegistryConfig::new(vec![
        LlmProviderOperationalConfig::from_openai_compatible_config(
            "enabled-secondary",
            "Enabled Secondary",
            true,
            false,
            commandcode_runtime_config("secondary-model"),
        ),
    ]);

    assert!(registry.active_openai_compatible_config().is_none());
}

#[test]
fn provider_public_settings_are_safe_for_admin_ui() {
    let registry = LlmProviderRegistryConfig::new(vec![
        LlmProviderOperationalConfig::from_openai_compatible_config(
            "commandcode-local",
            "Command Code Local",
            true,
            true,
            commandcode_runtime_config("deepseek/deepseek-v4-flash"),
        ),
    ]);

    let public_settings = registry.public_settings();
    let setting = public_settings.first().expect("public provider setting");

    assert_eq!(setting.id, "commandcode-local");
    assert_eq!(setting.display_name, "Command Code Local");
    assert_eq!(setting.kind, LlmProviderKind::OpenAiCompatible);
    assert_eq!(setting.base_url, "http://127.0.0.1:3050");
    assert_eq!(setting.model, "deepseek/deepseek-v4-flash");
    assert!(setting.enabled);
    assert!(setting.is_default);
    assert!(setting.api_key_configured);

    let json = serde_json::to_string(setting).expect("serialize public provider setting");
    assert!(json.contains("commandcode-local"));
    assert!(json.contains("api_key_configured"));
    assert!(!json.contains("user_secret_key"));
    assert!(!json.contains("\"api_key\":"));
}

#[test]
fn env_values_build_single_operational_provider_for_local_commandcode_proxy() {
    let registry = LlmProviderRegistryConfig::from_env_values(LlmProviderEnvValues {
        provider_kind: None,
        provider_id: Some("commandcode-local"),
        display_name: Some("Command Code Local"),
        enabled: Some("true"),
        is_default: Some("true"),
        base_url: Some("http://127.0.0.1:3050"),
        api_key: Some("user_secret_key"),
        model: Some("deepseek/deepseek-v4-flash"),
        timeout_secs: Some("90"),
        temperature: Some("0.3"),
        max_output_tokens: Some("64000"),
        response_format: None,
    });

    let active = registry
        .active_openai_compatible_config()
        .expect("env provider config");

    assert_eq!(active.base_url, "http://127.0.0.1:3050");
    assert_eq!(active.api_key, "user_secret_key");
    assert_eq!(active.model, "deepseek/deepseek-v4-flash");
    assert_eq!(active.timeout_secs, 90);
    assert!((active.temperature - 0.3).abs() < f32::EPSILON);
    assert_eq!(active.max_output_tokens, Some(64_000));
}

#[test]
fn env_values_build_deepseek_json_output_provider() {
    let registry = LlmProviderRegistryConfig::from_env_values(LlmProviderEnvValues {
        provider_kind: Some("deepseek"),
        provider_id: Some("deepseek"),
        display_name: Some("DeepSeek"),
        enabled: Some("true"),
        is_default: Some("true"),
        base_url: Some("https://api.deepseek.com"),
        api_key: Some("user_secret_key"),
        model: Some("deepseek-v4-flash"),
        timeout_secs: Some("90"),
        temperature: Some("0.2"),
        max_output_tokens: Some("4096"),
        response_format: Some("json_object"),
    });

    let active = registry
        .active_runtime_provider_config()
        .expect("deepseek provider config");
    let LlmProviderRuntimeConfig::DeepSeek(active) = active else {
        panic!("expected deepseek runtime provider config");
    };

    assert_eq!(active.base_url, "https://api.deepseek.com");
    assert_eq!(active.model, "deepseek-v4-flash");
    assert_eq!(active.max_output_tokens, Some(4096));
    assert_eq!(
        active.response_format,
        Some(serde_json::json!({ "type": "json_object" }))
    );

    let public_settings = registry.public_settings();
    let setting = public_settings.first().expect("public setting");
    assert_eq!(setting.kind, LlmProviderKind::DeepSeek);
    assert_eq!(
        setting.response_format,
        Some(serde_json::json!({ "type": "json_object" }))
    );
}

#[test]
fn env_values_infer_deepseek_kind_from_provider_id() {
    let registry = LlmProviderRegistryConfig::from_env_values(LlmProviderEnvValues {
        provider_kind: None,
        provider_id: Some("deepseek"),
        display_name: Some("DeepSeek"),
        enabled: Some("true"),
        is_default: Some("true"),
        base_url: Some("https://api.deepseek.com"),
        api_key: Some("user_secret_key"),
        model: Some("deepseek-v4-flash"),
        timeout_secs: Some("90"),
        temperature: Some("0.2"),
        max_output_tokens: None,
        response_format: None,
    });

    let active = registry
        .active_runtime_provider_config()
        .expect("deepseek provider config");

    assert!(matches!(active, LlmProviderRuntimeConfig::DeepSeek(_)));
    let public_settings = registry.public_settings();
    assert_eq!(
        public_settings.first().expect("public setting").kind,
        LlmProviderKind::DeepSeek
    );
}

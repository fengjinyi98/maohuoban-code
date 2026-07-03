use maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig;

#[test]
fn provider_config_from_env_values_requires_base_url_key_and_model() {
    let missing = OpenAiCompatibleConfig::from_env_values(
        Some("https://llm.example.com"),
        None,
        Some("maohuoban-model"),
        None,
        None,
        None,
        None,
    );
    assert!(missing.is_none());

    let config = OpenAiCompatibleConfig::from_env_values(
        Some("https://llm.example.com"),
        Some("secret-key"),
        Some("maohuoban-model"),
        None,
        None,
        None,
        None,
    )
    .expect("config should be available");

    assert_eq!(config.base_url, "https://llm.example.com");
    assert_eq!(config.model, "maohuoban-model");
    assert_eq!(config.timeout_secs, 30);
    assert!((config.temperature - 0.2).abs() < f32::EPSILON);
    assert_eq!(config.max_output_tokens, None);
}

#[test]
fn provider_config_parses_optional_limits_and_redacts_debug_key() {
    let config = OpenAiCompatibleConfig::from_env_values(
        Some("https://llm.example.com"),
        Some("secret-key"),
        Some("maohuoban-model"),
        Some("12"),
        Some("0.4"),
        Some("2048"),
        None,
    )
    .expect("config should be available");

    assert_eq!(config.timeout_secs, 12);
    assert!((config.temperature - 0.4).abs() < f32::EPSILON);
    assert_eq!(config.max_output_tokens, Some(2048));

    let debug = format!("{config:?}");
    assert!(debug.contains("api_key: \"<redacted>\""));
    assert!(!debug.contains("secret-key"));
}

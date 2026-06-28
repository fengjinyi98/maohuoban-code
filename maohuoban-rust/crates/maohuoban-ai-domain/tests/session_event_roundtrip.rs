use chrono::{TimeZone, Utc};
use maohuoban_ai_domain::ai::AgentSessionEventEntry;
use serde_json::json;
use uuid::Uuid;

#[test]
fn session_event_roundtrip_preserves_event_name_and_payload() {
    let entry = AgentSessionEventEntry {
        id: Uuid::new_v4(),
        session_id: Uuid::new_v4(),
        turn_id: Uuid::new_v4(),
        parent_event_id: None,
        event_name: "model_call_finished".to_owned(),
        payload: json!({
            "finish_reason": "stop",
            "usage": {
                "input_tokens": 12,
                "output_tokens": 8
            }
        }),
        created_at: Utc
            .with_ymd_and_hms(2026, 6, 28, 9, 30, 0)
            .single()
            .expect("valid timestamp"),
    };

    let encoded = serde_json::to_string(&entry).expect("serialize session event entry");
    let decoded: AgentSessionEventEntry =
        serde_json::from_str(&encoded).expect("deserialize session event entry");

    assert_eq!(decoded.event_name, "model_call_finished");
    assert_eq!(decoded.payload["finish_reason"], "stop");
    assert_eq!(decoded.payload["usage"]["input_tokens"], 12);
    assert_eq!(decoded.session_id, entry.session_id);
    assert_eq!(decoded.turn_id, entry.turn_id);
}

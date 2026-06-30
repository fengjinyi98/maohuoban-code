/// StreamingModelPurpose 流式模型用途
/// 核心职责：
/// - 区分首轮模型回答和工具后追问回答
/// - 统一诊断和终止条件判断
pub(crate) enum StreamingModelPurpose {
    Initial,
    Followup,
}

pub(crate) fn streaming_model_purpose_code(purpose: &StreamingModelPurpose) -> &'static str {
    match purpose {
        StreamingModelPurpose::Initial => "initial",
        StreamingModelPurpose::Followup => "followup",
    }
}

use maohuoban_ai_domain::ai::{AiContentBlock, AiInlineTextSpan};

/// `ParagraphContentProjection` 正文段落内容块投影结果
/// 核心职责：
/// - 同时承载前端展示纯文本和结构化段落内容块
/// - 保证二者来自同一次受控文本归一化
pub(super) struct ParagraphContentProjection {
    pub display_text: String,
    pub block: AiContentBlock,
}

/// `project_paragraph_content_block` 投影正文段落内容块
/// 核心职责：
/// - 将模型最终正文中的受控 inline markup 归一化为 span DTO
/// - 为 SSE 完成事件、历史回放和多端渲染提供统一段落结构
pub(super) fn project_paragraph_content_block(text: &str) -> Option<ParagraphContentProjection> {
    let spans = AiInlineTextSpan::parse_supported_markup(text);
    if spans.is_empty() {
        return None;
    }

    let plain_text = spans
        .iter()
        .map(|span| span.text.as_str())
        .collect::<String>();
    if plain_text.trim().is_empty() {
        return None;
    }

    Some(ParagraphContentProjection {
        display_text: plain_text.clone(),
        block: AiContentBlock::Paragraph {
            id: "answer-paragraph-1".to_owned(),
            text: plain_text,
            spans,
        },
    })
}

/// `append_paragraph_content_block` 追加正文段落内容块
/// 核心职责：
/// - 将模型最终文本投影为 paragraph DTO 并追加到内容块序列
/// - 返回前端最终展示文本，保证展示文本与 span 内容一致
pub(super) fn append_paragraph_content_block(
    final_text: &str,
    content_blocks: &mut Vec<AiContentBlock>,
) -> String {
    match project_paragraph_content_block(final_text) {
        Some(projection) => {
            content_blocks.push(projection.block);
            projection.display_text
        }
        None => final_text.to_owned(),
    }
}

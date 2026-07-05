use maohuoban_ai_domain::ai::{AiContentBlock, AiRichTextLineBlock, AiTableRowBlock};

/// `ParagraphContentProjection` 正文段落内容块投影结果
/// 核心职责：
/// - 同时承载前端展示纯文本和结构化段落内容块
/// - 保证二者来自同一次受控文本归一化
pub(super) struct ParagraphContentProjection {
    pub display_text: String,
    pub blocks: Vec<AiContentBlock>,
}

/// `project_paragraph_content_block` 投影正文段落内容块
/// 核心职责：
/// - 将模型最终正文中的受控 inline markup 归一化为 span DTO
/// - 为 SSE 完成事件、历史回放和多端渲染提供统一段落结构
pub(super) fn project_paragraph_content_block(text: &str) -> Option<ParagraphContentProjection> {
    let blocks = project_markdown_content_blocks(text);
    if blocks.is_empty() {
        return None;
    }

    let display_text = blocks
        .iter()
        .filter_map(block_display_text)
        .collect::<Vec<_>>()
        .join("\n\n");

    Some(ParagraphContentProjection {
        display_text,
        blocks,
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
            content_blocks.extend(projection.blocks);
            projection.display_text
        }
        None => final_text.to_owned(),
    }
}

fn project_markdown_content_blocks(text: &str) -> Vec<AiContentBlock> {
    let mut blocks = Vec::new();
    let mut paragraph_lines = Vec::new();
    let mut list_items = Vec::new();
    let mut counter = ContentBlockCounter::default();
    let lines: Vec<&str> = text.lines().collect();
    let mut index = 0;

    while index < lines.len() {
        let trimmed = lines[index].trim();
        if trimmed.is_empty() {
            flush_paragraph(&mut blocks, &mut paragraph_lines, &mut counter);
            flush_list(&mut blocks, &mut list_items, &mut counter);
            index += 1;
            continue;
        }

        if is_markdown_divider(trimmed) {
            flush_paragraph(&mut blocks, &mut paragraph_lines, &mut counter);
            flush_list(&mut blocks, &mut list_items, &mut counter);
            blocks.push(AiContentBlock::Divider {
                id: counter.next_id("divider"),
            });
            index += 1;
            continue;
        }

        if let Some(heading) = parse_heading(trimmed) {
            flush_paragraph(&mut blocks, &mut paragraph_lines, &mut counter);
            flush_list(&mut blocks, &mut list_items, &mut counter);
            blocks.push(AiContentBlock::SectionHeading {
                id: counter.next_id("heading"),
                text: heading.to_owned(),
            });
            index += 1;
            continue;
        }

        if is_table_header(&lines, index) {
            flush_paragraph(&mut blocks, &mut paragraph_lines, &mut counter);
            flush_list(&mut blocks, &mut list_items, &mut counter);
            let (table, next_index) = parse_table(&lines, index, &mut counter);
            if let Some(table) = table {
                blocks.push(table);
                index = next_index;
                continue;
            }
        }

        if let Some(quote) = trimmed.strip_prefix('>') {
            flush_paragraph(&mut blocks, &mut paragraph_lines, &mut counter);
            flush_list(&mut blocks, &mut list_items, &mut counter);
            if let Some(line) = AiRichTextLineBlock::from_markup(quote.trim()) {
                blocks.push(AiContentBlock::Quote {
                    id: counter.next_id("quote"),
                    text: line.text,
                    spans: line.spans,
                });
            }
            index += 1;
            continue;
        }

        if let Some(item) = parse_list_item(trimmed) {
            flush_paragraph(&mut blocks, &mut paragraph_lines, &mut counter);
            if let Some(line) = AiRichTextLineBlock::from_markup(item) {
                list_items.push(line);
            }
            index += 1;
            continue;
        }

        flush_list(&mut blocks, &mut list_items, &mut counter);
        paragraph_lines.push(trimmed.to_owned());
        index += 1;
    }

    flush_paragraph(&mut blocks, &mut paragraph_lines, &mut counter);
    flush_list(&mut blocks, &mut list_items, &mut counter);
    blocks
}

fn flush_paragraph(
    blocks: &mut Vec<AiContentBlock>,
    paragraph_lines: &mut Vec<String>,
    counter: &mut ContentBlockCounter,
) {
    if paragraph_lines.is_empty() {
        return;
    }
    let markup = paragraph_lines.join("\n");
    if let Some(line) = AiRichTextLineBlock::from_markup(&markup) {
        blocks.push(AiContentBlock::Paragraph {
            id: counter.next_id("paragraph"),
            text: line.text,
            spans: line.spans,
        });
    }
    paragraph_lines.clear();
}

fn flush_list(
    blocks: &mut Vec<AiContentBlock>,
    list_items: &mut Vec<AiRichTextLineBlock>,
    counter: &mut ContentBlockCounter,
) {
    if list_items.is_empty() {
        return;
    }
    blocks.push(AiContentBlock::List {
        id: counter.next_id("list"),
        items: std::mem::take(list_items),
    });
}

fn block_display_text(block: &AiContentBlock) -> Option<String> {
    match block {
        AiContentBlock::SectionHeading { text, .. }
        | AiContentBlock::Paragraph { text, .. }
        | AiContentBlock::Quote { text, .. } => Some(text.clone()),
        AiContentBlock::List { items, .. } => Some(
            items
                .iter()
                .map(|item| format!("- {}", item.text))
                .collect::<Vec<_>>()
                .join("\n"),
        ),
        AiContentBlock::Table { columns, rows, .. } => {
            let mut lines = vec![columns.join(" | ")];
            lines.extend(rows.iter().map(|row| {
                row.cells
                    .iter()
                    .map(|cell| cell.text.as_str())
                    .collect::<Vec<_>>()
                    .join(" | ")
            }));
            Some(lines.join("\n"))
        }
        AiContentBlock::Divider { .. }
        | AiContentBlock::PetProfileCardSkeleton { .. }
        | AiContentBlock::PetProfileCard { .. } => None,
    }
}

fn parse_heading(line: &str) -> Option<&str> {
    let trimmed = line.trim_start_matches('#');
    let marker_count = line.len().saturating_sub(trimmed.len());
    if (1..=6).contains(&marker_count) && trimmed.starts_with(' ') {
        Some(trimmed.trim())
    } else {
        None
    }
}

fn is_markdown_divider(line: &str) -> bool {
    let chars: Vec<char> = line.chars().collect();
    chars.len() >= 3 && chars.iter().all(|ch| matches!(ch, '-' | '*' | '_'))
}

fn parse_list_item(line: &str) -> Option<&str> {
    line.strip_prefix("- ")
        .or_else(|| line.strip_prefix("* "))
        .or_else(|| line.strip_prefix("+ "))
        .or_else(|| parse_ordered_list_item(line))
}

fn parse_ordered_list_item(line: &str) -> Option<&str> {
    let dot = line.find(". ")?;
    if line[..dot].chars().all(|ch| ch.is_ascii_digit()) {
        Some(&line[dot + 2..])
    } else {
        None
    }
}

fn is_table_header(lines: &[&str], index: usize) -> bool {
    index + 1 < lines.len()
        && split_table_row(lines[index]).len() >= 2
        && is_table_separator(lines[index + 1])
}

fn parse_table(
    lines: &[&str],
    start: usize,
    counter: &mut ContentBlockCounter,
) -> (Option<AiContentBlock>, usize) {
    let columns = split_table_row(lines[start]);
    if columns.len() < 2 || !is_table_separator(lines[start + 1]) {
        return (None, start);
    }

    let mut rows = Vec::new();
    let mut index = start + 2;
    while index < lines.len() {
        let cells = split_table_row(lines[index]);
        if cells.len() != columns.len() {
            break;
        }
        let Some(row) = parse_table_row(cells) else {
            break;
        };
        rows.push(row);
        index += 1;
    }

    if rows.is_empty() {
        return (None, start);
    }

    (
        Some(AiContentBlock::Table {
            id: counter.next_id("table"),
            columns: columns.into_iter().map(str::to_owned).collect(),
            rows,
        }),
        index,
    )
}

fn parse_table_row(cells: Vec<&str>) -> Option<AiTableRowBlock> {
    let mut parsed = Vec::new();
    for cell in cells {
        parsed.push(AiRichTextLineBlock::from_markup(cell)?);
    }
    Some(AiTableRowBlock { cells: parsed })
}

fn split_table_row(line: &str) -> Vec<&str> {
    let trimmed = line.trim().trim_matches('|');
    if !line.trim().contains('|') {
        return Vec::new();
    }
    trimmed.split('|').map(str::trim).collect()
}

fn is_table_separator(line: &str) -> bool {
    let cells = split_table_row(line);
    cells.len() >= 2
        && cells.iter().all(|cell| {
            let normalized = cell.trim_matches(':');
            normalized.len() >= 3 && normalized.chars().all(|ch| ch == '-')
        })
}

#[derive(Default)]
struct ContentBlockCounter {
    next: usize,
}

impl ContentBlockCounter {
    fn next_id(&mut self, prefix: &str) -> String {
        self.next += 1;
        format!("answer-{prefix}-{}", self.next)
    }
}

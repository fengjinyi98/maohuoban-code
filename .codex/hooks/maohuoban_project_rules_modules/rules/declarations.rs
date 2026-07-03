/// primary_declarations 提取顶层主要类型
/// 核心职责：
/// - 识别 Swift 顶层类型声明
/// - 识别 Rust 公开顶层类型与函数声明
pub(super) fn primary_declarations(extension: &str, content: &str) -> Vec<String> {
    let mut declarations = Vec::new();
    for line in content.lines() {
        if line.starts_with(char::is_whitespace) {
            continue;
        }
        let line = line.trim_start();
        let declaration = match extension {
            "swift" => swift_declaration_name(line),
            "rs" => rust_declaration_name(line),
            _ => None,
        };
        if let Some(name) = declaration {
            if !declarations.contains(&name) {
                declarations.push(name);
            }
        }
    }
    declarations
}

/// swift_declaration_name 提取 Swift 类型名
/// 核心职责：
/// - 支持常见访问控制与修饰符
/// - 返回顶层主要声明名称
fn swift_declaration_name(line: &str) -> Option<String> {
    declaration_name_after_keywords(
        line,
        &[
            "public",
            "open",
            "internal",
            "private",
            "fileprivate",
            "final",
        ],
        &["struct", "class", "enum", "actor", "protocol"],
    )
}

/// rust_declaration_name 提取 Rust 公开声明名
/// 核心职责：
/// - 支持 pub 与 pub(crate) 公开声明
/// - 返回顶层主要声明名称
fn rust_declaration_name(line: &str) -> Option<String> {
    let mut rest = line.trim_start();
    if let Some(next) = rest.strip_prefix("pub ") {
        rest = next.trim_start();
    } else if rest.starts_with("pub(") {
        let end = rest.find(')')?;
        rest = rest[end + 1..].trim_start();
    } else {
        return None;
    }
    declaration_name_after_keywords(rest, &[], &["struct", "enum", "trait", "type"])
}

/// declaration_name_after_keywords 提取关键字后的标识符
/// 核心职责：
/// - 跳过声明修饰符
/// - 返回类型或函数名称
fn declaration_name_after_keywords(
    line: &str,
    modifiers: &[&str],
    keywords: &[&str],
) -> Option<String> {
    let words: Vec<&str> = line.split_whitespace().collect();
    let mut index = 0;
    while index < words.len() && modifiers.contains(&words[index]) {
        index += 1;
    }
    if index >= words.len() || !keywords.contains(&words[index]) {
        return None;
    }
    words
        .get(index + 1)
        .map(|value| trim_identifier(value))
        .filter(|value| !value.is_empty())
}

/// trim_identifier 清理声明标识符
/// 核心职责：
/// - 去除泛型、参数和标点
/// - 保留可读类型名称
fn trim_identifier(value: &str) -> String {
    value
        .chars()
        .take_while(|ch| ch.is_ascii_alphanumeric() || *ch == '_')
        .collect()
}

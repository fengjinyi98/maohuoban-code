/// build_title 从用户消息构建会话标题
/// 核心职责：
/// - 按字符边界截断标题
/// - 避免混合 ASCII 与 CJK 文本触发 UTF-8 切片 panic
pub(crate) fn build_title(message: &str) -> String {
    let mut chars = message.chars();
    let title: String = chars.by_ref().take(18).collect();

    if chars.next().is_some() {
        format!("{title}...")
    } else {
        message.to_owned()
    }
}

#[cfg(test)]
mod tests {
    use super::build_title;

    #[test]
    fn build_title_truncates_by_char_boundary() {
        let message = "12345678901234567毛球";

        assert_eq!(build_title(message), "12345678901234567毛...");
    }
}

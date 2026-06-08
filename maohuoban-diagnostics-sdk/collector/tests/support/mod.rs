/// `tar_entries` 解析测试用无压缩 tar 条目
/// 核心职责：
/// - 验证 Collector 生成的归档可以按 tar 格式读取
/// - 对比归档内文件内容和导出目录原文件
pub fn tar_entries(archive: &[u8]) -> Vec<(String, Vec<u8>)> {
    let mut entries = Vec::new();
    let mut offset = 0;
    while offset + 512 <= archive.len() {
        let header = &archive[offset..offset + 512];
        if header.iter().all(|byte| *byte == 0) {
            break;
        }
        let name_end = header[0..100]
            .iter()
            .position(|byte| *byte == 0)
            .unwrap_or(100);
        let name = String::from_utf8(header[0..name_end].to_vec()).expect("tar name");
        let size_bytes = header[124..136]
            .iter()
            .copied()
            .filter(|byte| *byte != 0 && *byte != b' ')
            .collect::<Vec<_>>();
        let size_text = String::from_utf8(size_bytes).expect("tar size");
        let size = usize::from_str_radix(size_text.trim(), 8).expect("tar octal size");
        let data_start = offset + 512;
        let data_end = data_start + size;
        assert!(data_end <= archive.len(), "tar entry exceeds archive size");
        entries.push((name, archive[data_start..data_end].to_vec()));
        offset = data_start + size.div_ceil(512) * 512;
    }
    entries
}

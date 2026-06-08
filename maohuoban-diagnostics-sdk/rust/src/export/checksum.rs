use crate::DiagnosticsError;
use sha2::{Digest, Sha256};
use std::{fs, path::PathBuf};

/// `sha256_file_hex` 计算文件 SHA256
/// 核心职责：
/// - 为 manifest 提供文件级完整性校验值
/// - 使用小写十六进制作为跨语言稳定格式
pub(super) fn sha256_file_hex(path: &PathBuf) -> Result<String, DiagnosticsError> {
    let bytes = fs::read(path)?;
    let digest = Sha256::digest(bytes);
    Ok(format!("{digest:x}"))
}

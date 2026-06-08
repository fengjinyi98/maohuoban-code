use crate::DiagnosticsError;
use std::{
    fs::{self, File},
    io::Write as _,
    path::PathBuf,
};

/// `write_tar_archive` 写入无压缩 tar 归档
/// 核心职责：
/// - 将 Debug Bundle 核心文件打包为单文件传输格式
/// - 避免额外压缩依赖，保持导出层可预测
pub(super) fn write_tar_archive(
    output_path: &PathBuf,
    files: impl IntoIterator<Item = (&'static str, PathBuf)>,
) -> Result<(), DiagnosticsError> {
    let mut archive = File::create(output_path)?;
    for (name, path) in files {
        let data = fs::read(path)?;
        archive.write_all(&tar_header(
            name,
            u64::try_from(data.len()).unwrap_or(u64::MAX),
        ))?;
        archive.write_all(&data)?;
        let padding = (512 - (data.len() % 512)) % 512;
        if padding > 0 {
            archive.write_all(&vec![0; padding])?;
        }
    }
    archive.write_all(&[0; 1024])?;
    Ok(())
}

fn tar_header(name: &str, size: u64) -> [u8; 512] {
    let mut header = [0u8; 512];
    write_tar_string(&mut header[0..100], name);
    write_tar_octal(&mut header[100..108], 0o644);
    write_tar_octal(&mut header[108..116], 0);
    write_tar_octal(&mut header[116..124], 0);
    write_tar_octal(&mut header[124..136], size);
    write_tar_octal(&mut header[136..148], 0);
    header[148..156].fill(b' ');
    header[156] = b'0';
    write_tar_string(&mut header[257..263], "ustar");
    write_tar_string(&mut header[263..265], "00");
    let checksum = header.iter().map(|byte| u32::from(*byte)).sum::<u32>();
    write_tar_checksum(&mut header[148..156], checksum);
    header
}

fn write_tar_string(target: &mut [u8], value: &str) {
    let bytes = value.as_bytes();
    let count = bytes.len().min(target.len());
    target[..count].copy_from_slice(&bytes[..count]);
}

fn write_tar_octal(target: &mut [u8], value: u64) {
    let width = target.len();
    let text = format!("{value:0width$o}", width = width - 1);
    let bytes = text.as_bytes();
    target[..bytes.len()].copy_from_slice(bytes);
}

fn write_tar_checksum(target: &mut [u8], value: u32) {
    let text = format!("{value:06o}\0 ");
    target.copy_from_slice(text.as_bytes());
}

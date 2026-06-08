use maohuoban_diagnostics_collector::{CollectorConfig, collect_debug_bundle};
use std::{env, path::PathBuf, process};

/// main Collector CLI 入口
/// 核心职责：
/// - 解析本地段文件目录与输出目录
/// - 将采集结果导出为 Debug Bundle
fn main() {
    let args = env::args().skip(1).collect::<Vec<_>>();
    match run(&args) {
        Ok(()) => {}
        Err(error) => {
            eprintln!("{error}");
            process::exit(1);
        }
    }
}

fn run(args: &[String]) -> Result<(), String> {
    let mut segments = None;
    let mut output = None;
    let mut index = 0;
    while index < args.len() {
        match args[index].as_str() {
            "--segments" => {
                index += 1;
                segments = args.get(index).map(PathBuf::from);
            }
            "--output" => {
                index += 1;
                output = args.get(index).map(PathBuf::from);
            }
            "--help" | "-h" => {
                print_help();
                return Ok(());
            }
            unknown => return Err(format!("unknown argument: {unknown}")),
        }
        index += 1;
    }

    let segments = segments.ok_or_else(|| "missing --segments <path>".to_string())?;
    let output = output.ok_or_else(|| "missing --output <path>".to_string())?;
    let bundle = collect_debug_bundle(CollectorConfig::from_paths(segments, output))
        .map_err(|error| error.to_string())?;
    println!("{}", bundle.directory.display());
    Ok(())
}

fn print_help() {
    println!(
        "maohuoban_diagnostics_collector --segments <path> --output <path>\n\n导出 Maohuoban Debug Bundle。"
    );
}

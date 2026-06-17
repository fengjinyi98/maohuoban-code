use std::{env, time::Duration};

use maohuoban_media_gc_worker::{MediaGcWorkerConfig, run_once};
use maohuoban_media_storage::MediaObjectStore;
use sqlx::postgres::PgPoolOptions;

/// main 媒体清理 worker 入口
/// 核心职责：
/// - 读取本地或生产环境变量配置
/// - 按单次或轮询模式执行媒体 GC
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let _ = dotenvy::dotenv();
    let database_url = env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://fengjinyi@localhost/maohuoban".to_owned());
    let object_store = MediaObjectStore::from_env()?;
    let poll_interval_ms = env::var("MEDIA_GC_POLL_INTERVAL_MS")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(30_000);
    let run_once_mode = env::var("MEDIA_GC_WORKER_RUN_ONCE")
        .map(|value| value == "true")
        .unwrap_or(false);

    let pool = PgPoolOptions::new()
        .max_connections(4)
        .connect(&database_url)
        .await?;

    loop {
        let result = run_once(MediaGcWorkerConfig {
            pool: pool.clone(),
            object_store: object_store.clone(),
            batch_size: 50,
        })
        .await?;
        println!("media gc deleted {} assets", result.deleted_assets);

        if run_once_mode {
            break;
        }
        tokio::time::sleep(Duration::from_millis(poll_interval_ms)).await;
    }

    Ok(())
}

use crate::{CleanupPolicy, CleanupReport, DiagnosticEvent, DiagnosticsError};
use std::{
    path::PathBuf,
    sync::mpsc::{Receiver, SyncSender, TrySendError, channel, sync_channel},
    thread,
};

use super::event_store::EventStore;

/// `QueuedEventStoreConfig` 异步写入队列配置
/// 核心职责：
/// - 控制入队容量
/// - 保留批量写入配置入口供后续 worker 扩展
#[derive(Clone, Copy, Debug)]
pub struct QueuedEventStoreConfig {
    pub capacity: usize,
    pub batch_size: usize,
}

impl Default for QueuedEventStoreConfig {
    fn default() -> Self {
        Self {
            capacity: 2048,
            batch_size: 64,
        }
    }
}

/// `QueuedEventStore` bounded 后台写入存储
/// 核心职责：
/// - 让 append 热路径只做非阻塞入队
/// - 将 flush/read/cleanup 作为后台 writer 的同步边界
pub struct QueuedEventStore {
    sender: SyncSender<StoreCommand>,
    export_index_path: Option<PathBuf>,
}

impl QueuedEventStore {
    /// `new` 创建后台写入存储
    /// 核心职责：
    /// - 接管真实 `EventStore` 的所有权
    /// - 启动串行 worker 处理落盘、读取和清理命令
    #[must_use]
    pub fn new(mut store: Box<dyn EventStore>, config: QueuedEventStoreConfig) -> Self {
        let export_index_path = store.export_index_path();
        let (sender, receiver) = sync_channel(config.capacity);
        thread::spawn(move || run_store_worker(&mut store, &receiver));
        Self {
            sender,
            export_index_path,
        }
    }
}

impl EventStore for QueuedEventStore {
    fn append(&mut self, event: &DiagnosticEvent) -> Result<(), DiagnosticsError> {
        self.sender
            .try_send(StoreCommand::Append(event.clone()))
            .map_err(|error| match error {
                TrySendError::Full(_) => DiagnosticsError::EventQueueFull,
                TrySendError::Disconnected(_) => DiagnosticsError::EventQueueClosed,
            })
    }

    fn flush(&mut self) -> Result<(), DiagnosticsError> {
        let (sender, receiver) = channel();
        self.sender
            .send(StoreCommand::Flush(sender))
            .map_err(|_| DiagnosticsError::EventQueueClosed)?;
        receiver
            .recv()
            .map_err(|_| DiagnosticsError::EventQueueClosed)?
    }

    fn read_all(&self) -> Result<Vec<DiagnosticEvent>, DiagnosticsError> {
        let (sender, receiver) = channel();
        self.sender
            .send(StoreCommand::ReadAll(sender))
            .map_err(|_| DiagnosticsError::EventQueueClosed)?;
        receiver
            .recv()
            .map_err(|_| DiagnosticsError::EventQueueClosed)?
    }

    fn cleanup(&mut self, policy: &CleanupPolicy) -> Result<CleanupReport, DiagnosticsError> {
        let (sender, receiver) = channel();
        self.sender
            .send(StoreCommand::Cleanup(policy.clone(), sender))
            .map_err(|_| DiagnosticsError::EventQueueClosed)?;
        receiver
            .recv()
            .map_err(|_| DiagnosticsError::EventQueueClosed)?
    }

    fn export_index_path(&self) -> Option<PathBuf> {
        self.export_index_path.clone()
    }
}

enum StoreCommand {
    Append(DiagnosticEvent),
    Flush(std::sync::mpsc::Sender<Result<(), DiagnosticsError>>),
    ReadAll(std::sync::mpsc::Sender<Result<Vec<DiagnosticEvent>, DiagnosticsError>>),
    Cleanup(
        CleanupPolicy,
        std::sync::mpsc::Sender<Result<CleanupReport, DiagnosticsError>>,
    ),
}

fn run_store_worker(store: &mut Box<dyn EventStore>, receiver: &Receiver<StoreCommand>) {
    let mut pending_writer_error: Option<String> = None;
    while let Ok(command) = receiver.recv() {
        match command {
            StoreCommand::Append(event) => {
                if let Err(error) = store.append(&event) {
                    pending_writer_error = Some(error.to_string());
                }
            }
            StoreCommand::Flush(sender) => {
                let result = pending_writer_error
                    .take()
                    .map_or_else(|| store.flush(), |error| Err(writer_error(error)));
                let _ = sender.send(result);
            }
            StoreCommand::ReadAll(sender) => {
                let result = pending_writer_error
                    .take()
                    .map_or_else(|| store.read_all(), |error| Err(writer_error(error)));
                let _ = sender.send(result);
            }
            StoreCommand::Cleanup(policy, sender) => {
                let result = pending_writer_error
                    .take()
                    .map_or_else(|| store.cleanup(&policy), |error| Err(writer_error(error)));
                let _ = sender.send(result);
            }
        }
    }
}

fn writer_error(error: String) -> DiagnosticsError {
    DiagnosticsError::EventQueueWriterFailed(error)
}

use std::sync::Arc;

use tokio::sync::broadcast;

use super::HomeRealtimeEvent;

/// `HomeRealtimeHub` 首页实时事件中心
/// 核心职责：
/// - 为后端后台任务和 HTTP SSE 订阅共享同一个事件源
/// - 只广播已落库的首页变化信号，保持读模型单一来源
#[derive(Clone)]
pub struct HomeRealtimeHub {
    sender: Arc<broadcast::Sender<HomeRealtimeEvent>>,
}

impl Default for HomeRealtimeHub {
    fn default() -> Self {
        Self::new()
    }
}

impl HomeRealtimeHub {
    #[must_use]
    pub fn new() -> Self {
        let (sender, _) = broadcast::channel(128);
        Self {
            sender: Arc::new(sender),
        }
    }

    pub fn publish(&self, event: HomeRealtimeEvent) {
        let _ = self.sender.send(event);
    }

    #[must_use]
    pub fn subscribe(&self) -> broadcast::Receiver<HomeRealtimeEvent> {
        self.sender.subscribe()
    }
}

use std::collections::HashMap;

use super::{ModelRoute, ModelRouteConfig, ModelRouterError};

/// ModelRouter 模型标签路由器
/// 核心职责：
/// - 将 lite / primary / pro / memory 等稳定 label 解析为具体模型名
/// - 避免业务编排直接依赖 provider model 字符串
#[derive(Debug, Clone, Default)]
pub struct ModelRouter {
    routes: HashMap<String, String>,
}

impl ModelRouter {
    /// new 从内存配置构造路由器
    #[must_use]
    pub fn new(routes: impl IntoIterator<Item = ModelRouteConfig>) -> Self {
        Self {
            routes: routes
                .into_iter()
                .map(|route| (route.label, route.model))
                .collect(),
        }
    }

    /// resolve 解析模型 label
    ///
    /// 核心职责：
    /// - 未知 label 返回稳定 UnknownLabel 错误
    /// - 空模型配置返回稳定 ModelNotConfigured 错误
    pub fn resolve(&self, label: &str) -> Result<ModelRoute, ModelRouterError> {
        let model = self
            .routes
            .get(label)
            .ok_or_else(|| ModelRouterError::UnknownLabel {
                label: label.to_owned(),
            })?;

        if model.trim().is_empty() {
            return Err(ModelRouterError::ModelNotConfigured {
                label: label.to_owned(),
            });
        }

        Ok(ModelRoute {
            label: label.to_owned(),
            model: model.clone(),
        })
    }
}

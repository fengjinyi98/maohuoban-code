// runtime_workbench_prompt_projection Workbench 模型可见投影测试
// 核心职责：
// - 验证 Runtime 给模型的 Workbench prompt 使用受控文本投影
// - 防止 domain struct 字段名和未来新增字段自动进入模型输入

mod projection_cases;
mod support;

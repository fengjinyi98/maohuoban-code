# ADK-Rust | 用 Rust 构建强大的 AI 代理

- 来源链接：https://www.adk-rust.com/
- 浏览器最终地址：https://www.adk-rust.com/zh-CN
- 原始收集：docs/agent/4.md:8
- 保存时间：2026-06-28
- 访问状态：success
- 提取方式：浏览器可见正文提取
- 页面描述：灵活、模块化的生产级 AI 代理框架。模型无关。类型安全。极速高效。用 Rust 构建 LLM 代理、工作流和多代理系统。

---

## 原始备注

| **ADK-Rust** (Agent Development Kit) | 生产级 Agent 框架，模块化，支持模型无关、Tools、Memory、实时语音等。 | https://www.adk-rust.com/ 或 GitHub zavora-ai/adk-rust | 灵活、类型安全，适合复杂多代理。 |

## 正文

用 Rust 构建强大的 AI 代理

灵活、模块化的生产级 AI 代理框架。模型无关。类型安全。极速高效。

体验在线演示
开始使用
🆕
Rust 2024
🎨
Visual Builder
🦀
原生 Rust
⚡
异步优先
🔌
可插拔
main.rs
Visual Agent Builder

Design, build, and deploy AI agents without writing code

ADK Studio - Workflow Editor
Start
User Input
Agent
Research
Output
Final Report
🖱️
Drag & Drop

Visual workflow designer with ReactFlow canvas

⚡
Code Generation

One-click export to production Rust code

📡
Live Streaming

Real-time SSE with agent animations

Try ADK Studio
为什么选择 ADK-Rust?

专为追求性能、安全和灵活性的开发者从零打造。

🎯
模型无关

Gemini、OpenAI、Anthropic - 一行代码切换模型。为每个任务选择最佳模型，无供应商锁定。

🔧
模块化设计

按需使用。代理、模型、工具、会话等独立 crate。

⚡
极速高效

原生 Rust 性能。异步优先设计，开销最小。为生产负载而生。

🛡️
类型安全

编译时捕获错误。无运行时意外。Rust 编译器是您的后盾。

🚀
生产就绪

会话、制品、遥测、多种部署模式。真实应用所需一应俱全。

🔌
可扩展工具

内置工具加上便捷的自定义工具创建。无限扩展代理能力。

试用 ADK-Rust AI 代理 在线演示

与使用 adk-rust 构建的真实 AI 代理进行交互。亲身体验其强大功能。

💬
聊天助手
🦀
代码助手
🔍
研究代理
🦀
代码助手

专注于 Rust 和 adk-rust 的 AI 代理开发专家

功能特性
立即试用
此代理的功能
⚙️
Rust 专业知识

深入了解 Rust 惯用法、设计模式和最佳实践

🤖
adk-rust 框架

使用 adk-rust 构建 AI 代理的专业指导

🔍
代码审查

分析代码以发现错误、性能问题和改进建议

📚
API 指南

Gemini API 集成和工具使用帮助

示例提问
→如何使用 adk-rust 创建多代理工作流？→展示如何向代理添加自定义工具→在异步 Rust 中处理错误的最佳方式是什么？
开始对话
查看源代码
满足所有代理类型需求

从简单聊天机器人到复杂多步工作流，ADK-Rust 全面覆盖。

💬
LLM 代理

支持工具和记忆的对话代理。

查看代码
📋
顺序工作流

逐步任务执行管道。

查看代码
🔀
并行工作流

并发处理实现最大速度。

查看代码
🔁
循环工作流

迭代优化直至完成。

查看代码
🕸️
图代理

带条件分支的复杂流程。

查看代码
🎙️
实时语音

双向音频流代理。

查看代码
🔀
agentTypes.routerAgent.title

agentTypes.routerAgent.description

查看代码
实际应用演示

简洁、富有表现力的 API，让您专注于构建优秀的代理。

基础代理
带工具的代理
工作流
多代理
basic.rs
复制
1
use adk_rust::prelude::*;
2
3
#[tokio::main]
4
async fn main() -> Result<()> {
5
let model = GeminiModel::new(&api_key, "gemini-2.5-flash")?;
6
7
let agent = LlmAgentBuilder::new("assistant")
8
.description("A helpful AI assistant")
9
.instruction("You are friendly and concise.")
10
.model(Arc::new(model))
11
.build()?;
12
13
Launcher::new(Arc::new(agent)).run().await?;
14
Ok(())
15
}
分层架构

清晰的模块化设计，关注点分离，实现灵活性。

应用层

您的代理和业务逻辑

运行器层

执行与编排

代理层

LLM、工作流、图代理

服务层

模型、工具、会话、存储

与您的技术栈无缝集成

使用您喜爱的模型提供商，部署到任何地方。

Google Gemini
OpenAI
Anthropic
DeepSeek
部署选项
💻
控制台模式

用于开发和测试的交互式 CLI

🌐
服务器模式

用于 Web 应用的 REST API 端点

🤝
A2A 协议

代理间通信

几分钟即可开始

三个简单步骤，用 Rust 构建您的第一个 AI 代理。

1
添加到 Cargo.toml
[dependencies]
adk-rust = "0.1.8"
tokio = { version = "1", features = ["full"] }
2
创建您的第一个代理
let agent = LlmAgentBuilder::new("my_agent")
.model(Arc::new(model))
.build()?;
3
运行！
$ cargo run
查看完整文档
保持联系

获取新功能、版本发布和 AI 代理开发的最新动态。

名字 *
姓氏 *
邮箱 *
国家 *
选择您的国家
Afghanistan
Albania
Algeria
Andorra
Angola
Antigua and Barbuda
Argentina
Armenia
Australia
Austria
Azerbaijan
Bahamas
Bahrain
Bangladesh
Barbados
Belarus
Belgium
Belize
Benin
Bhutan
Bolivia
Bosnia and Herzegovina
Botswana
Brazil
Brunei
Bulgaria
Burkina Faso
Burundi
Cambodia
Cameroon
Canada
Cape Verde
Central African Republic
Chad
Chile
China
Colombia
Comoros
Congo (Democratic Republic)
Congo (Republic)
Costa Rica
Croatia
Cuba
Cyprus
Czech Republic
Denmark
Djibouti
Dominica
Dominican Republic
East Timor
Ecuador
Egypt
El Salvador
Equatorial Guinea
Eritrea
Estonia
Eswatini
Ethiopia
Fiji
Finland
France
Gabon
Gambia
Georgia
Germany
Ghana
Greece
Grenada
Guatemala
Guinea
Guinea-Bissau
Guyana
Haiti
Honduras
Hungary
Iceland
India
Indonesia
Iran
Iraq
Ireland
Israel
Italy
Ivory Coast
Jamaica
Japan
Jordan
Kazakhstan
Kenya
Kiribati
Kosovo
Kuwait
Kyrgyzstan
Laos
Latvia
Lebanon
Lesotho
Liberia
Libya
Liechtenstein
Lithuania
Luxembourg
Madagascar
Malawi
Malaysia
Maldives
Mali
Malta
Marshall Islands
Mauritania
Mauritius
Mexico
Micronesia
Moldova
Monaco
Mongolia
Montenegro
Morocco
Mozambique
Myanmar
Namibia
Nauru
Nepal
Netherlands
New Zealand
Nicaragua
Niger
Nigeria
North Korea
North Macedonia
Norway
Oman
Pakistan
Palau
Palestine
Panama
Papua New Guinea
Paraguay
Peru
Philippines
Poland
Portugal
Qatar
Romania
Russia
Rwanda
Saint Kitts and Nevis
Saint Lucia
Saint Vincent and the Grenadines
Samoa
San Marino
Sao Tome and Principe
Saudi Arabia
Senegal
Serbia
Seychelles
Sierra Leone
Singapore
Slovakia
Slovenia
Solomon Islands
Somalia
South Africa
South Korea
South Sudan
Spain
Sri Lanka
Sudan
Suriname
Sweden
Switzerland
Syria
Taiwan
Tajikistan
Tanzania
Thailand
Togo
Tonga
Trinidad and Tobago
Tunisia
Turkey
Turkmenistan
Tuvalu
Uganda
Ukraine
United Arab Emirates
United Kingdom
United States
Uruguay
Uzbekistan
Vanuatu
Vatican City
Venezuela
Vietnam
Yemen
Zambia
Zimbabwe
对 ADK-Rust 的兴趣
选择您的兴趣程度
计划学习 ADK-Rust
为项目评估中
目前正在使用 ADK-Rust
计划部署到生产环境
已部署到生产环境
有兴趣参与贡献
对 AI 代理有一般兴趣
Rust 经验
选择您的经验水平
无 Rust 经验
初学者（正在学习 Rust）
中级（已完成一些项目）
高级（有专业经验）
专家（多年经验，开源贡献者）
为 ADK-Rust 评分（如果您试用过）

点击评分，再次点击清除

反馈或评论（可选）
我同意接收关于 ADK-Rust 更新和新闻的营销邮件。您可以随时取消订阅。 隐私政策
订阅

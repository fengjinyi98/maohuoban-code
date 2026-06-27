# Rig - Build Powerful LLM Applications in Rust

- 来源链接：https://rig.rs/
- 浏览器最终地址：https://rig.rs/
- 原始收集：docs/agent/4.md:7
- 保存时间：2026-06-28
- 访问状态：success
- 提取方式：浏览器可见正文提取
- 页面描述：Rig: Build modular and scalable LLM Applications in Rust. Unified LLM interface, Rust-powered performance, and advanced AI workflow abstractions for efficient development.

---

## 原始备注

| **Rig** | 最受欢迎的 Rust LLM 应用框架，常被称为“Rust 的 LangChain”。支持 Agent、Tools、RAG、Streaming 等。 | https://rig.rs/ | 模块化、易用、生产就绪，支持 OpenAI/Anthropic/Ollama 等。教程丰富。 |

## 正文

Build AI Applications in RustA modular, scalable library for building LLM-powered applications. Production-ready and open source.main.rsuse rig::{completion::Prompt, providers::openai};

let openai = openai::Client::from_env();

let agent = openai.agent("gpt-5")
.preamble("You are a helpful assistant.")
.build();

let response = agent
.prompt("What is Rust?")
.await?;Get StartedDocsRig Book newTry Ryzome7K+GitHub Stars1346K+Downloads224+Contributors75K+ across 181+ dependent reposGithubSt. Jude Children's Research HospitalCoral ProtocolDriaNethermindNeonGrafbaseRyzomeOpenAgentsapp.buildMCP Rust SDKProbeLineraBuild AI Applications in RustA modular, scalable library for building LLM-powered applications. Production-ready and open source.Get StartedDocsRig Book newTry Ryzomemain.rsuse rig::{completion::Prompt, providers::openai};

let openai = openai::Client::from_env();

let agent = openai.agent("gpt-5")
.preamble("You are a helpful assistant.")
.build();

let response = agent
.prompt("What is Rust?")
.await?;Community DrivenJoin the fastest-growing ecosystem for AI development in Rust.7K+GitHub Stars1346K+Downloads224+Contributors75K+ across 181+ dependent repositories — GithubProduction ReadyTrusted by engineering teams building next-gen AI products.St. Jude Children's Research HospitalCoral ProtocolDriaNethermindApp.build (Neon)GrafbaseRyzomeOpenAgentsapp.buildMCP Rust SDKProbeLineraMicrosoft Agent Governance ToolkitWhy Rig?Everything you need to build production-grade AI applications20+ Model ProvidersUnified interface for OpenAI, Anthropic, Google, Cohere, and more.10+ Vector StoresSeamless integration with MongoDB, Qdrant, LanceDB, and others.Full WASM SupportRun AI applications anywhere. Browser, edge, or server.Production ReadyBattle-tested, type-safe, and built for scale.Simple, powerful APIsWrite clean, idiomatic Rust to build sophisticated AI applicationsBasic AgentWith ToolsStreamingRAG Pipelinebasic_agent.rsuse rig::{completion::Prompt, client::{CompletionClient, ProviderClient},providers::openai};

let agent = openai::Client::from_env()
.agent("gpt-5")
.preamble("You are a helpful assistant.")
.build();

let response = agent
.prompt("Explain quantum computing")
.await?;

println!(response);Get started in secondscargo add rigThen check out the quickstart guideOne interface. Every provider.Switch between 20+ model providers and 10+ vector stores without changing your code.Model ProvidersOpenAIAnthropicGeminiCohereAWS BedrockGroq+15 moreVector StoresMongoDBQdrantLanceDBPostgreSQLNeo4jMilvus+5 moreView all integrationsWhat developers can build with RigCoding AgentsBuild AI-powered coding assistants and terminal tools with tool execution.ExploreRAG ApplicationsCreate intelligent search and Q&A over your documents and knowledge bases.ExploreData PipelinesProcess and analyze data at scale with LLM-powered workflows.ExploreEmbedded AIRun AI directly in browsers and edge devices via WASM.ExploreOpen source, built togetherJoin 224+ contributors building the future of AI in RustStar on GitHub7K+ starsJoin DiscordChat with the communityReady to build AI applications in Rust?Rig is MIT licensed and free to use. Join 117 contributors building the future of AI infrastructure.Get StartedView on GitHub

# ldclabs/anda: 🤖 An AI agent framework built with Rust.

- 来源链接：https://github.com/ldclabs/anda
- 浏览器最终地址：https://github.com/ldclabs/anda
- 原始收集：docs/agent/4.md:11
- 保存时间：2026-06-28
- 访问状态：success
- 提取方式：浏览器可见正文提取
- 页面描述：🤖 An AI agent framework built with Rust. Contribute to ldclabs/anda development by creating an account on GitHub.

---

## 原始备注

| **Anda** | 可组合的 AI Agent 运行时框架，支持 Models + Tools + Memory 组合。 | https://github.com/ldclabs/anda | 专注运行时组合性。 |

## 正文

anda
Public
Watch
Fork 54
Star 433
ldclabs/anda
 main
1 Branch
46 Tags
t
T
Add file
Add file
Code
Folders and files
Name	Last commit message	Last commit date

Latest commit
zensh
and
anda-ai
fix: handle pending tool calls before compaction
65b99ea
 · 
History
458 Commits

.github/workflows

 

 

anda_cli

 

 

anda_core

 

 

anda_engine

 

 

anda_engine_server

 

 

anda_web3_client

 

 

docs

 

 

.gitignore

 

 

AGENTS.md

 

 

CHANGELOG.md

 

 

Cargo.toml

 

 

LICENSE-APACHE

 

 

LICENSE-MIT

 

 

MCP_INTEGRATION.md

 

 

Makefile

 

 

README.md

 

 

README_CN.md

 

 

README_JA.md

 

 

anda_diagram.webp

 

 

example.env

 

 
Repository files navigation
README
Apache-2.0 license
MIT license
Anda

A Rust framework for building composable AI agent runtimes.

README Translations

English readme | 中文说明 | 日本語の説明

Introduction

Anda is a Rust framework for building AI agents that can combine models, tools, memory, and other agents into a single runtime. It focuses on composability, type-safe extension points, asynchronous execution, and practical runtime control.

The core engine lets developers register agents and tools, route model requests by capability labels, call local or remote functions, isolate context state, and add optional persistence or memory layers when an application needs them.

Key Features

Composable agents and tools Agents and tools are registered through stable traits and function definitions, so specialized components can be combined into larger workflows without hard-coding one application shape.

Model routing The engine can route completion requests through labeled model tiers such as primary, pro, flash, or lite, while provider-specific adapters stay behind a common request and output contract.

Runtime orchestration CompletionRunner handles iterative model turns, tool calls, agent calls, usage accounting, artifacts, steering messages, follow-up messages, cancellation, and compact continuation handoffs for long-running sessions.

Scoped execution context BaseCtx and AgentCtx provide isolated state, cache, object storage, HTTP calls, signed calls, cancellation, and child contexts for each agent or tool.

Extensible memory and skills Optional extensions provide conversation storage, KIP-based memory tools, filesystem access, shell execution, fetch, notes, todos, and file-backed skills.

Discovery-aware tool bundles Static tools, dynamic providers, and MCP servers can expose capability groups so agents can survey related tool bundles with tools_groups, then expand a group with tools_select only when its schemas are needed.

Project

Documents:

Anda Architecture
Project Structure
anda/
├── anda_cli/              # Command-line interface for Anda engine servers
├── anda_core/             # Core traits, types, and runtime contracts
├── anda_engine/           # Agent runtime, orchestration, contexts, models, and extensions
└── anda_engine_server/    # HTTP server for serving one or more Anda engines
How to Use and Contribute
For application builders

Use anda_cli and anda_engine_server to run and interact with configured engines.

For developers
Build custom agents and tools with the anda_core traits.
Extend anda_engine with reusable runtime features.
Improve model adapters, context capabilities, memory integrations, and server APIs.
Products Built on Anda
Anda Brain: Persistent memory and cognition product built on the Anda framework.
Anda Bot: Personal AI assistant and application runtime built on the Anda framework.
Related Projects
KIP: Knowledge Interaction Protocol used by Anda memory tools.
License

Copyright © 2026 LDC Labs.

ldclabs/anda is licensed under the MIT License. See LICENSE for the full license text.

About

🤖 An AI agent framework built with Rust.

anda.ai
Topics
agent agi autonomous decentralize
Resources
Readme
License
Apache-2.0, MIT licenses found
Activity
Custom properties
Stars
433 stars
Watchers
6 watching
Forks
54 forks
Report repository

Releases 34
v0.12.0
Latest
+ 33 releases

Packages
2
anda_bot_enclave_amd64
alpine

Contributors
6

Languages
Rust
100.0%
